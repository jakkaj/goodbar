Yes—with a small amount of native glue you can treat **each Edge profile as its own pin** (name, color, icon) and launch/focus it just like Windows.

### What to read

* **Profiles live in** `~/Library/Application Support/Microsoft Edge/` (`Default`, `Profile 1`, `Profile 2`, …). ([Microsoft Learn][1])
* **Metadata is in** `…/Local State` (JSON): `profile.info_cache` contains entries keyed by profile dir with fields such as `name`, `shortcut_name`, `avatar_icon`, `default_avatar_fill_color`, `default_avatar_stroke_color`, and `profile_color_seed`. (Chromium keeps these keys here; Edge inherits this.) ([Diffchecker][2], [Chromium Git Repositories][3])

### How to launch/focus a specific profile

* Call Edge with a profile selector. Two reliable forms on macOS:

  * `"/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" --profile-directory="Profile 1"`
  * Or `open -na "Microsoft Edge" --args --profile-directory="Profile 1"`
    This works even if Edge is already running; omit `--new-window` to reuse an existing window of that profile, add it to force a new window. ([Gist][4])

### How to show per‑profile color & icon in your bar

* **Color:** read `default_avatar_fill_color`/`default_avatar_stroke_color` (signed 32‑bit ARGB; convert to hex) or `profile_color_seed` and paint your tile/badge accordingly. ([Chromium Git Repositories][3], [Diffchecker][2])
* **Icon:** `avatar_icon` is typically a `chrome://theme/IDR_PROFILE_AVATAR_XX` resource. Since you can’t fetch that URL externally, do what Chromium/Edge does on Windows: **badge the base app icon with a colored profile avatar** (circle or silhouette) you render yourself. (That’s literally how Windows profile shortcuts are produced.) ([chromiumcodereview.appspot.com][5])

### Pin model (Edge profiles)

Store pins like:

```json
{
  "bundleId": "com.microsoft.Edge",
  "profileDir": "Profile 1",     // "Default" | "Profile 1" | …
  "displayName": "Work",
  "colors": { "fill": -14737376, "stroke": -1 },  // from Local State
  "avatarIconUrl": "chrome://theme/IDR_PROFILE_AVATAR_26"
}
```

* **Click** → run Edge with `--profile-directory="<profileDir>"` (and your “open on this display” placement code). Reuse/new‑window behavior controlled by `--new-window`. ([Gist][4])
* **Right‑click** → Jump List per profile (Recent/Tasks) as you already planned.

### Showing running Edge windows per profile

macOS doesn’t expose a built‑in “profile id” on windows. Practical options:

1. **Command‑based focus (recommended):** when the user clicks a profile pin, *re‑issue* the same launch command without a URL—Edge brings that profile’s existing window forward if one exists, or spawns a new one. You don’t need to identify windows yourself. ([Gist][4])
2. **Heuristic tagging:** when you launch a profile, watch for the next Edge window that appears on that display (AX notifications) and tag it to that profile; keep that mapping until the window closes.
3. **Advanced (optional):** for richer attribution, read Edge’s `Local State` (`last_active_profiles`) to infer the most recently activated profile before a window burst, but it’s rarely necessary. ([Diffchecker][2])

### Flutter/native pieces

* **Dart pin schema** includes `profileDir`.
* **MethodChannel**: `launchEdgeProfile(profileDir, newWindow: false)` shells the command above; reuse your existing AX “move to this display” step afterward.
* **Renderer**: draw the base Edge icon, add a small circular badge using the profile’s fill/stroke (or your own vector silhouette), and tint tile accents with `profile_color_seed`.

### Why this is “Windows‑like”

Windows achieves the effect by creating **per‑profile shortcuts** whose icons are **badged with the profile avatar** and whose arguments lock to that profile. You’re replicating both: **distinct visual identity** and **argument‑based profile binding**. ([chromiumcodereview.appspot.com][5])

If you want, I can drop a tiny Swift helper that parses `Local State` and returns `{dir, name, fill, stroke, colorSeed}` for your Flutter UI to consume.

[1]: https://learn.microsoft.com/en-us/answers/questions/2403928/i-cannot-locate-localappdatamicrosoftedgeuser-data?utm_source=chatgpt.com "I cannot locate \"%LocalAppData%\Microsoft\Edge\User ..."
[2]: https://www.diffchecker.com/KB7ORfCU/?utm_source=chatgpt.com "Local State"
[3]: https://chromium.googlesource.com/chromium/src/%2B/lkgr/chrome/browser/profiles/profile_attributes_entry.cc?utm_source=chatgpt.com "chrome/browser/profiles/profile_attributes_entry.cc"
[4]: https://gist.github.com/ciphertxt/bf17716b2ca3c391a998f206abb9f08e "Opens a specific Microsoft Edge profile by name on macOS · GitHub"
[5]: https://chromiumcodereview.appspot.com/14137032/diff/248001/chrome/browser/profiles/profile_shortcut_manager_win.cc "
    
    
      chrome/browser/profiles/profile_shortcut_manager_win.cc -
    
    
      Issue 14137032: Create profile .ico file on profile creation -
    
    Code Review
  "
