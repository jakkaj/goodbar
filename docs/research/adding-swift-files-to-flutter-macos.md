Below is a CI‑friendly, **command‑line–only** way to add `macos/Runner/ScreenService.swift` to your Flutter macOS app’s **Runner** target, plus alternatives, diffs, pitfalls, and notes for Flutter/CocoaPods.

---

## TL;DR (works on any macOS CI runner)

```bash
# 1) Install tooling (once per machine/CI run)
sudo gem install xcodeproj

# 2) Save this script in your repo
mkdir -p tools
cat > tools/add_swift_to_runner.rb <<'RUBY'
#!/usr/bin/env ruby
# Idempotently add macos/Runner/ScreenService.swift to the Runner target.
require 'xcodeproj'

proj_path = 'macos/Runner.xcodeproj'
swift_rel  = 'ScreenService.swift'     # path *inside* Runner group
group_path = 'Runner'                  # Xcode group (maps to macos/Runner on disk)
target_name = 'Runner'

project = Xcodeproj::Project.open(proj_path)

runner_target = project.targets.find { |t| t.name == target_name }
abort("Target '#{target_name}' not found") unless runner_target

runner_group = project.main_group.find_subpath(group_path, true)
runner_group.set_source_tree('<group>')

# Ensure the file exists on disk where the group points
disk_path = File.join('macos', group_path, swift_rel)
abort("File not found: #{disk_path}") unless File.exist?(disk_path)

# Reuse existing file reference if present (idempotent)
file_ref = runner_group.files.find { |f| f.path == swift_rel } || runner_group.new_file(swift_rel)

# Add to Sources build phase if missing (idempotent)
unless runner_target.sources_build_phase.files_references.include?(file_ref)
  runner_target.add_file_references([file_ref])
end

project.save
puts "Added/ensured #{swift_rel} in target #{target_name}"
RUBY
chmod +x tools/add_swift_to_runner.rb

# 3) Run it (before flutter build)
./tools/add_swift_to_runner.rb

# 4) Build
flutter build macos
```

That’s all you need. The script is **safe to run repeatedly** and never duplicates entries.

---

## Why your build fails

The file exists on disk but isn’t registered in `Runner.xcodeproj`. Xcode (and thus `flutter build macos`) only compiles source files that appear in:

* a `PBXFileReference` (file known to the project),
* a `PBXBuildFile` inside the **Runner → Sources** build phase,
* and as a child of the **Runner** group (so the path resolves correctly).

---

## Option A (recommended): Ruby `xcodeproj` automation

**Pros:** Stable, idempotent, readable; avoids hand‑editing UUIDs.

1. **Install once (CI or dev box):**

```bash
# System Ruby is fine on macOS runners
sudo gem install xcodeproj
# or, if you prefer pinning
# echo -e "source 'https://rubygems.org'\ngem 'xcodeproj', '~> 1.24'" > Gemfile
# bundle install
```

2. **Use the script from the TL;DR** (stores the file under the existing **Runner** group and adds it to the **Sources** phase).

3. **Verify:**

```bash
grep -n 'ScreenService.swift' macos/Runner.xcodeproj/project.pbxproj
xcodebuild -list -project macos/Runner.xcodeproj
```

4. **Build:**

```bash
flutter build macos
# or:
# xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Debug build
```

### Put it in CI (example GitHub Actions job)

```yaml
jobs:
  macos-build:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: "3.x" }
      - run: sudo gem install xcodeproj
      - run: ./tools/add_swift_to_runner.rb
      - run: flutter pub get
      - run: flutter build macos --release
```

---

## Option B: Python (`pbxproj`) automation (if you prefer Python)

```bash
pip3 install pbxproj
cat > tools/add_swift_to_runner.py <<'PY'
from pbxproj import XcodeProject
from pbxproj.pbxextensions.ProjectFiles import FileOptions

proj = XcodeProject.load('macos/Runner.xcodeproj/project.pbxproj')
# path relative to project dir (macos/)
file_path = 'Runner/ScreenService.swift'

# Idempotent add to group 'Runner' and target 'Runner'
added = proj.add_file(file_path, parent='Runner', target='Runner',
                      force=False, file_options=FileOptions())
if added:
    print('Added file and build phase entry')
else:
    print('File already present')

proj.save()
PY
python3 tools/add_swift_to_runner.py
flutter build macos
```

---

## Option C (last resort): edit `project.pbxproj` by hand

**Not recommended** for automation, but here’s the anatomy. You must create **three** things with unique 24‑char hex IDs (uppercase):

```bash
# helper to make a 24‑char uppercase hex id
NEWID() { hexdump -n 12 -v -e '/1 "%02X"' /dev/urandom; }
```

1. **PBXFileReference** (file known to project):

```diff
 /* Begin PBXFileReference section */
+  111111111111111111111111 /* ScreenService.swift */ = {
+    isa = PBXFileReference;
+    lastKnownFileType = sourcecode.swift;
+    path = ScreenService.swift;
+    sourceTree = "<group>";
+  };
 /* End PBXFileReference section */
```

2. **PBXBuildFile** (entry that can be placed into Sources phase):

```diff
 /* Begin PBXBuildFile section */
+  222222222222222222222222 /* ScreenService.swift in Sources */ = {
+    isa = PBXBuildFile;
+    fileRef = 111111111111111111111111 /* ScreenService.swift */;
+  };
 /* End PBXBuildFile section */
```

3. **Add the file to the Runner group** (so the relative path resolves to `macos/Runner`):

```diff
 /* PBXGroup "Runner" children: */
       333333333333333333333333 /* AppDelegate.swift */,
       444444444444444444444444 /* MainFlutterWindow.swift */,
+      111111111111111111111111 /* ScreenService.swift */,
```

4. **Add to the Runner target’s Sources build phase**:

```diff
 /* PBXSourcesBuildPhase files = (...) for target Runner */
       AAA... /* AppDelegate.swift in Sources */,
       BBB... /* MainFlutterWindow.swift in Sources */,
+      222222222222222222222222 /* ScreenService.swift in Sources */,
```

> ⚠️ Avoid converting the pbxproj with `plutil -convert` in automation. It strips comments and often causes huge diffs/merge churn.

---

## Flutter‑specific notes

* There’s **no Flutter CLI** command that “adds native files to Xcode projects.” You must modify the Xcode project (via script or by opening Xcode).
* If you expect to reuse native code or keep Runner clean, consider extracting into a **local Flutter plugin** (`flutter create -t plugin --platforms=macos my_screen_plugin`) and add it to `pubspec.yaml` via a path dependency. This avoids touching `Runner.xcodeproj` for code growth.
* **Hot reload** does **not** reload native Swift. After native changes, restart the macOS app (`flutter run` again or rebuild).

---

## Minimal `ScreenService` example (compiles + MethodChannel)

`macos/Runner/ScreenService.swift`

```swift
import Cocoa
import FlutterMacOS

final class ScreenService: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(name: "screen_service",
                                            binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getDisplays":
            let displays: [[String: Any]] = NSScreen.screens.map { s in
                let f = s.frame
                return [
                    "width": Int(f.width),
                    "height": Int(f.height),
                    "scale": s.backingScaleFactor,
                    "localizedName": s.localizedName
                ]
            }
            result(displays)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
```

`macos/Runner/MainFlutterWindow.swift` (showing where to wire it)

```swift
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    private var screenService: ScreenService?

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        self.contentViewController = flutterViewController
        self.setFrame(self.frame, display: true)

        let messenger = flutterViewController.engine.binaryMessenger
        screenService = ScreenService(messenger: messenger)

        super.awakeFromNib()
    }
}
```

---

## Best practices for organizing native code

* **App‑specific code:** keep under `macos/Runner/…` (e.g., `macos/Runner/Services/` group).
* **Reusable/native‑heavy:** move to a **plugin** (cleaner code ownership, easier testing, fewer pbxproj merges).
* Keep **Pods** untouched; only modify `Runner.xcodeproj`.

---

## Pitfalls & mitigations

* **Wrong UUIDs / manual edits:** Prefer `xcodeproj` or `pbxproj` libraries which generate IDs and validate structure.
* **Not added to Sources phase:** Adding a file reference isn’t enough; ensure it’s in **Runner → Sources** (scripts above do this).
* **Broken paths:** Keep `sourceTree = "<group>"` and place the file under the **Runner** group so `macos/Runner/…` is the on‑disk path.
* **Merge conflicts in `project.pbxproj`:**

  * Run an **idempotent** script in CI before build (and also commit the result).
  * Avoid tools that re‑order entire sections; keep changes minimal.
* **CocoaPods breakage:** Don’t touch `Pods.xcodeproj`. Let `flutter build macos`/`pod install` manage Pods. Your change is only in `Runner.xcodeproj`.
* **Xcode version quirks:** Stick to `xcodeproj` API; it supports modern Xcode versions and hides format differences.
* **Native reload expectations:** Flutter hot reload won’t pick up Swift edits—restart the app.

---

## Answers to your “Key Research Questions”

1. **Add via CLI:** Use `xcodeproj` (Ruby) or `pbxproj` (Python) to create a file reference under the **Runner** group and add it to the **Runner** target’s **Sources** build phase (scripts above).

2. **Correct `project.pbxproj` edits:** You must add **PBXFileReference**, **PBXBuildFile**, put the file ref under **PBXGroup Runner**, and add the build file into **PBXSourcesBuildPhase** of **Runner**. See Option C diff.

3. **Flutter‑specific CLI:** None for adding native files. Only project‑level tools (Xcode/Pods); Flutter CLI won’t register new native sources for you.

4. **Organization best practices:** Keep app‑specific native files under `macos/Runner` (optionally grouped like `Services/`); for reusable/native‑heavy code, use a plugin package.

5. **CI/CD automation:** Run the idempotent script (Option A/B) **before** `flutter build macos`. Pin tool versions (Gemfile/requirements.txt) if you need reproducibility.

---

## Quick validation checklist

* `grep ScreenService.swift macos/Runner.xcodeproj/project.pbxproj` shows entries in **PBXFileReference** and **PBXSourcesBuildPhase**.
* `xcodebuild -list -project macos/Runner.xcodeproj` lists the **Runner** target.
* `flutter run -d macos` starts successfully; the Dart side can call `MethodChannel('screen_service')`.

Use the script from the TL;DR and you’re done.
