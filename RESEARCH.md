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

## Dock buttons (v1.1.0) — DockX

Sources cloned and read on 2026-11-16:

- **DockX** — github.com/udevsharold/DockX (`DockX.xm`,
  `DXCollectionView.m`, `DockX.h`, `TextOperation.h`): adds a shortcut
  bar as a subview of `UIKeyboardDockView` and runs actions on
  `[UIKeyboardImpl activeInstance].privateInputDelegate ?:
  .inputDelegate` (a `UIResponder<UITextInput>`): `copy:` / `cut:` /
  `paste:` / `selectAll:` directly on the delegate with pasteboard +
  `-[UIKeyboardImpl insertText:]` fallbacks, `undoManager` for
  undo/redo, `-[UIKeyboardImpl dismissKeyboard]` for dismissal.
  `UIKeyboardDockView` exposes `leftDockItem` / `rightDockItem`, whose
  views delimit the free center area of the dock.
- **Barmoji** (CP Digital Darkroom): same insertion point — a custom
  view inside `UIKeyboardDockView`, between the globe and dictation
  items.

LilLiftBoard's dock buttons adopt this approach (dock subview; actions
dispatched to the input delegate, with cursor movement through the
public `UITextInput` protocol). No code was copied; the implementation
is original.

Layout note (2026-11-16, confirmed on a real iPhone 8): the bar was
initially centered in the free area delimited by `leftDockItem` /
`rightDockItem`. On Home-button iPhones those dock items do not exist —
the globe and dictation keys sit in the keyboard's bottom key row — so
the dock-item lookup and its fallback branch were removed. The bar now
always spans the full dock width and centers its buttons within it.

Real-device test (2026-11-16, iPhone 8, Japanese flick keyboard): the
settings UI worked, the lift produced an empty strip of about 40 pt
below the keys, but no buttons appeared. On this device / input mode
the dock view evidently never gets a usable frame (height at least
24 pt, in the lifted strip), so a dock-hosted bar alone is not enough.
Fix: `UIPeripheralHostView` — which always spans the whole keyboard —
hosts a fallback bar in the bottom `lift` points of its bounds, shown
only while no dock-hosted bar is visible in the same hierarchy, so the
two never appear at once. `UIKeyboardLayoutStar`'s `layoutSubviews`
also re-syncs the host bar via its superview, in case the host view's
own layout is not called again after the keys are laid out.

Second test (2026-11-16, after the fallback build): still nothing.
Reviewing the code shared by *all* hosts turned up a likelier single
cause: the portrait check read the orientation from the *keyboard
window's* scene. That window has no scene of its own, so the check fell
back to the window's bounds — the keyboard rectangle, wider than tall
even in portrait — and classified every portrait keyboard as
landscape, hiding the bar in every host at once (the lift itself does
not use this check, which is why it kept working). The check now asks
the app's foreground-active window scene, with the screen bounds as
the last resort. The same build adds a third host that does not depend
on the keyboard's internal view layout at all — the keyboard window
itself (`UIRemoteKeyboardWindow` / `UITextEffectsWindow`), synced from
its `layoutSubviews` and from `UIKeyboardDidShowNotification` — and
gives the buttons an explicit label-color tint and a 20 pt symbol
configuration, so a rendered button can no longer be near-invisible.
With that build the buttons were confirmed working on the device.

Follow-ups from that test (same day): the buttons were split into
left / center / right groups (three preference keys, three settings
sections, anchored layout), the settings list switched to the
standard table editing (edit mode with delete controls and reorder
handles, like the Control Center settings) instead of long-press
drag, the defaults gained the cursor keys with line-start / line-end
and dismiss in their popups, Delete and Return key actions and
one-tap symbol presets (stored as Insert Text) were added, and the
button tint now resolves the label color against the keyboard view's
trait collection so it follows the keyboard's key text color
(keyboard appearance), not the host app's.

After the first on-device test of that build, the user arranged the
buttons into a layout they liked and asked for it as the new default:
Copy / Paste / Undo on the left, the cursor keys in the center,
Dismiss Keyboard on the right (Paste has no popup: a Dismiss entry
there was the user's own slip while arranging, and the Undo left
behind it read as an arbitrary pairing). The
symbol preset list was dropped again in favour of plain Insert Text
(symbols are typed with the keyboard like any fixed phrase), the
picker's add flow now finishes on tap instead of select-then-Done,
long-press drag reordering returned alongside the standard edit mode,
and a Side Margin setting (0–40 pt, default 20 pt) insets the groups
from the strip's edges.

On-device, some apps then showed the default buttons despite a saved
configuration. Cause: preferences were read through an
`NSUserDefaults` suite, and inside sandboxed app processes that read
can come back empty (cfprefsd access differs per process), so the
store saw "nothing saved" and substituted the defaults; system apps
read the same suite fine, hence only *some* apps. Fix: `LLBLoadPrefsDictionary`
merges the preferences plist (rootless
`/var/jb/var/mobile/Library/Preferences/…` first, then the rootful
path) with the suite; both the button store and the scalar settings
(lift, size, spacing, margin) go through it.

The first version of that merge let the file win, which broke the
settings UI itself: saving goes through the suite, cfprefsd flushes
to the plist only later, so on returning to the buttons list its
`viewWillAppear` reload re-read the stale file and the just-added
button vanished until the screen was reopened. Final shape: the suite
wins where it can be read, the file fills in where it cannot, and
saving buttons also writes through to the plist file immediately so
file-only readers (sandboxed apps) see changes without waiting for
the flush.

Two more on-device fixes from the same round: the buttons list lost
its Edit button (as `leftBarButtonItem` it replaced the back button,
so the screen felt impossible to leave; reordering is long-press
drag, deleting is swipe), and the button tint now resolves against
the keyboard layout view's traits — the key plane carries the
keyboard appearance, while the dock/host views keep the host's
traits, which mismatched in Spotlight.

Post-1.1.0: an Icon Weight setting (SF Symbol weight, Ultralight–
Black, default Light) first used a PSLinkListCell /
PSListItemsController specifier with NSNumber values, which crashed
Preferences on tap. It was replaced with a PSLinkCell whose action
presents an action sheet from the root list controller (the same
action pattern the Buttons row already used), storing the picked
index and posting the prefs-changed notification directly.

Post-1.2.0: horizontal drags on the whole bar scrub the caret. A
UIPanGestureRecognizer subclass withholds its touchesMoved from
super until the touch has travelled 8 pt horizontally, so below the
threshold the touch still belongs to the buttons' tap / long-press
recognizers (whose allowableMovement is the same 8 pt); a
vertically dominant travel fails the recognizer. Past the
threshold the recognizer claims the touch (cancelling the button
recognizers), any open popup is dismissed, and the caret is set
from a drag-start anchor plus the accumulated character count
(10 pt per character, travel past 120 pt counting double), applied
through the UITextInput selection so it works in any app the tweak
is injected into.

The popup gained flick selection in the same round: the scrub
recognizer's delegate refuses to begin while a popup is open, so
the touch that long-pressed keeps belonging to the long-press
recognizer, whose Changed events highlight the popup button under
the finger and whose Ended either runs the highlighted item,
leaves the popup open (finger released back on the anchor button —
a plain hold), or dismisses it (released anywhere else). The
long-press allowableMovement is generous (300 pt) for this: early
sideways drags are still pre-empted because the scrub recognizer
cancels the touch when it claims it, long before the press fires.
