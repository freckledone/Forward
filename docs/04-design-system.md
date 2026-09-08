# 04 — Design System

Source of truth for Further's visual and interaction language.

Governing principle: **Apple's language, spoken confidently.** The reference isn't Settings — it's **Fitness** and **Weather**. Native means we use system fonts, semantic colors, standard controls, and Dynamic Type. It does NOT mean plain. Fitness uses gradients, hero numeric displays, tinted cards, and rich chart fills — all of that is fair game. What we reject is *anti-Apple* aesthetics: startup-SaaS card stacks, neon marketing gradients, gamification confetti, custom fonts, custom nav bars.

Anything that would look at home in the current Apple Fitness app is on the table for Further.

---

## 1. Typography

- **Font:** system default (SF Pro). Never a bundled or custom font.
- **Text styles:** SwiftUI `.font(.largeTitle | .title | .title2 | .title3 | .headline | .body | .callout | .subheadline | .footnote | .caption)`. Never hard-coded point sizes for body copy.
- **Hero numeric displays (Fitness-inspired).** Big stat numbers on Progress cards and End-Workout summary use:
  - Weight: `.font(.system(size: 44, weight: .bold, design: .rounded))` with `.monospacedDigit()`.
  - Card headline: `.font(.system(.title, design: .rounded, weight: .semibold))`.
  - These are the visual anchors of the app — confident, chunky, alive. Like the number inside a Fitness ring.
- **Inline numeric fields (weight/reps/RIR in Active Workout rows):** `.body.monospacedDigit()`.
- **Section headers on hero surfaces** (Progress, End Workout): `.title2.rounded()`. Not shouty caps.
- **Dynamic Type:** every screen supports Dynamic Type end-to-end. Hero displays scale gracefully; at `.accessibility5` they may wrap but never truncate.

## 2. Color

Rich, purposeful color — not everything is grey.

- **Accent color:** system `.accentColor` set at the app root. **Proposed: a warm orange (`#F97316`-ish, but from an asset catalog so it's tunable).** Feels like effort, warmth, forward motion. Not Apple's default blue (already every app's tint), not neon.
- **Card tints — the Fitness move.** Progress-card backgrounds are **subtly tinted** by the exercise's primary muscle group. Chest → warm peach; back → cool blue; legs → deep purple/violet; shoulders → gold; arms → green; core → grey-neutral. Each tint uses a `LinearGradient` from ~10% opacity top-left to ~4% opacity bottom-right of the muscle color, over `Color(uiColor: .secondarySystemGroupedBackground)`. Result: cards feel identifiable at a glance without being loud. This is the single most Fitness-like decision in the whole system.
- **Text and structural surfaces:** still semantic. `Color.primary`, `.secondary`, `.systemBackground`, `.systemGroupedBackground`.
- **Gradients are permitted with purpose:** hero card backgrounds (per above), chart line fills, and PR badges. Random decorative gradients on nav bars or buttons are still out.
- **No fake glass** by default — but `.background(.regularMaterial)` on ambient panels (End Workout summary sheet, Progress detail overlays) is welcome. This is what Weather does.
- **Adaptive:** light + dark both look intentional. Tinted cards use the same hue in dark mode at slightly higher opacity (~14% top-left, ~6% bottom-right) so they still register against near-black backgrounds.

## 3. Spacing

- **Scale:** 4, 8, 12, 16, 20, 24, 32, 40, 56. The larger values (32–56) are reserved for hero moments — a Progress card's internal vertical rhythm, or the space above/below an End-Workout PR display.
- **List rows:** system list insets, no override.
- **Card padding:** 20pt (up from Settings-style 16pt — cards feel like they *breathe*).
- **Hero-section vertical rhythm:** 40pt between the big number and its supporting label, 24pt between grouped stat rows.
- **Prefer `Spacer()`** in HStacks/VStacks over manual insets.

## 4. Corner radii

- **System components** (Button, Toggle, TextField): as-provided.
- **Cards:** `20pt` continuous curve. Rounded, generous, iOS-modern (matches Fitness workout cards).
- **PR badges and pill labels:** `.capsule`.
- **Chart containers on detail views:** `24pt` continuous curve with a subtle `.background(.regularMaterial)`.

## 5. Icons

- **SF Symbols exclusively** for V1.
- **Rendering mode:** `.hierarchical` is the default (adds depth, matches Fitness/Weather). `.palette` with two colors on hero symbols (e.g., the Workouts tab icon can use accent + secondary). `.multicolor` allowed on decorative marks that Apple has designed multicolor for (weather symbols style — not our main use case).
- **Weight:** `.regular` default; `.semibold` in small hit areas; `.bold` for hero symbols.
- **Preferred SF Symbols reference:**
  - Workouts tab: `dumbbell.fill` (palette: accent + secondary)
  - History tab: `clock.arrow.circlepath`
  - Progress tab: `chart.line.uptrend.xyaxis`
  - Settings: `gearshape`
  - Add: `plus.circle.fill` (hierarchical)
  - Start workout: `play.fill`
  - End workout: `checkmark.circle.fill` (softer than "stop")
  - Star (key lift): `star.fill` in an accent-tinted rendering when active; `star` outline when not
  - Delete: `trash`
  - Edit: `pencil`
  - RIR / effort: `gauge.medium`
  - PR badge: `trophy.fill`

## 6. Components

System-first, but tuned for richness.

- **Lists:**
  - Home template list: `List` `.plain` — but each row is a **custom card view** (see §7) inside a `PlainListRowBackground` so it feels like Fitness workout tiles, not a table.
  - Settings, template editing: `Form` `.insetGrouped`.
  - History: `List` `.insetGrouped` with session rows as compact cards.
- **Navigation:** `NavigationStack`. Large titles on Home, History, Progress roots. Inline title on Active Workout so the current exercise gets the visual weight.
- **Tabs:** `TabView` at the root. Three tabs (Workouts / History / Progress) per D-019. Consider a `TabView` `.tabViewStyle(.sidebarAdaptable)` if it looks right on iPad later (defer).
- **Sheets:** `.sheet` with `.presentationDetents([.medium, .large])` where multi-height feels right (End Workout summary uses this — glances at PR count on medium, expands to full detail on large).
- **Active Workout presentation:** `.fullScreenCover` with a custom `.background(LinearGradient(...))` using the current exercise's muscle-group tint at ~5% opacity, so the whole screen breathes the exercise's color. Subtle. Not loud.
- **Buttons:**
  - Primary CTA (Start Workout, End Workout, Create Template): `.buttonStyle(.borderedProminent)` + `.controlSize(.large)` + `.tint(.accentColor)`.
  - Secondary: `.bordered`.
  - Row-level: `.plain`.
  - Destructive: `role: .destructive`.
- **Toggles, Steppers, TextFields:** system, unmodified.
- **Text input in the Active Workout row** (weight, reps): inline `TextField`. Weight uses `.keyboardType(.decimalPad)`, reps `.numberPad`.

## 7. Cards — the primary visual unit

Cards are how content lives. They should feel like **Fitness workout tiles** — rich, tinted, confident.

Anatomy of a Progress card:
- 20pt padding.
- 20pt continuous corner radius.
- Background: `LinearGradient` from muscle-group tint (top-left ~10% opacity) to `.secondarySystemGroupedBackground` (bottom-right).
- Optional subtle shadow: `.shadow(color: .black.opacity(0.04), radius: 6, y: 2)`. Small, honest, present in Fitness.
- Content:
  - **Header row:** small SF Symbol (`.hierarchical`, muscle-group-tinted) + exercise name in `.headline`.
  - **Hero number:** current PR — `44pt bold rounded monospaced-digit` weight, `.title3.rounded` reps beside it. This is the visual anchor.
  - **Trend line:** 12-week Charts `LineMark` in accent color with `.interpolationMethod(.catmullRom)` for smoothness, plus a very subtle `AreaMark` fill (accent at ~10% opacity fading to clear).
  - **Footer:** "3 days ago: 105 kg × 5, 5, 4" in `.footnote` `.secondary`.

Anatomy of a Home template card:
- 20pt padding, 20pt corner radius.
- Background: a very subtle gradient using accent color at 4% → surface. Templates look like they belong to a family without being loud.
- Header: template name in `.title3` `.rounded` `.semibold`.
- Body: 3–4 exercise names in `.subheadline` `.secondary`, then "+N more" if longer.
- Trailing: `.play.fill` in accent color, sized 22pt.

## 8. Empty, error, and loading states

- **Empty states:** `ContentUnavailableView`, but the *symbol* leans on the Fitness aesthetic (large, `.hierarchical`, accent-tinted).
  - Home: `"No templates yet"` · `dumbbell` symbol · `"Templates are your saved workouts. Create one to start logging."` · primary CTA `"Create Template"`.
  - History: `"No workouts yet"` · `clock.arrow.circlepath` · `"Completed workouts appear here."`
  - Progress: `"No key lifts starred"` · `star` · `"Star an exercise to see progress here."`
- **Errors:** `.alert(...)`. Never a red banner or toast. Sync failures do not surface (offline-first).
- **Loading:** `ProgressView()`. Loading is rare. When it does show (first-run CloudKit fetch), it's inline and brief, not fullscreen.

## 9. Confirmation patterns

- **Destructive:** `.confirmationDialog(...)`. Destructive-role action + Cancel. Never both accent-tinted.
- **Destructive actions:** delete session, delete template, discard in-progress workout.
- **Non-destructive actions don't confirm.** Marking a set complete, ending a workout, starring an exercise are fast.

## 10. Haptics

Haptics are the app's second sense of touch. They're punctuation, not decoration — but when a set completes with a crisp `.rigid` tap under your thumb, the app feels *alive*, not like a form you're filling out. This is where much of the "pretty and polished" perception comes from on iPhone; it's why Fitness's ring-close feels so satisfying.

### 10.1 Principles

- **Haptics respond to meaningful commits**, not to navigation or exploration.
- **Frequent actions get softer haptics; rare actions get stronger ones.** A set completes 15+ times per workout; End Workout happens once. If both used the same intensity, one of them would feel wrong.
- **Never haptic without a matching visual change.** A haptic without a state change on-screen is confusing.
- **Respect the user's global haptic setting.** iOS exposes this via `UIDevice.current.playInputClick()` semantics and the "System Haptics" toggle in Settings → Sounds & Haptics. If disabled, we produce nothing — every call to the Haptics service becomes a no-op.
- **Reduce Motion doesn't affect haptics.** They're separate accessibility axes. Some users need reduced motion but want haptics loud.

### 10.2 Full event inventory

Frequent, per-set / per-set-like actions — use the softest haptics so they don't fatigue:

| Event | Haptic | Why |
|---|---|---|
| Set marked complete | `UIImpactFeedbackGenerator(.rigid)` | The core moment. `.rigid` feels precise and crisp — like flipping a well-built switch. Not `.light` (too subtle for the primary interaction) and not `.medium` (too heavy at 15–30 per workout). |
| Set skipped (swipe) | `UIImpactFeedbackGenerator(.soft)` | Softer, differentiated from complete. Confirms the swipe registered. |
| Set added (via + button) | `UIImpactFeedbackGenerator(.light)` | Subtle — you're adding structure, not committing effort. |
| Set edited (weight/reps typed) | none | Redundant with keyboard haptics. Would fatigue. |
| Star / unstar exercise as key | `UISelectionFeedbackGenerator().selectionChanged()` | Toggle-flavored, same feel as a picker. |

Rare, session-boundary actions — use stronger haptics to mark the moment:

| Event | Haptic | Why |
|---|---|---|
| Start Workout tapped | `UIImpactFeedbackGenerator(.medium)` | You're beginning. Meaningful, not routine. |
| End Workout tapped | `UIImpactFeedbackGenerator(.medium)` | Same weight as Start — bookends. |
| New PR detected on End Workout | `UINotificationFeedbackGenerator().notificationOccurred(.success)` | Once per PR. Informational, not celebratory. If multiple PRs in one session, still one haptic (the summary sheet handles the visual). |
| Resume Workout tapped on Home banner | `UIImpactFeedbackGenerator(.light)` | You're stepping back into an existing session — softer than starting new. |

Confirmation / destructive:

| Event | Haptic | Why |
|---|---|---|
| Destructive-confirmation dialog appears | `UINotificationFeedbackGenerator().notificationOccurred(.warning)` | Signals "pause and read this." |
| Confirmation confirmed (delete goes through) | none | The dialog already fired; another haptic would be noise. The list-row animation is the visual confirmation. |
| Destructive action canceled | none | No haptic on inaction. |

### 10.3 Explicitly no haptics

- Tab switching, sheet open/close, keyboard input, navigation push/pop.
- Text field focus.
- Scrolling (obviously).
- Successful iCloud sync (invisible to the user; haptics would be baffling).
- App launch, splash, transitions between rooms.

The rule of thumb: **if you'd expect Notes or Reminders to produce a haptic at this moment, we do too. If not, we don't.**

### 10.4 The `Haptics` service

Raw `UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator` calls do NOT appear in views. All haptic use goes through a single service:

```swift
enum Haptics {
    static func setCompleted()          // .rigid impact
    static func setSkipped()            // .soft impact
    static func setAdded()              // .light impact
    static func starToggled()           // selection changed
    static func workoutStarted()        // .medium impact
    static func workoutEnded()          // .medium impact
    static func personalRecordEarned()  // .success notification
    static func resumeTapped()          // .light impact
    static func warning()               // .warning notification
}
```

Rationale:
- **Named intent, not intensity.** Callers say `Haptics.setCompleted()`, not `Haptics.rigidImpact()`. If we later decide `.soft` feels better for that moment, one file changes.
- **Generator lifecycle.** Each function prepares and fires; no need for views to hold on to generators.
- **Testability.** In tests, we swap the service implementation for a no-op or a recording spy.
- **Single place to check user setting.** If we ever add an in-app "reduce haptics" toggle (parking-lot; probably unnecessary since iOS provides one), it lives in this file.

### 10.5 Custom Core Haptics — parking-lot

Fitness uses Core Haptics for ring-close moments — custom patterns like a heartbeat or a rising sparkle. We deliberately *don't* do this for V1:

- Custom patterns edge toward celebration, which D-024 forbids.
- Core Haptics is real code and real testing surface.
- The system generators cover 100% of our current events.

If a future version adds custom-pattern haptics (e.g., a very subtle "double-tap" feel on PR earned), it goes behind a decision entry and stays disciplined — no rising sparkles, no heartbeats, nothing that reads as gamification.

## 11. Motion

Fitness has real motion — rings animate on fill, cards spring in. Weather does its live wallpaper. Match that energy, honestly.

- **`.spring(response: 0.35, dampingFraction: 0.8)`** is the default interactive spring. Feels tactile, not bouncy.
- **Chart line fill-in on appear:** 500ms ease-out draw, gated on first render only.
- **Card entrance on Home:** subtle stagger (30ms per card) on first appearance.
- **Active-workout current-set emphasis change:** spring per above.
- **Respect `reduceMotion`:** every non-essential animation gates on `@Environment(\.accessibilityReduceMotion)`. When true, transitions are instantaneous — no motion at all.

## 12. Accessibility

Non-negotiable.

- **Dynamic Type end-to-end.** Test at `.accessibility5`. Hero numbers reflow / wrap rather than truncate.
- **VoiceOver labels** for every interactive element, composed from data. Set-row: `"Set 3, 100 kg, 5 reps, RIR 2, completed"`.
- **44 × 44 pt minimum hit target.** Where visual is smaller, `.contentShape(.rect)` extends the hit region.
- **Contrast:** tinted card backgrounds are opacity-blended over semantic surfaces so text remains readable at both modes. Verified with Accessibility Inspector.
- **Reduce Transparency, Reduce Motion, Increase Contrast, Bold Text:** honored via system components + explicit gates on our own animations and materials.

## 13. Layout

- **Compact-width primary target:** iPhone in portrait.
- **Regular width (iPad, landscape):** must not crash or look broken; not designed-for in V1. `NavigationSplitView` deferred.
- **Safe areas** respected. Hero backgrounds extend under the status bar (Fitness pattern) but content respects safe area.
- **Keyboard-avoiding:** `.safeAreaInset` or `ScrollView` — the Active Workout weight input must never sit under the keyboard.

## 14. Copy

- **Sentence case** in headings, buttons, and labels. Not Title Case.
- **No exclamation points.** No "Awesome!" language. Confident, calm.
- **Numbers:** `"5 reps"`, `"110 kg"` (thin space between value and unit).
- **Errors** name the failure and the recovery in one sentence.

## 15. Chart style

- **Framework:** SwiftUI `Charts`.
- **Line chart** for weight-over-time. Accent-color `LineMark` with `.catmullRom` interpolation + subtle `AreaMark` gradient fill (accent 10% → clear).
- **Axis:** minimal but not stripped. 3–5 date labels on X, 4 value labels on Y. Default gridlines allowed.
- **Marks:** point marks visible on the detail chart, hidden on card thumbnails (visual noise at small size).
- **Animation:** fill-in on first appear (§11). No animation on subsequent updates.

## 16. What we explicitly reject

- Custom fonts, custom icons, custom nav bars.
- Bottom sheets that aren't system `.presentationDetents`.
- Toast notifications.
- Skeleton loaders.
- Overlay tooltips.
- Confetti, celebrations, animated PR badges (Constitution §4, D-024).
- Vibrant/neon marketing gradients (chart fills at 10% opacity ≠ neon).
- "Floating" tab bars or custom-shaped nav.
- Card stacks that mimic third-party fintech apps.
- Fake glass on surfaces that aren't ambient (chrome, chips, cards). `Material` on sheets is fine.

## 17. Design review checklist

Before any screen is called "done":

- [ ] Uses system components where possible; deviations documented.
- [ ] All colors are either semantic (`.primary`, `.secondary`, `Color(.systemBackground)`) or the accent, or a muscle-group tint from the palette.
- [ ] All text uses text styles or the explicit hero-number system (§1).
- [ ] Renders correctly at `.accessibility5` Dynamic Type.
- [ ] VoiceOver navigation is coherent and every interactive element is labeled.
- [ ] Minimum 44×44 pt hit targets.
- [ ] Reduce Motion honored (non-essential animation gated).
- [ ] Dark mode looks intentional (screenshot in both). Tinted cards still register.
- [ ] Keyboard doesn't hide any input on the smallest supported device.
- [ ] Copy is sentence case, factual, no exclamation points.
- [ ] Haptics fire only where §10 permits.

---

## Muscle-group tint palette

Reference values for card tints (§2, §7). Adjust once in an asset catalog.

| Muscle group | Light-mode hue (name) | Notes |
|---|---|---|
| chest | warm peach | soft, human |
| back | steel blue | cool, structural |
| lats | deep teal | distinct from back |
| shoulders | gold | warm, high |
| biceps | leaf green | vitality |
| triceps | forest green | pairs with biceps but darker |
| quads | violet | strong, low body |
| hamstrings | plum | pairs with quads |
| glutes | rose | warm, distinct |
| calves | sand / khaki | grounded |
| core | slate | neutral, center |
| forearms | copper | earthy |
| traps | bronze | warm structural |

Applied as `LinearGradient` at ~10% top-left → ~4% bottom-right over `secondarySystemGroupedBackground`. In dark mode, ~14% → ~6%. Final hex values live in `Assets.xcassets` under `MuscleTint/<group>`; picked collaboratively during the first visual pass.

---

## Open sub-decisions

- **Accent color final hex.** Proposed warm orange; deferred to the first visual pass. Alternatives: system blue, teal, muted red. One-line change via `AccentColor` asset.
- **Muscle-group tint final hexes.** Above palette is descriptive; concrete values chosen during first visual pass.
- **App icon.** Coming when we start visual work.
