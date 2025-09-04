Yes. You can show **per‑profile colors & icons even when Edge/Chrome windows are created outside your bar** by (1) building a local catalog of profiles and (2) mapping each running window to a profile at runtime. This works for both Edge and Chrome on macOS.

---

## 1) Build a local **profile catalog** (Chrome + Edge)

Read the browser’s *Local State* JSON and cache `profile.info_cache`:

* **Chrome:** `~/Library/Application Support/Google/Chrome/Local State` (same idea for Dev/Beta/Canary bundles). Chromium documents the *user data dir* and that each profile is a subfolder (e.g., `Default`, `Profile 1`, …). ([Chromium Git Repositories][1])
* **Edge:** `~/Library/Application Support/Microsoft Edge/Local State` (Edge uses the same Chromium pattern; Microsoft docs/guides reference the profile paths and `edge://version` for the profile path). ([Microsoft Learn][2])

From `profile.info_cache.<profileDir>` read:

* `name`, `avatar_icon`, and the **profile color** fields: `default_avatar_fill_color`, `default_avatar_stroke_color`, and/or `profile_color_seed`. These keys are defined in Chromium’s profile code. ([Chromium Git Repositories][3])
* Optional: `gaia_picture_file_name` (use file if present for Google/Microsoft‑account pictures). ([Chromium Git Repositories][3])

> Render: badge the base app icon with the profile avatar color (and GAIA picture if available). If nothing is set, use the fill/stroke colors; this is how Chromium styles the avatar. ([Chromium Git Repositories][3])

---

## 2) Map each **running window → profile**, even if launched elsewhere

Use a **multi‑probe** strategy that succeeds whether the user opened a window from the Dock, a URL handler, or via the browser’s own profile switcher.

### Probe A — process command‑line (fast path)

* Get the **owner PID** for the window (CGWindow API), then read that process’ argv. On macOS you can read peer‑process arguments (same user) via `sysctl` (KERN\_PROCARGS2) or similar; there are working Swift examples. If you find `--profile-directory=Profile 1`, you have the profile directory immediately. ([Medium][4], [Stack Overflow][5])

> Caveat: If the main browser process wasn’t launched with `--profile-directory` (e.g., “last used” profile opened), this flag may be absent; keep probing.

### Probe B — Accessibility: read the **avatar button’s** label/tooltip

* Traverse the window’s **AX** tree; locate the **avatar/profile button** in the browser toolbar and read its accessible text (`AXTitle`/`accessibilityLabel` or `AXHelp`).

  * Chromium sets the avatar button’s **tooltip** to the **profile name**, so the accessible help/name resolves to the profile’s display name. ([Chromium Git Repositories][6], [Chromium Issues][7])
  * Chrome exposes its UI controls over accessibility APIs, so the avatar button is reachable. ([Google Online Security Blog][8])
  * In AppKit, the tooltip string is exposed via the `accessibilityHelp` property; accessibility clients read it. ([Apple Developer][9])

Match that string against the names from your catalog (handles localization because you’re comparing the **exact profile display name** the user set).

> Permissions: AX requires user consent (Privacy → Accessibility). If not granted, skip Probe B. ([Apple Developer][10])

### Probe C — last‑chance fallback

* If A/B fail, you can temporarily query the **profile path** through the browser itself (e.g., opening `chrome://version` / `edge://version` to read “Profile path”), then close the tab. Use sparingly, as it’s intrusive; Microsoft and community docs confirm these pages show the *Profile path*. ([Microsoft Learn][11])

### Realtime updates

* Listen for **window lifecycle** via AX notifications (`kAXWindowCreatedNotification`, `kAXFocusedWindowChanged`) and re‑run A/B only on changes; this keeps things snappy and stays in sync when a user **switches profiles inside the browser** (new window opens under the new profile). ([Apple Developer][12], [Stack Overflow][13])

---

## 3) Incognito/Guest detection

Chromium’s avatar button swaps to special icons in **Incognito/Guest**; you can mirror that in your UI (e.g., hat/glasses glyph with a purple underline) when the AX text indicates Incognito or the process args contain `--incognito`. The avatar button code uses distinct icons for these modes. ([Chromium Git Repositories][6])

---

## 4) Launch/focus behavior (still “Windows‑like”)

For **clicks** on a profile pin:

* Launch the browser with that profile:
  `"/Applications/<App>.app/Contents/MacOS/<App>" --profile-directory="<Profile X>" [--new-window] [--] <url>`
  This form is reliable across Chrome/Edge (direct binary works better than `open -a` for profile selection). Community/Docs show the same switch; some posts note `open -a` can reuse “last used” unless all instances are closed—going direct avoids that ambiguity. ([Super User][14], [Tahoe Ninja][15], [text/plain][16])
* To **focus** an already‑running profile window, issuing the same command **without a URL** usually brings that profile’s window forward (Chromium matches to the profile’s browser process). If it still spawns a new window, use AX to raise the existing one on the target display.

---

## 5) Edge **and** Chrome specifics

* **Paths & profile dirs**

  * Chrome profiles live under `~/Library/Application Support/Google/Chrome/` (`Default`, `Profile 1`, …). ([Chromium Git Repositories][1])
  * Edge profiles live under `~/Library/Application Support/Microsoft Edge/` with the same structure; Microsoft answers/docs and RPA guides reference the Mac paths and `edge://version`/`edge://profile-internals` for profile path discovery. ([Microsoft Learn][2], [UiPath Documentation][17])
* **Colors & icons** are read from the same Chromium keys in *Local State* for both browsers (`profile_color_seed`, `default_avatar_*`, `avatar_icon`). ([Chromium Git Repositories][3])
* **Multiple channels** (Chrome Dev/Beta/Canary): scan additional **User Data** roots and merge profiles into your catalog with a `channel` field to disambiguate.

---

## 6) Flutter/native glue (minimal)

* **Dart model**:

  ```ts
  class BrowserProfile {
    String appId;        // com.google.Chrome | com.microsoft.Edge
    String profileDir;   // "Default", "Profile 1", …
    String displayName;  // e.g., "Work"
    int? fillARGB;       // default_avatar_fill_color
    int? strokeARGB;     // default_avatar_stroke_color
    int? colorSeed;      // profile_color_seed
    String? gaiaImagePath;
  }
  ```
* **MethodChannel** (Swift):

  * `listProfiles(appId) -> [BrowserProfile]` (parse *Local State*)
  * `detectProfileForWindow(appId, windowId) -> profileDir?`

    * Try argv (`--profile-directory=`) → AX avatar button name → null
  * `launchProfile(appId, profileDir, url?, newWindow?)`
* **Rendering**: compose app icon + circular badge tinted with `fillARGB`; load `gaiaImagePath` if present; fallback to first‑letter monogram if nothing else.

---

## 7) Performance & privacy

* Cache the *Local State* parse (invalidate on mtime change).
* Cache **window→profile** mapping until the window closes or its AX avatar text changes.
* Respect the **Accessibility** permission model; if not granted, skip Probe B and show a neutral icon. ([Apple Developer][10])

---

### Why this will feel “Windows‑like”

Windows pins create **per‑profile shortcuts** (icon badged with the profile avatar; pinned item launches a fixed profile). You’re replicating both the **visual identity** (color/icon from *Local State*) and the **binding** (`--profile-directory`) — plus you detect windows launched any other way via AX/argv so your bar is always correct. ([Chromium Git Repositories][3])

If you want, I can sketch the Swift functions for: parsing *Local State* (both apps), argv extraction, AX traversal to find the avatar button, and a tiny profile‑icon renderer.

[1]: https://chromium.googlesource.com/chromium/src/%2B/main/docs/user_data_dir.md?utm_source=chatgpt.com "Chromium Docs - User Data Directory"
[2]: https://learn.microsoft.com/en-us/answers/questions/2402846/how-to-locate-the-last-browsing-history-for-micros?utm_source=chatgpt.com "How to locate the Last Browsing History for Microsoft Edge ..."
[3]: https://chromium.googlesource.com/chromium/src/%2B/lkgr/chrome/browser/profiles/profile_attributes_entry.cc?utm_source=chatgpt.com "chrome/browser/profiles/profile_attributes_entry.cc"
[4]: https://gaitatzis.medium.com/getting-running-process-arguments-using-swift-5cfe6c365e44?utm_source=chatgpt.com "Getting Running Process Arguments Using Swift"
[5]: https://stackoverflow.com/questions/31582787/os-x-getting-remote-process-input-args-sometimes-fails?utm_source=chatgpt.com "OS X getting remote process input args sometimes fails"
[6]: https://chromium.googlesource.com/chromium/src/%2B/905040dd60ac97d8faff71032f2e454a7443a9dd/chrome/browser/ui/views/profiles/avatar_toolbar_button.cc?utm_source=chatgpt.com "chrome/browser/ui/views/profiles/avatar_toolbar_button.cc"
[7]: https://issues.chromium.org/41376635?utm_source=chatgpt.com "Add new avatar button to toolbar per MD refresh [41376635]"
[8]: https://security.googleblog.com/2024/10/using-chromes-accessibility-apis-to.html?utm_source=chatgpt.com "Using Chrome's accessibility APIs to find security bugs"
[9]: https://developer.apple.com/documentation/appkit/nsaccessibility-c.protocol/accessibilityhelp?changes=_1&language=objc&utm_source=chatgpt.com "accessibilityHelp | Apple Developer Documentation"
[10]: https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification?language=objc&utm_source=chatgpt.com "AXObserverAddNotification - Documentation"
[11]: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/userdatadir?utm_source=chatgpt.com "Microsoft Edge Browser Policy Documentation UserDataDir"
[12]: https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification?utm_source=chatgpt.com "AXObserverAddNotification(_:_:_:_:)"
[13]: https://stackoverflow.com/questions/68793532/how-use-axobserveraddnotification?utm_source=chatgpt.com "How use AXObserverAddNotification?"
[14]: https://superuser.com/questions/759535/open-google-chrome-specific-profile-from-command-line-mac?utm_source=chatgpt.com "Open Google Chrome Specific Profile From Command ..."
[15]: https://tahoeninja.blog/posts/launching-edge-with-different-profiles-using-shortcuts/?utm_source=chatgpt.com "Launching Edge With Different Profiles Using Shortcuts"
[16]: https://textslashplain.com/2022/01/05/edge-command-line-arguments/?utm_source=chatgpt.com "Edge Command Line Arguments - text/plain"
[17]: https://docs.uipath.com/studio/standalone/2024.10/user-guide/edge-extension-open-browser-non-default-browser-profile?utm_source=chatgpt.com "Studio - Open browser with non-default browser profile"
