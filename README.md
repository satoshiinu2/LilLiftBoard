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

## Packages

- `packages/com.satoshiinu.lilliftboard_1.0.0_iphoneos-arm64.deb` — rootless (Dopamine / palera1n rootless, `/var/jb`)
- `packages/com.satoshiinu.lilliftboard_1.0.0_iphoneos-arm.deb` — rootful (palera1n rootful etc.)

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

## Status

**Tested and working on a real device (iPhone 8, iOS 16) as of
2026-11-16** — the keyboard is raised as expected and the bottom row no
longer triggers the home gesture. Packages are also verified locally
(contents, arm64 Mach-O, code signature, filter plist, PreferenceLoader
entry).
