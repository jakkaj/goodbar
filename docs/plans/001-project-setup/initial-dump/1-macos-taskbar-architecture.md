Below is a practical, “ship‑it” plan to build a Windows‑style taskbar for **macOS using Flutter**, with per‑display isolation, pinning, per‑window entries, drag re‑order, and sane interaction with Spaces/Stage Manager/fullscreen.

---

## 1) What macOS *does* and *doesn’t* let you do (constraints to design around)

* **Enumerate all on‑screen windows** (owner process, bounds, title, z‑order front→back): via `CGWindowListCopyWindowInfo(..., kCGWindowListOptionOnScreenOnly)` in CoreGraphics. You can filter by display by intersecting window bounds with each `NSScreen`’s frame. ([Apple Developer][1])
* **Launch apps**: via `NSWorkspace.openApplication(...)` / `openApplication(at:configuration:...)`. There’s **no public API to launch an app directly on a specific display**; you launch, then move its window(s). ([Apple Developer][2], [Ask Different][3])
* **Reserve screen space** like the system Dock (i.e., shrink other windows’ “work area”): there’s **no public API** for third‑party apps to change `NSScreen.visibleFrame`. You must instead *float your bar above other windows* and, if you want to keep windows out of its area, **nudge them** using the Accessibility API. ([Apple Developer][4], [Stack Overflow][5])
* **Stay above other apps**: set the bar window `NSWindow.level = .statusBar` (or `.dock`) and control appearance with `NSWindow` APIs. ([Apple Developer][6])
* **Behave well across Spaces/Stage Manager and fullscreen**: use `NSWindow.collectionBehavior` flags like `.moveToActiveSpace`, `.canJoinAllSpaces`, and optionally `.fullScreenAuxiliary` to control where the bar appears. ([Apple Developer][7])
* **Move/resize other apps’ windows & watch window changes**: use the macOS **Accessibility API** (`AXUIElement`, `AXObserverAddNotification` for `kAXWindowMovedNotification`/`kAXWindowResizedNotification`) after the user grants **Accessibility** permission. Expect notifications at the **end** of move/resize. ([Apple Developer][8], [Stack Overflow][9])
* **Prompt for Accessibility**: `AXIsProcessTrustedWithOptions` (show the OS permission dialog). Many legit window managers (Magnet, Rectangle) require this. ([Apple Developer][10], [magnet.crowdcafe.com][11], [Apple Support][12])

> Why this matters: the Windows taskbar *reserves* space OS‑wide; macOS doesn’t allow third‑party bars to do that, so we emulate the behavior by (a) floating above windows, and optionally (b) nudging other windows away via Accessibility.

---

## 2) Target behavior vs. Windows taskbar (so we mirror what matters)

* **Per‑monitor isolation** (“show buttons only where the window is open”): that’s how Windows multi‑monitor mode can be configured. We’ll default to this on macOS. ([Microsoft Support][13], [TECHCOMMUNITY.MICROSOFT.COM][14])
* **Pinning vs. running**: Windows mixes pinned items with running instances and supports re‑order + right‑click pin/unpin. We’ll do the same. ([Microsoft Learn][15], [Microsoft Press Store][16])
* **Separate entries per instance** (“never combine”): Windows allows non‑grouped buttons with labels; we’ll surface each *window* as an entry. ([Microsoft Learn][17])

---

## 3) Flutter‑first architecture (idiomatic on macOS)

### 3.1 High‑level components

* **One Flutter window per physical display** (your “taskbar instance”):

  * Place at the display’s bottom, fixed height; float above apps.
  * Use `desktop_multi_window` to create/manage multiple bar windows.
  * Use `screen_retriever` to enumerate displays & track changes; `NSApplication.didChangeScreenParametersNotification` as native backstop. ([Dart packages][18], [Apple Developer][19])
* **Native glue (Swift/Obj‑C)** via MethodChannels for:

  1. **Window enumeration** (CoreGraphics) with per‑display filtering.
  2. **Focusing/raising/moving** a chosen app window (Accessibility).
  3. **Launch + “move to this display when ready”** loop (NSWorkspace + AX).
* **Flutter UI** renders:

  * **Pinned row** (reorderable, persistent).
  * **Running row** (ephemeral windows on this display; reorderable; vanishes on close).
  * **Right‑click context menus** using a native‑feeling menu package.
* **Persistence**: store pins, order, and per‑app preferences in `shared_preferences` or `hive`.

### 3.2 Recommended Flutter packages

* **Multi‑window**: `desktop_multi_window`. ([Dart packages][18])
* **Display info**: `screen_retriever`. ([Dart packages][20])
* **Window control (position/size, always on top)**: `window_manager` and/or `macos_window_utils` for level tweaks. ([Dart packages][21])
* **Context menus**: `super_context_menu` (uses system menus on macOS). ([Dart packages][22])
* **Startup at login** (optional): `launch_at_startup` (wraps modern login item APIs). ([Dart packages][23])

---

## 4) Native macOS side (swift) — the three key bridges

### A) “List windows on this display”

* Use `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)`; filter layer `0` (normal) and intersect `kCGWindowBounds` with target `NSScreen.frame`. Return:

  * windowNumber, ownerPID, ownerName, title (`kCGWindowName`), bounds, isOnScreen.
* Map `ownerPID` → `NSRunningApplication` to fetch **app icon**. ([Apple Developer][1])

### B) “Activate/raise/move a window”

* Ask for Accessibility permission: `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`.
* From PID: `let app = AXUIElementCreateApplication(pid)` → get `kAXWindowsAttribute`.
* For a window element, set `kAXPosition` / `kAXSize` (to keep it above the bar area on this display), and perform `AXRaise`. ([Apple Developer][10])

### C) “Launch app; put first window on this display”

* Launch with `NSWorkspace.openApplication(...)`.
* Poll (short backoff) via AX for the app’s first standard window; when present, **move it** to the target display’s region (and optionally resize to avoid overlapping the bar). ([Apple Developer][2])

---

## 5) The taskbar window itself (per display)

**Creation & placement (Swift via a small helper, called once per display):**

```swift
let barHeight: CGFloat = 44
let screenFrame = screen.frame
let barFrame = NSRect(x: screenFrame.minX,
                      y: screenFrame.minY,
                      width: screenFrame.width,
                      height: barHeight)
window.setFrame(barFrame, display: true)

window.level = .statusBar                      // above app windows
window.collectionBehavior = [
  .moveToActiveSpace,                          // follow current Space
  .canJoinAllSpaces,                           // visible across Spaces
  .fullScreenAuxiliary                         // optional: show in fullscreen
]
window.isOpaque = false
window.backgroundColor = .clear
```

This gives you a bar that sits at the bottom of **each** display and stays visible across Spaces (you can toggle `.fullScreenAuxiliary` in settings; some users don’t want bars over fullscreen apps). ([Apple Developer][6])

**React to display changes**: re‑layout bars on `NSApplication.didChangeScreenParametersNotification`. ([Apple Developer][19])

---

## 6) Keeping other apps from overlapping the bar (three tactics)

1. **Simple mode (default, no special permissions):** bar floats at `.statusBar` level; windows can pass underneath if maximized, but the bar is always on top. Zero permissions. ([Apple Developer][6])
2. **“Nudge” mode (requires Accessibility permission):** monitor **moved/resized** window notifications with `AXObserverAddNotification` and, if a window intersects your bar’s rect on that display, set its AX frame so its bottom edge sits just above the bar. Notifications fire at the end of the gesture (that’s normal). ([Apple Developer][24], [Stack Overflow][9])
3. **Launch‑on‑this‑display assist:** when the user clicks a *pin*, launch the app, then move its new window into the current display’s “safe area” (above your bar). ([Apple Developer][2])

> There is **no supported way** to change `NSScreen.visibleFrame` like the Dock does. If you see apps claiming it, they’re using Accessibility/heuristics under the hood. ([Stack Overflow][5])

---

## 7) Data model & behaviors (to match your spec)

* **Pinned items**

  * Schema: `{ bundleId, displayPolicy, iconPath?, customLabel?, order }`
  * Reorder with `ReorderableListView` (persist order). Right‑click menu: *Open*, *Pin/Unpin*, *Move to Display X*, *Quit*. ([Flutter API Docs][25], [Dart packages][22])
  * Click when **not running**: `NSWorkspace` launch + “move to this display”. When **running with ≥1 window on this display**: the **first** window “occupies” the pin tile (icon + title); extra windows of that app appear in the **running** section after the pins (your requested behavior).
* **Running (non‑pinned) items**

  * Every *window* is an entry (never combine). Reorderable within the running segment; removed when the window closes.
* **Per‑display isolation**

  * Each bar window shows only windows whose bounds intersect that display. When windows move between displays (dragged across), AX notifications → update membership.
* **Badges & affordances**

  * Indicator dot for running; brighter glow for *active* window’s button; small count badge on a pin if >1 window exists (click to cycle or show mini list).

---

## 8) Flutter UI sketch (clean, Windows‑like styling)

* **Layout**: `[<drag‑reorderable PINS> | divider | <drag‑reorderable RUNNING>]`
* **Tile (“bar button”)**

  * 32×32 app icon + optional title (truncate), rounded hover, pressed states, subtle drop shadow; small underline for active.
  * Right‑click → native context menu (`super_context_menu` on macOS). ([Dart packages][22])
* **Implementation notes**

  * Use `desktop_multi_window` to spawn a bar per display, passing a `displayId` into each Flutter instance; `screen_retriever` to rebuild on hot‑plug/scale change. ([Dart packages][18])
  * For “always on top” and frameless window visuals, control via `window_manager`/`macos_window_utils`. ([Dart packages][21])

---

## 9) Example: minimal platform channel surfaces (Dart ↔ Swift)

**Dart (per display bar instance)**

```dart
final method = const MethodChannel('sys.windows');

Future<List<WindowInfo>> listWindowsForDisplay(int displayId) async {
  final raw = await method.invokeMethod<List>('listWindows', {'displayId': displayId});
  return (raw ?? []).map(WindowInfo.fromMap).toList();
}

Future<void> focusWindow(int windowNumber) =>
  method.invokeMethod('focusWindow', {'windowNumber': windowNumber});

Future<void> moveWindowToDisplay(int windowNumber, int displayId, Rect avoidRect) =>
  method.invokeMethod('moveWindowToDisplay', {
    'windowNumber': windowNumber,
    'displayId': displayId,
    'avoid': {
      'x': avoidRect.left, 'y': avoidRect.top,
      'w': avoidRect.width, 'h': avoidRect.height
    }
  });

Future<void> launchBundleOnDisplay(String bundleId, int displayId, Rect avoidRect) =>
  method.invokeMethod('launchOnDisplay', {'bundleId': bundleId, 'displayId': displayId, 'avoid': {/*...*/}});
```

**Swift (sketch of the key bits)**

```swift
@objc class WindowBridge: NSObject {
  @objc func listWindows(_ args: [String:Any], result: FlutterResult) {
    let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String:Any]]
    // Filter to layer 0 and intersect with target NSScreen...
    // Map to [String: Any] with pid, windowNumber, title, bounds, displayId.
    result(filtered)
  }

  @objc func focusWindow(_ args: [String:Any], result: FlutterResult) {
    guard let winNumber = args["windowNumber"] as? CGWindowID else { result(false); return }
    // Resolve PID via window info, build AXUIElement app & window, AXRaise
    result(true)
  }

  @objc func moveWindowToDisplay(_ args: [String:Any], result: FlutterResult) {
    // Requires AX trust; compute target frame on that display, set AXPosition/AXSize
    result(true)
  }

  @objc func launchOnDisplay(_ args: [String:Any], result: FlutterResult) {
    // NSWorkspace.openApplication(...), then poll AX for first window and move it
    result(true)
  }
}
```

APIs referenced: `CGWindowListCopyWindowInfo`, `NSWorkspace.*`, `NSRunningApplication.icon`, AX (`AXUIElement*`, `AXObserverAddNotification`). ([Apple Developer][1])

---

## 10) Styling & UX details (Windows‑like, but native‑feeling on macOS)

* **Height**: \~44 px; **icon**: 24–28 px logical; **corner radius**: 8–10 px.
* **Hover**: subtle acrylic/blur (macOS feel) via `macos_window_utils` visual effect; **active**: 2 px underline, mild glow. ([Dart packages][26])
* **Right‑click**:

  * Pinned: Open / Unpin / Quit / Options → “Open on this display”, “Always show title”, “Show previews”.
  * Running: Open / Pin / Close window / Move to Other Display.

---

## 11) “How we keep parity with Windows semantics”

* **Per‑monitor buttons**: only show windows on that monitor (like “Taskbar where window is open”). ([Microsoft Support][13])
* **Pinning**: right‑click a running item to pin; pins live left, before running items. Drag to reorder pins. ([Microsoft Press Store][16])
* **Separate entries per instance**: one tile per window; pin’s first running window “takes over” the pin tile; extras appear after pins. ([Microsoft Learn][17])

---

## 12) Distribution & permissions

* You’ll request **Accessibility** at first run (`AXIsProcessTrustedWithOptions`) if user enables “Nudge windows” or “Launch on this display & place window”. Without it, basic overlay/task switcher still works. ([Apple Developer][10])
* **Login item**: optional toggle using `SMAppService` (or `launch_at_startup` from Flutter). ([Apple Developer][27], [Dart packages][23])
* App Store: many window managers ship **with Accessibility permission** (e.g., Magnet). Plan for a clear explainer and fallback behavior if permission isn’t granted. ([magnet.crowdcafe.com][11])

---

## 13) Implementation checklist

1. **Skeleton**

   * Add packages: `desktop_multi_window`, `screen_retriever`, `window_manager`, `macos_window_utils`, `super_context_menu`, `shared_preferences`. ([Dart packages][18])
   * Create a **controller** that: spawns one bar window per display, keeps a per‑display state store, handles MethodChannel calls.
2. **Native bridges**

   * Implement window listing (CoreGraphics) + app icon (NSRunningApplication). ([Apple Developer][1])
   * Implement focus/move/raise (Accessibility) and the launch‑then‑place loop. ([Apple Developer][8])
3. **UI**

   * Build a **segmented** horizontal list: `[pins] | [running]`.
   * Reorder support (drag); context menus; active state; badges. ([Flutter API Docs][25], [Dart packages][22])
4. **Window avoidance (optional)**

   * If user enables: set up `AXObserverAddNotification` for move/resize; on overlap with bar rect, adjust `AXFrame`. ([Apple Developer][24])
5. **Polish**

   * Stage Manager/Spaces rules via `collectionBehavior`; toggle “Show over fullscreen apps”. ([Apple Developer][7])

---

## 14) Known edge cases & how to handle them

* **Some apps don’t expose titles in `kCGWindowName`** → fall back to AX `AXTitle`. ([Apple Developer][1])
* **Fullscreen apps**: if users dislike overlay in fullscreen, disable `.fullScreenAuxiliary`. ([Apple Developer][28])
* **Rapid move/resize** events\*\*: AX sends notifications **after** a gesture—good enough for “nudge” adjustments (not pixel‑by‑pixel live). ([Stack Overflow][9])
* **HiDPI math**: convert between points and pixels with each screen’s `backingScaleFactor` when mixing CG (pixels) and AppKit (points).

---

## 15) Why this design is “idiomatic Flutter on macOS”

* Flutter renders the **entire bar UI** with high performance and portable code.
* **Native interop is narrow and purpose‑built** (window enumeration, AX moves, and launch), cleanly wrapped behind MethodChannels. Flutter stays the UI brain.
* You leverage mainstream, actively‑maintained packages for multi‑window, screen info, window flags, menus, and login items. ([Dart packages][18])

---

## 16) Optional: match some Windows nuances later

* **Hover previews** (thumbnail of window): grab app window snapshots (Screen Recording permission would be needed on modern macOS).
* **Jump Lists**‑like menus: for some apps, populate recent docs/commands on right‑click.
* **Group combine modes**: add a setting to “combine when bar is full”.

---

If you want, I can drop in a starter repo skeleton (Flutter + macOS host with the three native bridges wired) based on the package set above, with one bar per display and the pin/running model pre‑stubbed.

[1]: https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo%28_%3A_%3A%29?utm_source=chatgpt.com "CGWindowListCopyWindowInfo(_:_:)"
[2]: https://developer.apple.com/documentation/appkit/nsworkspace/openapplication%28at%3Aconfiguration%3Acompletionhandler%3A%29?utm_source=chatgpt.com "openApplication(at:configuration:completionHandler:)"
[3]: https://apple.stackexchange.com/questions/431524/is-there-a-way-to-launch-an-application-on-a-particular-display?utm_source=chatgpt.com "Is there a way to launch an application on a particular ..."
[4]: https://developer.apple.com/documentation/AppKit/NSScreen/visibleFrame?utm_source=chatgpt.com "visibleFrame | Apple Developer Documentation"
[5]: https://stackoverflow.com/questions/7195383/can-i-change-nsscreen-visibleframe?utm_source=chatgpt.com "Can I change NSScreen visibleframe?"
[6]: https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct?utm_source=chatgpt.com "NSWindow.Level | Apple Developer Documentation"
[7]: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/movetoactivespace?utm_source=chatgpt.com "moveToActiveSpace | Apple Developer Documentation"
[8]: https://developer.apple.com/documentation/applicationservices/axuielement_h?utm_source=chatgpt.com "AXUIElement.h - Documentation"
[9]: https://stackoverflow.com/questions/15303973/axwindowmoved-via-axobserver-continuous-updates?utm_source=chatgpt.com "AXWindowMoved (via AXObserver) - continuous updates?"
[10]: https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions?utm_source=chatgpt.com "AXIsProcessTrustedWithOptions(_:)"
[11]: https://magnet.crowdcafe.com/faq.html?utm_source=chatgpt.com "Window manager for Mac"
[12]: https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac?utm_source=chatgpt.com "Allow accessibility apps to access your Mac"
[13]: https://support.microsoft.com/en-us/windows/customize-the-taskbar-in-windows-0657a50f-0cc7-dbfd-ae6b-05020b195b07?utm_source=chatgpt.com "Customize the Taskbar in Windows"
[14]: https://techcommunity.microsoft.com/discussions/windowsinsiderprogram/when-using-multiple-displays-show-my-taskbar-apps-on-/4384493?utm_source=chatgpt.com "When using multiple displays, show my taskbar apps on"
[15]: https://learn.microsoft.com/en-us/windows/apps/develop/windows-integration/pin-to-taskbar?utm_source=chatgpt.com "Pin your app to the taskbar - Windows apps"
[16]: https://www.microsoftpressstore.com/articles/article.aspx?p=3178893&seqNum=4&utm_source=chatgpt.com "Using Windows 11"
[17]: https://learn.microsoft.com/en-us/answers/questions/4123168/cant-un-combine-taskbar-items-in-windows-11-after?utm_source=chatgpt.com "Can't un-combine taskbar items in Windows 11 after latest ..."
[18]: https://pub.dev/packages/desktop_multi_window?utm_source=chatgpt.com "desktop_multi_window | Flutter package"
[19]: https://developer.apple.com/documentation/appkit/nsapplication/didchangescreenparametersnotification?utm_source=chatgpt.com "didChangeScreenParametersNo..."
[20]: https://pub.dev/packages/screen_retriever "screen_retriever | Flutter package"
[21]: https://pub.dev/packages/window_manager?utm_source=chatgpt.com "window_manager | Flutter package"
[22]: https://pub.dev/packages/super_context_menu?utm_source=chatgpt.com "super_context_menu | Flutter package"
[23]: https://pub.dev/packages/launch_at_startup?utm_source=chatgpt.com "launch_at_startup | Flutter package - Pub"
[24]: https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification?utm_source=chatgpt.com "AXObserverAddNotification(_:_:_:_:)"
[25]: https://api.flutter.dev/flutter/material/ReorderableListView-class.html?utm_source=chatgpt.com "ReorderableListView class - material library - Dart API"
[26]: https://pub.dev/packages/macos_window_utils?utm_source=chatgpt.com "macos_window_utils | Flutter package"
[27]: https://developer.apple.com/documentation/servicemanagement/smappservice?utm_source=chatgpt.com "SMAppService | Apple Developer Documentation"
[28]: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary?utm_source=chatgpt.com "fullScreenAuxiliary | Apple Developer Documentation"
