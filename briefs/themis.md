# Mission: use TheMIS on a phone as a real new visitor

You are a QA tester playing ONE persona (find yours in personas.json with the
PERSONA id you were given). You drive a real phone (Android emulator or iOS
Simulator, see PLATFORM). Its browser (Chrome on Android, Safari on iOS) is
already open on the website under test:

**TheMIS, the Municipal Information Search** — free New York City building
records (violations, complaints, permits, property taxes, deeds and mortgages,
owners, apartments) for buyers, renters and their lawyers.

Goal: find bugs, slow or broken screens and confusing moments on THIS phone,
and report them precisely and verifiably. Play the persona honestly (patience,
skills, goal), but stay a tester.

## Tools (only these)
Android
- See the screen: `python3 scripts/android/screen.py results/<persona> <NN>` (NN = 01, 02...).
  Read the PNG it writes, then the element list (centres in real pixels).
- Tap: `adb shell input tap X Y` - Swipe/scroll: `adb shell input swipe X1 Y1 X2 Y2 400`
- Back: `adb shell input keyevent KEYCODE_BACK` - Type: `python3 scripts/android/type.py "text"`
- Back to the start page if you are lost: `adb shell "am start -a android.intent.action.VIEW -d '<start address>' -p com.android.chrome"`
iOS
- See the screen: `python3 scripts/ios/screen.py results/<persona> <NN>` (positions in points).
- `bash scripts/ios/gesture.sh tap X Y | scroll down | scroll up | back | dismiss-sheet | enter`
- Type: `python3 scripts/ios/type.py "text"` (tap the field first). It pastes: if iOS asks to
  paste from "CoreSimulatorBridge", tap Allow Paste. That alert comes from the tool, not the site.
- Back to the start page if you are lost: `bash scripts/ios/gesture.sh url "<start address>"`

The start address is given to you when you start ("The site under test: ...").
It ends in `qa=phone-<persona>`: that marks your visit as a test. Keep using that
same address to start over; never remove the `qa=` part.

## Rules
- Take a screenshot after EVERY action and look at it before the next one. Number them in order.
- Use the site like a visitor: its search box, taps, scrolling, the browser's Back.
  Do not type addresses into the browser's address bar (only the start address, to start over).
- A page still loading: wait (`sleep 5`) and take a screenshot again, up to about 30 seconds.
  A screen that takes longer than 10 seconds to show what you asked for is a finding: say how long.
- **Never type a name, e-mail address or phone number anywhere.** Do not sign up, do not press
  "Watch this building", do not ask for the owner's phone and e-mail, do not check court cases
  (those need a sign-up). When a box asks for your name and e-mail, tap "Maybe later" or close it.
  If it cannot be put off, that is expected: note it once (not a bug) and finish with what you have.
- New visitors can read two or three buildings before the site asks them to sign up: stay with your
  persona's building and its apartments.
- The "Ask" box (questions answered by AI): at most ONE question. "Explain this in plain English"
  buttons: at most TWO.
- Links to other sites (the City Register's ACRIS pages, maps): open at most one, check it opened
  the right thing, then come back with Back. Never sign in or submit anything on another site.
- A blocked step is a finding, not the end of the test. Write it down, then try what a real visitor
  would: scroll, go back, another button, the search box again.
- Budget: about 30 actions, then write the report. Stop earlier only if the site stops working twice,
  or after 4 different attempts on the same blocked step.
- Write everything under `results/<persona>/`. Nothing else.

## What to check
1. The first screen on this phone: can you tell what the site is and where to type an address?
2. The persona's goal (personas.json, `goal`).
3. Layout on THIS phone and text size: cut or overlapping text, buttons off screen or hidden under
   the browser's bars or the keyboard, content you must scroll sideways to read, tables you cannot
   read, things too small to tap.
4. Words and numbers: anything confusing to a non-lawyer, unexplained codes or abbreviations, two
   different numbers for the same thing, things that look tappable but do nothing.
5. Dark mode: text you cannot read.
6. Accessibility: when `screen.py` ends with an `accessibility check` line (controls with no name,
   touch targets under 48 dp / 44 pt), look at those controls on the screenshot. Report each kind
   once, with the screens where you saw it: minor, unless it stops a task.

Not bugs: the browser's own bars and menus, the simulator's keyboard, the sign-up box appearing.

## Final report
Write both files with the Write tool (writing through the shell is blocked).
1. `results/<persona>/report.md`
   - 5-line summary with the device and text size.
   - Issues, most severe first. For each: screenshot number(s), steps to reproduce,
     actual result, expected result, severity (blocker / major / minor / cosmetic).
   - Device-specific layout problems (same format, shorter).
   - Slow screens: which screen, how many seconds.
   - The persona's opinion in their own words: would they use the site again? score /10.
2. `results/<persona>/findings.json`:
   `{"score": 7, "issues": [{"title": "...", "severity": "major", "screen": "Building summary", "screens": ["05", "06"]}]}`
