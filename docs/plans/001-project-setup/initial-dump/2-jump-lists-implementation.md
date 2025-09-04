Here are the practical ways to implement **Jump Lists** (per‑app *Recent* + *Tasks*) for your Flutter/macOS taskbar, with the right native hooks and a fallback plan.

---

## 1) “Recent” items (per target app)

**Best source (works for most document‑based apps):** the system’s **Shared File Lists** kept per app here:

```
~/Library/Application Support/
  com.apple.sharedfilelist/
    com.apple.LSSharedFileList.ApplicationRecentDocuments/
      <bundle-id>.sfl2
```

These `.sfl2` files are binary property lists that store **Bookmarks** (alias‑like objects) to the app’s recent documents. Decode the bookmark and you get a resolvable file URL. ([The Eclectic Light Company][1])

**How to read them (Swift bridge):**

1. Load `<bundle-id>.sfl2` as a property list.
2. Walk the structure and **extract `Data` blobs that are bookmark payloads**.
3. Resolve each with `URL(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)`. If it resolves, it’s a recent doc URL; grab name, icon, and dates; keep original list order (it’s already “most recent first”). ([Apple Developer][2], [The Eclectic Light Company][1])

> Note: `LSSharedFileList` is long‑deprecated; there’s **no public replacement**. Reading the on‑disk `.sfl2` is the reliable approach used by utilities. ([Stack Overflow][3])

**Nice touch:** generate quick thumbnails for each recent using **Quick Look Thumbnailing** (`QLThumbnailGenerator`) and show them in the submenu. ([Apple Developer][4])

**Sandbox reality check:** a Mac App Store–sandboxed build **can’t** read those per‑app `.sfl2` files. If you want Jump Lists from other apps’ recents, ship **unsandboxed (outside MAS)**, or provide a degraded mode (see §3). Apple’s docs explain that sandboxed apps only get user‑selected file access via security‑scoped bookmarks. ([Apple Developer][5])

**Swift sketch (native plugin):**

```swift
struct JumpRecentItem { let url: URL, let displayName: String, let icon: NSImage }

func recentDocuments(for bundleId: String, limit: Int) -> [JumpRecentItem] {
  let sflPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/\(bundleId).sfl2")
  guard let data = try? Data(contentsOf: sflPath) else { return [] }

  // Deserialize the plist, then recursively collect bookmark Data blobs.
  let anyPlist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
  let bookmarkDatas = collectBookmarkData(anyPlist) // walk dicts/arrays, filter Data that resolves

  var out: [JumpRecentItem] = []
  for b in bookmarkDatas.prefix(limit) {
    var stale = false
    if let url = try? URL(resolvingBookmarkData: b, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale) {
      let name = (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? url.lastPathComponent
      let icon = NSWorkspace.shared.icon(forFile: url.path)
      out.append(.init(url: url, displayName: name, icon: icon))
    }
  }
  return out
}
```

(Algorithm: treat the file as a plist, **look for bookmark blobs**, resolve them. This avoids private classes in the archive; see forensic write‑ups on this format.) ([swiftforensics.com][6], [mac4n6.com][7])

**Opening with the pinned app:** when the user clicks a recent item under App X, open that URL **with App X** via `NSWorkspace` + `OpenConfiguration` so you don’t hit the default handler by mistake. ([Apple Developer][8])

---

## 2) “Tasks” (app‑specific quick actions)

For non‑document actions (e.g., “New Window”, “New Incognito Window”, “New Terminal Tab”), use one or more of:

* **Apple Events / AppleScript.** Many apps expose simple verbs (“make new window”). You’ll need the **Apple Events entitlement** to prompt the user for permission (Automation under Privacy). ([Apple Developer][9])
* **URL schemes** (`slack://`, `zoommtg://`, `notion://`, `vscode://` …) where available.
* **`open` with arguments** (for some apps, `open -na "App" --args ...`), or `NSWorkspace` with `OpenConfiguration.arguments`. ([Apple Developer][8])

**Examples you can ship in a JSON registry:**

```json
{
  "com.google.Chrome": {
    "tasks": [
      { "title": "New Window", "type": "applescript",
        "script": "tell application id \"com.google.Chrome\" to make new window" },
      { "title": "New Incognito Window", "type": "cli",
        "cmd": "/usr/bin/open", "args": ["-na","Google Chrome","--args","--incognito"] }
    ]
  },
  "com.apple.Safari": {
    "tasks": [
      { "title": "New Window", "type": "applescript",
        "script": "tell application id \"com.apple.Safari\" to make new document" }
    ]
  },
  "com.microsoft.VSCode": {
    "tasks": [
      { "title": "New Window", "type": "cli",
        "cmd": "/usr/bin/open", "args": ["-na","Visual Studio Code"] }
    ]
  }
}
```

(Chrome/Safari “new window” via AppleScript is widely used; `open -na` launches a fresh instance/new window.) ([Super User][10], [Stack Overflow][11], [MacScripter][12])

**Automation permission UX:** first time a user invokes a scripted task, the OS will prompt (“App wants to control Safari”). That’s expected with TCC. ([Apple Developer][9])

---

## 3) Fallbacks / degraded modes (when sandboxed or the app doesn’t use NSDocument)

* **Sandboxed build:** skip per‑app recents; show **Tasks** only. Optionally, show a *global* “Recent Documents” submenu (from `~/Library/.../RecentDocuments.sfl2`) filtered by file type (UTI) or by “Open With” default handler; not perfect, but useful. ([Ask Different][13])
* **Non‑document apps (browsers, terminal, chat):** rely on **Tasks** and your own **“Frequent”** stats (see §4).

---

## 4) “Frequent” section (Windows‑style)

Track what users launch/open **through your bar** and persist counts per bundle id + file URL. Sort by frequency and show the top N under *Frequent*. This avoids scraping each app’s private MRU files and works uniformly.

---

## 5) Flutter integration

* Use `super_context_menu` so your right‑click menu is a native **NSMenu** with submenus (*Recent*, *Frequent*, *Tasks*) and icons/thumbnails. It uses the system context menu on macOS. ([Dart packages][14])
* Bridge to Swift with a thin MethodChannel:

  * `recentDocsFor(bundleId, limit) -> [ {title, path/icon/thumbnail} ]`
  * `performTask(taskId, bundleId)` (AppleScript / URL / CLI)
  * `openFileWithApp(url, bundleId)`
* Cache **recent** results for a few seconds to keep the menu snappy; invalidate on app activation or when you detect the `.sfl2` file changed (mtime).

---

## 6) Placement + “open on this display”

When opening a *Recent* item or *Task*, reuse your existing “launch on this display & move window above the bar” logic (NSWorkspace launch, then AX to position), so the window appears on the bar’s monitor. ([Apple Developer][8])

---

## 7) Gotchas

* Not every app writes to its per‑app `.sfl2` (a few keep their own MRUs). Your provider chain should be: **App‑specific** (if you have a recipe) → **SFL2** → **Global Recents filtered by handler** → empty. ([The Eclectic Light Company][1], [Ask Different][13])
* Some `.sfl2` items can be **security‑scoped bookmarks** created by sandboxed apps; `URL(resolvingBookmarkData:...)` still resolves them for reading paths, but you won’t inherit the other app’s read rights. You just need the path to *ask* NSWorkspace to open it with the target app. ([Apple Developer][15])

---

## 8) Minimal native code you’ll need

* **Recents**: plist decode + bookmark resolution as above. ([The Eclectic Light Company][1], [Apple Developer][2])
* **Thumbnails**: `QuickLookThumbnailing`. ([Apple Developer][4])
* **Open with app**: `NSWorkspace` + `OpenConfiguration`. ([Apple Developer][8])
* **Tasks**: AppleScript runner (`NSAppleScript`/`OSAScript`), URL opener, and `open` wrapper; gate Apple Events behind the entitlement. ([Apple Developer][9])

---

### TL;DR implementation plan

1. Add a **JumpListProvider** on the native side that returns `Recent` and `Tasks` for a given bundle id (SFL2 → bookmarks → URLs; curated tasks per app). ([The Eclectic Light Company][1])
2. Render a native context menu from Flutter with `super_context_menu` and inject items on‑demand (lazy fetch). ([Dart packages][14])
3. Open recents **with the target app** and then position the window on that display using your AX placement. ([Apple Developer][8])
4. Track launches to build a **Frequent** section that works for every app.

If you want, I can sketch the exact Swift functions and the Dart MethodChannel contracts you can drop straight into your project.

[1]: https://eclecticlight.co/2023/08/04/recent-items-property-lists-bookmarks-and-resolvers/ "Recent items, property lists, Bookmarks and resolvers – The Eclectic Light Company"
[2]: https://developer.apple.com/documentation/foundation/nsurl/init%28resolvingbookmarkdata%3Aoptions%3Arelativeto%3Abookmarkdataisstale%3A%29?utm_source=chatgpt.com "init(resolvingBookmarkData:options:relativeTo ..."
[3]: https://stackoverflow.com/questions/53788340/possible-to-add-to-finder-sidebar-since-lssharedfilelist-is-deprecated?utm_source=chatgpt.com "Possible to Add to Finder Sidebar Since LSSharedFileList ..."
[4]: https://developer.apple.com/documentation/quicklookthumbnailing?utm_source=chatgpt.com "Quick Look Thumbnailing | Apple Developer Documentation"
[5]: https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox?utm_source=chatgpt.com "Accessing files from the macOS App Sandbox"
[6]: https://www.swiftforensics.com/2018/12/making-nskeyedarchives-human-readable.html?utm_source=chatgpt.com "Making NSKeyedArchives human readable"
[7]: https://www.mac4n6.com/blog/2016/1/1/manual-analysis-of-nskeyedarchiver-formatted-plist-files-a-review-of-the-new-os-x-1011-recent-items?utm_source=chatgpt.com "Manual Analysis of 'NSKeyedArchiver' Formatted Plist Files"
[8]: https://developer.apple.com/documentation/appkit/nsworkspace?utm_source=chatgpt.com "NSWorkspace | Apple Developer Documentation"
[9]: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events?utm_source=chatgpt.com "Apple Events Entitlement | Apple Developer Documentation"
[10]: https://superuser.com/questions/104180/how-to-create-a-new-chrome-window-on-mac-os-x-using-applescript-or-a-shell-scrip?utm_source=chatgpt.com "How to create a new Chrome window on Mac OS X using ..."
[11]: https://stackoverflow.com/questions/67102767/open-a-new-safari-window-on-macos-with-applescript-without-messing-things-up?utm_source=chatgpt.com "Open a new Safari Window on MacOS with AppleScript ..."
[12]: https://www.macscripter.net/t/multiple-instances-of-google-chrome-and-microsoft-outlook/75076?utm_source=chatgpt.com "Multiple instances of Google Chrome and Microsoft Outlook"
[13]: https://apple.stackexchange.com/questions/464860/where-does-pages-store-its-list-of-recently-opened-documents?utm_source=chatgpt.com "Where does Pages store its list of recently opened documents?"
[14]: https://pub.dev/packages/super_context_menu?utm_source=chatgpt.com "super_context_menu | Flutter package"
[15]: https://developer.apple.com/documentation/foundation/nsurl/bookmarkresolutionoptions?utm_source=chatgpt.com "NSURL.BookmarkResolutionOptions"
