# LilLiftBoard

Raises the system keyboard on Home-button iPhones (iPhone 8 etc.) so the
bottom key row no longer sits on the screen edge, where iPhone X style
gesture tweaks (GesturesXV and similar) misread touches as a home swipe.

## How it works

Hooks `+[UIKeyboardImpl deviceSpecificPaddingForInterfaceOrientation:inputMode:]`
and adds a bottom padding (default **30 pt**, adjustable 0–50 pt in
Settings → LilLiftBoard). This is the same mechanism iOS itself uses for
the dock area on iPhone X and later, so the keyboard background fills the
added space and the globe / dictation buttons move with it — nothing is
left transparent under the keys. `UIKeyboardDockView` bounds are extended
slightly to match, as in the classic implementations (see RESEARCH.md).

Guards:

- Does nothing when the system already reports a bottom padding
  (notched devices), when disabled, or when the lift is 0.
- Portrait only; landscape is untouched.
- iPhone only — the tweak does not activate on iPad
  (split / floating keyboards unaffected).
- Settings changes are picked up via a Darwin notification; they apply
  the next time the keyboard is laid out (Respring button provided for
  apps that keep the old layout).

Injection is via the `com.apple.UIKit` filter, i.e. every app process
that hosts the system keyboard, same as Little11's UIKit component.

## Dock buttons

The space the lift creates below the keyboard (between the globe and
dictation keys) can hold configurable action buttons — the same spot
Barmoji and UnderDock use on notched devices.

- Buttons appear when the tweak and Dock Buttons are enabled, the lift
  is at least 20 pt, and the device is in portrait.
- Buttons are organized in three groups — **Left**, **Center** and
  **Right** — anchored to the corresponding side of the strip (the
  center group is centered between the other two). Their color follows
  the keyboard's own key text color.
- Default setup: **Copy** (long-press popup: Cut, Select All),
  **Paste** and **Undo** (Redo) on the left; **Cursor Left**
  (Start of Line, Dismiss Keyboard) and **Cursor Right** (End of Line,
  Dismiss Keyboard) in the center; **Dismiss Keyboard** on the right.
- Long-pressing a button opens a small panel above it with that button's
  own sub-buttons; tapping one runs it and closes the panel.
- Available actions: Cut, Copy, Paste, Select All, Undo, Redo, Cursor
  Left, Cursor Right, Start of Line, End of Line, Insert Text (with a
  per-button custom text — a single symbol typed there works as a
  symbol button), Dismiss Keyboard, Delete, and Return. Actions run on
  the keyboard's current text input (`UIKeyboardImpl`'s input
  delegate), the same approach DockX uses.

### Configuring

Settings → LilLiftBoard → **Dock Buttons** (on/off) → **Buttons**:

- The list has a section per group (Left / Center / Right). Tap **+**,
  choose a group, then tap an action in the picker to add it right away
  (Insert Text asks for its text first).
- Reorder by long-press dragging a row — across groups too — or swipe
  a row to delete it. (There is deliberately no Edit button: it would
  take the back button's place in the navigation bar.)
- Tap a row (or its ⓘ) to edit it: change the tap action, edit the
  long-press popup items (add / delete / reorder, same list UI), set
  the custom text for Insert Text, or delete the button.
- **Reset to Defaults** at the bottom restores the default setup.

The Dock Buttons settings also have sliders for the button size
(20–60 pt), the spacing between buttons (0–24 pt) and the side margin
insetting the groups from the strip's edges (0–40 pt, default 20 pt).

Changes are saved to the `dockButtons` / `dockButtonsCenter` /
`dockButtonsRight` preferences and picked up by the tweak immediately
(Darwin notification); they apply the next time the keyboard is laid
out.

The settings pane also has a **Test** scratch text field, so the dock
buttons (copy, paste, cursor movement…) can be tried without leaving
Settings; its contents are not saved.

## Packages

- `packages/com.satoshiinu.lilliftboard_1.1.0_iphoneos-arm64.deb` — rootless (Dopamine / palera1n rootless, `/var/jb`)
- `packages/com.satoshiinu.lilliftboard_1.1.0_iphoneos-arm.deb` — rootful (palera1n rootful etc.)

Target: iOS 15–16, arm64. Depends on mobilesubstrate (ElleKit) and
preferenceloader.

> **Upgrading from the old KeyboardLift package:** this tweak was renamed
> from KeyboardLift (`com.satoshiinu2.keyboardlift`) to LilLiftBoard.
> Uninstall the old KeyboardLift package first, then install LilLiftBoard —
> both packages hook the same keyboard padding, so do not keep both.

## Building

- macOS / CI: `.github/workflows/build.yml` (Theos + iPhoneOS 16.5 SDK,
  builds both package schemes).
- This Linux VM: `./build.sh` — builds on a `/tmp` copy because ldid
  cannot sign in place on the workspace filesystem; Theos, the SDK,
  clang-20/lld shims and a self-built ldid live under `~/workspace/theos`
  and `~/workspace/bin`.

## Development

This tweak was developed with the help of an AI assistant (Muse by Meta),
under satoshiinu's direction. The problem definition, desired behavior,
name, and the final testing on a real device are the author's; the
research, implementation, and packaging were carried out in collaboration
with the AI. The classic implementations consulted along the way are
credited in [RESEARCH.md](RESEARCH.md).

## Status

**Tested and working on a real device (iPhone 8, iOS 16) as of
2026-11-16** — the keyboard is raised as expected and the bottom row no
longer triggers the home gesture. Packages are also verified locally
(contents, arm64 Mach-O, code signature, filter plist, PreferenceLoader
entry).

The dock buttons added in 1.1.0 were confirmed working on the same
device on 2026-11-16 (buttons render in the lifted strip and copy /
paste work in the settings Test field).
