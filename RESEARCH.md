# Existing implementations — what was actually read

Sources cloned and read on 2026-11-16 (copies under `research/`):

## Little11 — github.com/ryannair05/Little11 (fork of LittleXS)

`TweakUI.xm`, group `KeyboardDock`:

- `+[UIKeyboardImpl deviceSpecificPaddingForInterfaceOrientation:inputMode:]`
  — returns the original `UIEdgeInsets` with `bottom` forced to **46**
  (skipped when Barmoji/DockX is present).
- `-[UIKeyboardDockView bounds]` — height **+15**.

Its `ForceDefaultKeyboard` group does the inverse (bottom = 0).
The filter plist (`Little11UIKit.plist`) injects via `com.apple.UIKit`,
i.e. into every UIKit app process, which is where the system keyboard lives.
Bottom inset for apps is done separately in the same file
(`-[UIWindow safeAreaInsets]`, bottom = 20) — not needed for this tweak.

## LittleXS — github.com/alexcpr/LittleXS (original)

`Tweak.xm`, group `KeyboardDock`: identical approach —
`deviceSpecificPadding…` bottom = **40** (80 with Barmoji),
`UIKeyboardDockView bounds` height +15 (or origin.y shift with Barmoji).

## KeyboardX — clarityzzz (Packix, "open source" link)

The Packix page links to `github.com/clarityzzz/KeyboardX`, which now
returns **404** (deleted/renamed), so its source could not be read.
Its description matches the same idea (ports the iPhone X keyboard,
iOS 11–12 only).

## License note

Little11 ships a Vim-style license text and LittleXS an unrelated MIT
text; regardless, no code was copied. Only the *approach* — which Apple
private API the system itself uses for the keyboard's bottom padding —
was adopted, and LilLiftBoard's implementation was written from scratch
(parameterised lift amount, guards, its own prefs handling).

## Conclusion

`deviceSpecificPaddingForInterfaceOrientation:inputMode:` is UIKit's own
knob for this: on notched devices its bottom value is what creates the
dock area below the keys (keyboard background extends into it and the
globe/dictation buttons are laid out there by the system). Setting it on
a Home-button device therefore raises the keys *and* fills the gap
natively — no frame shifting, no transparent strip.
