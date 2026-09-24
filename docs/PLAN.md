# WoW Forever Countdown: design plan

This is the implementation plan the app was built from. It went through several review rounds before any code was written, then had one major revision mid-build. It's kept here as a record of the decisions and the reasons for them. For how to build and use the app, see the [README](../README.md).

## Status

| Phase | Scope | State |
|---|---|---|
| 1 | Thin vertical slice: packaged and signed app, countdown, menu bar, resources, notifications, login item | Done |
| 2 | Visuals and the launch celebration | Done, as a WidgetKit widget (see the revision) |
| 3 | README, screenshots, GitHub release | Done: [v1.0.0](https://github.com/ksarantakos/countdown/releases/tag/v1.0.0) (arm64) |

## Refinements since the revision

- **Design reference**: the palette comes from the [WoW Forever site](https://worldofwarcraft.blizzard.com/en-us/forever)'s CSS: gold `#fff7c6 → #ffd254 → #c76700`, beige/bronze `#f3eee2 / #ebdec2 / #b1997f / #82705b`, teal `#00afd7 → #011c2b`, and the section gradient `#063149 → #017CAA`. The site's heading font is a licensed webfont, so the widget uses **Cinzel** (OFL) in its place, plus **Open Sans** (OFL), which is the site's actual body font. The motifs (teal disc glow, bronze octagon frame, diamond studs) are drawn in code; no Blizzard artwork is included.
- **Monochrome desktop mode**: when windows cover the desktop, macOS renders widgets in a vibrant or monochrome mode, where fills become solid white. The widget checks `widgetRenderingMode` and switches to outlines, with no glows or text shadows.
- **Spacing by visible glyphs**: Cinzel's line box is 1.35 em tall around 0.70 em capitals. Text boxes are sized to cap height (`cinzelCapBox`, `openSansCapBox`), so layout gaps equal the visible gaps.
- **Fireworks on an ultrawide**: a fading dark scrim, larger bursts and a bigger finale, so the show reads over busy windows.
- **Stale widget process**: macOS keeps the old widget extension running after a reinstall, so `build.sh` stops it and the new build renders.
- **Frozen widget timer (fixed after v1.0.0)**: the widget's seconds never ticked. Filling the timer text with a gradient makes WidgetKit draw it as a static image. Isolated by testing each style on its own; the timer now uses a solid color.
- **Leading zeros**: the system timer rounds up and drops leading zeros (`4:59:56`, `49:56`, `9:45`). Each day is split into timeline entries where a digit drops (at 35,999, 3,599 and 599 seconds left), and each entry adds a static `0`, `00:` or `00:0` prefix. The widget therefore always reads `HH:MM:SS`, and each day starts one second after the boundary so the widget matches the menu bar exactly. A unit test simulates the system timer around every boundary and compares it with `Remaining`. The timeline is capped by days rather than entries (default 400), so the whole countdown (about 4 entries a day) fits in one timeline that never needs a reload. If the cap is ever hit, the timeline is cut only at the end of a day.
- **Repository**: the existing private repo `ksarantakos/countdown` is used, rather than the `wow-forever-countdown` name the original plan proposed.

## Revision (during Phase 2): a real WidgetKit widget replaces the floating panel
You asked for a real desktop widget (gallery, native sizes, snapping) instead of the floating NSPanel. Decisions: **WidgetKit only** (the panel is removed), **XcodeGen** (`project.yml` committed, `.xcodeproj` generated), and **signing with your Apple ID team** (Xcode → Settings → Accounts; the team ID goes in a gitignored `Local.xcconfig`).

This supersedes §5 (desktop window), the widget parts of §7, and the layout and build details in §8:
- **Structure**:
  - `Package.swift` keeps only the `CountdownCore` library and its tests, so `swift test` still works.
  - The Xcode project has two targets:
    - **WoWCountdown.app**: the menu bar agent. It hosts the widget and handles fireworks, fanfare, notifications, launch at login and demo mode.
    - **WoWCountdownWidget.appex**: a WidgetKit extension, sandboxed, embedded in the app.
  - Both targets use CountdownCore as a local package.
- **Widget timeline**: one entry per day boundary (`target − k·86400`). Each entry shows the static day count plus `Text(timerInterval: entry…nextBoundary, countsDown: true)`, which ticks live as H:MM:SS. The last entry is at the target and shows NOW LIVE plus a relative "Launched … ago". The reload policy is `.never` because every date is absolute. The app calls `WidgetCenter.reloadAllTimelines()` on launch.
- **Limits you accepted**:
  - no live animation inside the widget (embers, shimmer and rolling digits are gone; there's static ornamentation instead);
  - the ticking part is a single H:MM:SS run, not separate tiles;
  - the widget goes monochrome when windows cover the desktop unless Widget style is set to Full-color;
  - the widget always shows the real target, because demo mode applies only to the app.
- **Sizes**: systemSmall, systemMedium and systemLarge. The widget adapts to `widgetRenderingMode` (full color vs. accented/vibrant).
- **Removed**:
  - `DesktopWidgetWindow`, `WidgetWindowController`, the SwiftUI panel view, and the placement and visibility settings;
  - `Placement` and its tests;
  - the menu items Show/Hide, Reset Position and Size.
  - Added instead: a menu item "Add the Widget to Your Desktop…" with instructions.
- **Resources**: the app icon comes from an asset catalog (the widget gallery shows the containing app's icon). `AppIcon.png` is a plain app resource loaded through `Bundle.main`. The "installed app with `.build` hidden" check still applies.
- **Build**: `build.sh` runs `xcodegen`, then `xcodebuild -scheme WoWCountdown -configuration Release` (arm64 by default, `--universal` fails loudly if incomplete), then copies the result to `dist/`, zips it and installs it. The signing team comes from `Local.xcconfig`. Without a team, the build fails with instructions rather than silently falling back to ad-hoc signing.
- **Verification**:
  - the widget appears in the gallery and on the desktop at each size;
  - timer text ticks;
  - the day boundary entries are correct (unit-tested in CountdownCore as `WidgetTimeline.entries`);
  - the NOW LIVE entry renders.
  - Screenshots are taken with `screencapture`.

## Original plan

Everything below is the plan as first approved. Where it conflicts with the revision above, the revision wins.

### Context
You want a native macOS app that counts down to the WoW Forever launch: **Nov 4, 2026, 3:00 PM PT**. That's 2026-11-04 23:00 UTC, because DST ends Nov 1.

- **Toolchain**: macOS 26.5, Swift 6.3, Command Line Tools only. There's no Xcode, so a WidgetKit extension isn't possible. The app is a **floating desktop widget** built with SwiftPM and packaged into a `.app` by a script.
- **Your choices**: desktop-layer draggable widget, S/M/L sizes, epic fantasy style, menu bar countdown, launch celebration, silent milestone notifications, launch at login, and a fanfare once at launch, with catch-up within six hours; also available through Preview Celebration.
- **Branding**: "WoW Forever" as styled text only. The widget shows no logo artwork. `icon_512x512.avif` becomes the app icon. `camelot-logo-gamepage.avif` isn't used.
- **GitHub**: the existing private repo, `ksarantakos/countdown` (you chose to keep this name), plus a Release with a zipped `.app`.

### Approach: thin vertical slice first
**Phase 1 (slice, verify the installed build before adding visuals):**
- The packaged app, installed and signed.
- One plain draggable widget showing the ticking countdown.
- The menu bar item.
- Resource loading, proven from the installed app.
- Notification permission and scheduling.
- Launch-at-login registration.

**Phase 2**: the epic visuals, S/M/L layouts, embers, fireworks and fanfare.

**Phase 3**: README, screenshots, GitHub repo and release.

### Layout
```
Package.swift                                   // macOS 14+, executable target + core library + tests
Sources/CountdownCore/                          // pure logic, no AppKit (testable)
  Countdown.swift                               // target date, breakdown, rounding
  LaunchState.swift                             // celebration decision logic
  Milestones.swift                              // milestone list → (id, fireDate, text)
Sources/WoWCountdown/
  main.swift, AppDelegate.swift
  CountdownController.swift                     // single 1 Hz clock, publishes state; owns celebration trigger
  DesktopWidgetWindow.swift                     // NSPanel + screen-aware position persistence
  WidgetView.swift, Theme.swift, EmberField.swift
  StatusItemController.swift
  CelebrationController.swift, Fanfare.swift
  Notifications.swift, LoginItem.swift, Settings.swift
  ResourceLocator.swift
  Resources/AppIcon.png                         // committed PNG (converted once from the AVIF)
Tests/CountdownCoreTests/
scripts/convert-assets.sh                       // one-off AVIF → PNG/icns; output committed
build.sh
```
The committed files are the PNG and a generated `AppIcon.icns`. Normal builds never need the AVIF files.

### Key design decisions

#### 1. Resources
- Assets live in `Sources/WoWCountdown/Resources/` and are declared with `.process("Resources")`.
- `ResourceLocator` finds the SwiftPM bundle `WoWCountdown_WoWCountdown.bundle` by looking in `Bundle.main.resourceURL` first. It falls back to `Bundle.module` only for `swift run`.
- `build.sh` copies that bundle into `Contents/Resources/`.
- **Verification**: temporarily rename `.build` and launch the installed app. It must still find its assets.

#### 2. Countdown math and rounding (CountdownCore)
- The target is built from explicit `TimeZone(identifier: "America/Los_Angeles")` components.
- `remainingSeconds = ceil(target - now)` while the target is in the future. The display therefore reads 00:00:01 until the instant of launch and never shows all zeros early.
- `isLive = now >= target`.
- A `breakdown` function returns days, hours, minutes and seconds.

#### 3. CountdownController and the celebration policy
- A single controller runs a 1 Hz timer that is independent of any view. The views and the menu bar observe it.
- It also re-evaluates on `NSWorkspace.didWakeNotification`, significant time changes, and app launch.
- Detection compares state, not exact ticks: the controller celebrates when it sees `wasLive == false → isLive == true`, or the equivalent on the first evaluation.
- The flag is keyed by the target, e.g. `celebrated.2026-11-04T23:00:00Z`, so if the date ever changes, an old flag doesn't carry over.
- The flag is written to UserDefaults **before** any fireworks or audio start. It doesn't call `synchronize()`, which Apple says is unnecessary. This is best-effort persistence: a crash during playback is unlikely to cause a repeat, but that isn't guaranteed, and that's acceptable for this app.
- **Audio policy: "once at launch, with catch-up within six hours; also available through Preview Celebration."** The fanfare can therefore play after a wake or reopen instead of strictly at zero, and the README says so. On launch, wake or relaunch, if the target has passed and the flag for this target isn't set:
  - if the target passed **6 hours ago or less**, it celebrates once and marks the flag;
  - if it passed more than 6 hours ago, it marks the flag silently and just shows NOW LIVE.
- It never celebrates twice.

#### 4. Demo isolation
- `--demo-seconds N` sets up a `DemoContext` with the target at now+N and an **in-memory** settings store. Nothing is written to the celebration flag or the notification schedule. The window title and menu bar show a "DEMO" badge.
- In demo mode, launch-at-login changes are disabled: the menu item is greyed out and marked "(demo)", and no `SMAppService` calls are made. Notification authorization and scheduling are also skipped.
- The menu's **Preview Celebration** plays the fireworks and fanfare only. The countdown state doesn't change.
- Before launch-arg tests, the running app is quit with `osascript -e 'quit app "WoWCountdown"'` or `pkill`.

#### 5. Desktop window (prototyped and verified in Phase 1)
- It starts as a borderless non-activating `NSPanel` at `desktopIconWindow + 1` with `[.canJoinAllSpaces, .stationary, .ignoresCycle]`.
- Dragging uses a custom `mouseDown`/`mouseDragged` handler with `acceptsFirstMouse`, so it works while the app is inactive.
- Position is saved as `{screen displayID/localizedName, origin relative to that screen's visibleFrame}`.
- On `didChangeScreenParametersNotification`, or when the size changes, the window is restored to its saved screen. If that screen is gone it falls back to the main screen, and it's always clamped inside a `visibleFrame`.
- **Manual test matrix**:
  - drag while another app is focused
  - Show Desktop (F11 / hot corner)
  - Mission Control
  - switching Spaces
  - Stage Manager on and off
  - unplugging or re-plugging an external monitor
  - S→L resize near a screen edge

  Flags get adjusted based on what this shows.

#### 6. Login item and notifications as system state
- **Login item**:
  - The menu checkmark is derived from `SMAppService.mainApp.status` each time the menu opens.
  - `.requiresApproval` shows "Approve in System Settings…", which calls `SMAppService.openSystemSettingsLoginItems()`.
  - Registration errors appear in an alert.
- **Notifications**:
  - On launch the app checks `getNotificationSettings`:
    - `.notDetermined`: explicitly calls `requestAuthorization(options: [.alert])`, then continues according to the result.
    - `.denied`: the menu shows "Notifications off — Open Settings".
  - When authorized, it reconciles against the desired milestone set, where each entry has an id, a fire date and content:
    - it removes pending `milestone.` requests that aren't in the desired set;
    - it **replaces** any request whose id exists but whose trigger date, title or body differs;
    - it adds any missing requests.
  - The reconcile diff is a pure CountdownCore function, so it can be tested.
  - Triggers are `UNCalendarNotificationTrigger` with explicit time zone components. Past dates are skipped.
  - Milestones: 30d, 14d, 7d, 3d, 1d, 12h, 1h, 10m, and launch.
  - **Sound is nil.** Notifications are silent; the only audio is the fanfare, played once at launch, with catch-up within six hours; also available through Preview Celebration.

#### 7. Visuals (Phase 2)
- **Card**: a dark stone gradient with a double gold hairline border, a glow and a vignette.
- **Title**: a "WoW Forever" wordmark in serif with a gold gradient.
- **Numerals**: heavy serif with `.contentTransition(.numericText(countsDown: true))`.
- **Background**: rising embers in the card.
- **Sizes**:
  - **S** (~170²): days plus hh:mm:ss.
  - **M** (~360×220): four tiles.
  - **L** (~420²): tiles, a day-progress ring, and a "Nov 4 · 3 PM PT" footer.
- **Live state**: pulsing "NOW LIVE" and "Launched X ago".
- **Fireworks**: a click-through overlay on every screen for about 15 s.
- **Fanfare**: synthesized with AVAudioEngine.
- **Accessibility and hiding**:
  - With `accessibilityReduceMotion` on: no embers, no shimmer, and fireworks become a simple fade and glow.
  - When the widget is hidden or occluded (`occlusionState`), decorative animation stops. The 1 Hz clock keeps running.

#### 8. Build and distribution (`build.sh`)
1. Assets are already committed PNG and icns files. No conversion happens during the build.
2. By default it builds **Apple Silicon only** (`swift build -c release --arch arm64`).
   - `./build.sh --universal` also builds x86_64 and runs `lipo -create`. If any architecture fails, it exits non-zero with a clear error. It never silently downgrades.
   - The README and release notes state which architectures the attached ZIP supports, checked with `lipo -archs`.
3. Assemble `WoWCountdown.app`:
   - binary
   - `Info.plist` with `LSUIElement`, bundle id `com.ksarantakos.wowcountdown`, the version, and `CFBundleIconFile`
   - `AppIcon.icns`
   - the resource bundle
4. Sign last: `codesign --force --deep -s - WoWCountdown.app`, then check it with `codesign --verify`.
5. Install to `~/Applications`, and zip to `dist/WoWCountdown.app.zip` with `ditto -c -k --keepParent`.

### GitHub
- `git init`, then a `.gitignore` for `.build/`, `*.app`, `dist/` and `.DS_Store`.
- A README covering features, build steps, the supported architecture(s), and Gatekeeper instructions. The Gatekeeper steps: open the app once, then go to **System Settings → Privacy & Security → Open Anyway**, because the app is ad-hoc signed and not notarized. Screenshots go in `docs/`.
- `gh repo create ksarantakos/wow-forever-countdown --private --source . --push`.
- `gh release create v1.0.0 dist/WoWCountdown.app.zip` with the same Gatekeeper and architecture notes.
- Commits keep the configured git author, Kyri Sarantakos. A Claude Co-Authored-By trailer goes only on commits whose content Claude actually wrote. Commits made by you alone don't get one.

### Verification
- **Unit tests** (`swift test`, CountdownCore): if the CLT has no XCTest or Testing, a `--self-test` executable mode runs the same cases. The cases:
  - DST-correct UTC target (23:00Z)
  - 0.4 s before the target shows 00:00:01 and not live
  - exactly zero is live
  - sleeping across the launch (last seen before, now 2 h after) celebrates once
  - waking 10 h after doesn't celebrate but marks the flag
  - relaunch after celebrating doesn't celebrate
  - the flag is written before effects start
  - a flag for a different target key doesn't suppress the celebration
  - reconcile diff: add missing, replace changed, remove stale, and keep unchanged requests as they are
  - demo context writes nothing to the persistent store
  - the milestone list skips past dates
  - position clamping when the saved screen is missing or the frame is off-screen, via a pure `clamp(frame:screens:)` function
- **Phase 1 installed-build checks**:
  - quit any running instance, `./build.sh`, rename `.build`, then `open ~/Applications/WoWCountdown.app`
  - the widget renders, drags while inactive, and keeps its position after relaunch
  - the menu bar ticks
  - notification permission is prompted and the pending milestone requests are logged
  - the login item status is reflected in the menu
  - work through the manual desktop test matrix from §5
- **Phase 2**:
  - `screencapture` of each size so the visuals can be iterated on
  - `--demo-seconds 10` shows the fireworks, the fanfare and the NOW LIVE state; afterwards the real flag, the notifications and the `SMAppService` status are all unchanged
  - Preview Celebration leaves the countdown intact
  - Reduce Motion is honored
