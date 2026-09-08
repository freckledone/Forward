# Decision Log — Forward

Every important product, UX, or architectural decision goes here. Format:

> **ID · Title**
> **Decision:** what · **Why:** reason · **Alternatives:** what else considered · **Why not:** reasons they lost · **Date:** YYYY-MM-DD · **Impact:** downstream effect

If a decision changes, add a new entry with a new ID and mark the old one **Superseded by D-XXX**. Do not edit old decisions in place.

---

## Product & scope

### D-001 — Audience of 1 for V1
- **Decision:** V1 is designed for one specific user (the author). Feature debates are resolved by "does the author want this," not "does the market want this."
- **Why:** Prevents scope creep from hypothetical users; produces a more opinionated, coherent product.
- **Alternatives:** Design for experienced lifters broadly; general strength trainees; beginners.
- **Why not:** Each requires accommodating patterns the author may not share, generating scope pressure with no counter-signal.
- **Date:** 2026-09-06
- **Impact:** Every future scope debate defers to this. Onboarding, beginner features, and generalized exercise handling are not in V1.

### D-002 — Structured programs primary; freestyle secondary
- **Decision:** V1 optimizes for users following a saved template. Freestyle logging is supported but not the design center.
- **Why:** Matches the author's actual training (custom split, planned sessions).
- **Alternatives:** Freestyle-primary; both equally weighted.
- **Why not:** Author doesn't train freestyle; equal weighting forces compromises in Active Workout UX.
- **Date:** 2026-09-06
- **Impact:** Home is a template list; Active Workout is designed around a template being the entry point.

### D-003 — Progress = weight and reps on key lifts
- **Decision:** The app's definition of "progress" is whether the user is lifting more weight or more reps on exercises they've marked as key.
- **Why:** Explicit user preference over consistency/volume/broad-PR framings.
- **Alternatives:** Volume-oriented; consistency-oriented; broad PR celebration; algorithmic "what matters" surface.
- **Why not:** All three were explicitly rejected. The user wants an honest, specific metric.
- **Date:** 2026-09-06
- **Impact:** Progress screen centers key lifts. No volume dashboards, streaks, or per-accessory PR notifications in V1.

## Data model

### D-004 — Canonical kg storage; display-only conversion
- **Decision:** All weight values are stored in kilograms. Display converts to lb per user preference. Stored values are never mutated on unit switch.
- **Why:** Prevents precision drift from repeated conversions; matches HealthKit's internal model; simplest schema.
- **Alternatives:** Store value + original unit per set.
- **Why not:** Adds schema complexity without meaningful UX benefit when display rounding is done carefully.
- **Date:** 2026-09-06
- **Impact:** Every weight field in the data model is `weightKg: Double`. Display layer handles conversion + rounding. Exports encode kg.

### D-005 — Templates define structure only; weight comes from SuggestionEngine
- **Decision:** Templates hold exercises + set count + target reps. They do not hold prescribed weights. The SuggestionEngine produces suggested weights per set from history.
- **Why:** Templates stay clean; history is the source of truth; matches the user's mental model of "workouts that carry history."
- **Alternatives:** Template stores weight; blank field every time; smart auto-progression as the default engine.
- **Why not:** Template-stores-weight makes templates maintenance work; blank is unnecessary friction; auto-progression is prescriptive and often wrong.
- **Date:** 2026-09-06
- **Impact:** Template entity has no `weightKg` on exercises. SuggestionEngine is invoked when starting a session.

### D-006 — SuggestionEngine is a protocol
- **Decision:** Weight suggestions are produced by an object conforming to a `SuggestionEngine` protocol. V1 ships one implementation; UI depends only on the protocol.
- **Why:** User explicitly asked for pluggability — start simple, evolve independently.
- **Alternatives:** Hardcode logic in the view model.
- **Why not:** We know we'll have multiple implementations over time; abstraction cost is negligible.
- **Date:** 2026-09-06
- **Impact:** UI code never mentions concrete engine logic. Future algorithms swap without UI churn.

### D-007 — V1 engine = Simple-1 (last-session lookup)
- **Decision:** V1 SuggestionEngine pre-fills each set with what was done in the same slot of the last completed session of the same exercise. No auto-adjustment.
- **Why:** Zero risk of being wrong; respects user judgment; forces "bump weight" UI to be fast.
- **Alternatives:** Simple-2 (+2.5 kg on green light); Simple-3 (symmetric auto-adjust); ship multiple as toggle.
- **Why not:** Any auto-adjust puts the app in the coach's seat; toggle-based is extra UI without proven demand.
- **Date:** 2026-09-06
- **Impact:** Simple engine implementation. Bump-weight interaction must be fast in the Active Workout UI.

### D-008 — No warm-up concept in V1
- **Decision:** Every set is a "set." No `.warmup` vs `.working` type; no `isWarmup` flag.
- **Why:** User does not log warm-ups.
- **Alternatives:** First-class warm-up type with UI distinction.
- **Why not:** Adding a category the user doesn't use adds ceremony to every interaction.
- **Date:** 2026-09-06
- **Impact:** `Set` entity has no type discriminator. Warm-up type is a non-breaking future migration if needed.

### D-009 — No advanced set types in V1
- **Decision:** No AMRAP, drop sets, supersets, cluster sets, rest-pause, or myo-reps in V1.
- **Why:** User does not use them.
- **Alternatives:** Add AMRAP flag; model drop sets as multi-weight sets; add ExerciseGroup concept for supersets.
- **Why not:** Building for hypothetical use adds real complexity to Active Workout and data model.
- **Date:** 2026-09-06
- **Impact:** `Set` entity remains minimal. Adding any of these later is a non-breaking migration except supersets (requires new ExerciseGroup relationship).

### D-010 — V1 loading modes: .weighted and .bodyweight only
- **Decision:** Exercises are one of two loading modes: `.weighted` (weight + reps) or `.bodyweight` (reps + optional added weight). Bodyweight-assisted and timed are parking-lot.
- **Why:** User does weighted and bodyweight training; does not regularly do assisted or timed work.
- **Alternatives:** Include timed, distance, bodyweight-assisted from V1.
- **Why not:** Each new loading mode requires a distinct input row and PR logic.
- **Date:** 2026-09-06
- **Impact:** Exercise entity has `loadingMode: LoadingMode` (enum with two initial cases). On `.bodyweight`, `Set.weightKg` means *added* weight, not total.

### D-011 — No user-created custom exercises in V1
- **Decision:** V1 ships with a curated exercise database (bundled JSON). Users cannot create custom exercises through the UI.
- **Why:** Explicit user preference; keeps DB quality controlled; simplifies CloudKit sync.
- **Alternatives:** Full custom creation; limited creation; custom exercises stored separately.
- **Why not:** All add UI surface the user has said isn't needed in V1.
- **Date:** 2026-09-06
- **Impact:** No exercise-creation form in V1. Missing exercises require a PR against seed data. **See RISK-001.**

## UX & interaction

### D-012 — Active Workout uses Model C (hybrid grid)
- **Decision:** All sets for the current exercise are visible as rows. The current set is visually emphasized and ready to receive input. Any past set is one tap to edit.
- **Why:** Best balance of overview and focus; Apple-native pattern.
- **Alternatives:** Model A (guided/focused, one set at a time); Model B (spreadsheet grid, no emphasis).
- **Why not:** A punishes edits and hides context; B feels less calm and less iOS-native.
- **Date:** 2026-09-06
- **Impact:** Active Workout renders the whole exercise; input focus follows the current set.

### D-013 — RPE captured on a 1–10 scale · **Superseded by D-038 (2026-09-06)**
The original text is preserved below for audit. See D-038 for the current decision.

Original: 
- **Decision:** RPE input uses the classic 1–10 scale, per set. RPE is a first-class field alongside weight and reps.
- **Why:** Matches author's mental model; industry standard for strength training.
- **Alternatives:** RIR (reps-in-reserve); user-selectable; skip RPE.
- **Why not:** Second scale doubles UI work; skipping loses a data point the author values.
- **Date:** 2026-09-06
- **Impact:** `Set.rpe: Int?` (optional, 1–10). Future engines may use RPE as an input.

### D-014 — No rest timer in V1
- **Decision:** V1 does not include a rest timer.
- **Why:** User explicitly rejected it; not part of the logging workflow.
- **Alternatives:** Auto-start on set complete; manual-start; toggleable.
- **Why not:** Any timer adds ambient UI to the Active Workout screen the user hasn't asked for.
- **Date:** 2026-09-06
- **Impact:** No timer chrome on Active Workout. Rest timer is in the parking lot.

### D-015 — Deviations from templates are silent
- **Decision:** Skipping, adding, reordering, or swapping sets/exercises during a session does not modify the template. Session records reality; template stays as-is.
- **Why:** Prompt fatigue kills prompts; templates should change only when explicitly edited.
- **Alternatives:** Prompt to update template on deviation; auto-update template.
- **Why not:** Both invite drift or dialog fatigue.
- **Date:** 2026-09-06
- **Impact:** Sessions and templates are independent entities. No "update template?" prompt anywhere.

### D-016 — End Workout → save + brief summary
- **Decision:** Tapping End Workout saves the session and shows a summary (total sets, duration, new PRs, optional note field). Done dismisses to Home.
- **Why:** Natural checkpoint without gamification.
- **Alternatives:** Silent save + dismiss; mandatory note; summary + system notification.
- **Why not:** Silent loses PR surfacing; mandatory adds friction; notification adds noise.
- **Date:** 2026-09-06
- **Impact:** Summary screen is a modal shown after End Workout.

### D-017 — First launch: empty Home + CTA
- **Decision:** First launch shows an empty Home with a single "Create your first template" CTA. No welcome tour, no sample data, no multi-screen intro.
- **Why:** Audience of 1 does not require coaching.
- **Alternatives:** Canned sample template; multi-screen intro; fake historical sample data.
- **Why not:** All add friction or clutter for a user who knows what they want.
- **Date:** 2026-09-06
- **Impact:** No onboarding views. Empty-state design must be well-crafted.

### D-018 — Home = template list + Recent section; no smart prediction
- **Decision:** Home shows the user's templates in user-defined order. An optional "Recent" section shows the most recent completed sessions for one-tap repeat. No day-of-week or cycle prediction.
- **Why:** The author's training pattern has flex; prediction would be wrong often enough to be net-negative.
- **Alternatives:** "Today: Push Day" schedule banner; rotating-cycle predictor.
- **Why not:** Both require the app to guess; wrong guesses are worse than no guess.
- **Date:** 2026-09-06
- **Impact:** No scheduling entity in the data model. Home is a list view.

### D-019 (tentative) — Tab bar: Workouts / History / Progress
- **Decision (tentative):** Three-tab navigation. Settings via a gear icon in the Workouts tab header.
- **Why:** Small, native pattern. Fewer than 5 tabs.
- **Alternatives:** Four tabs including Settings; drawer navigation.
- **Why not:** Drawer is non-Apple-native; 4th tab for Settings wastes real estate.
- **Date:** 2026-09-06
- **Impact:** Root view uses `TabView`. Marked tentative pending review during Design System stage.

## Progress

### D-020 — Key lifts flagged by user star
- **Decision:** Any exercise can be starred as a "key lift" from its detail view. Starred exercises populate the Progress dashboard.
- **Why:** User-controlled and reversible in one tap. Auto-detection is wrong precisely during program transitions.
- **Alternatives:** Auto-detect from frequency; configure in Settings; no distinction (show all).
- **Why not:** Auto is unreliable; Settings is more steps; no-distinction drops the concept.
- **Date:** 2026-09-06
- **Impact:** Exercises carry a per-user `isKey` flag (persistence pattern for user-flags-on-bundled-exercises to be resolved in Technical Architecture stage).

### D-021 — Progress opens to dashboard of key-lift cards
- **Decision:** Progress tab opens to a dashboard of cards, one per key lift. "See all exercises" link at the bottom for non-key.
- **Why:** Matches user's stated priority; key lifts get the real estate.
- **Alternatives:** List of all exercises; single "headline" lift screen; chart-first with selector.
- **Why not:** All either dilute the key-lift concept or over-focus on one lift.
- **Date:** 2026-09-06
- **Impact:** Progress tab is a scrollable grid/list of cards.

### D-022 — Progress card content
- **Decision:** Each card shows exercise name, current PR (weight × reps), 12-week top-set trend line, and last-session summary. Detail view adds full-history chart with adjustable time range, rep-max grid (1/3/5/8/10 rep PRs), and session list.
- **Why:** Every element earns its space against the "log or see progress" test.
- **Alternatives:** Estimated 1RM as headline; volume as headline.
- **Why not:** 1RM formulas disagree; volume isn't the user's stated metric.
- **Date:** 2026-09-06
- **Impact:** Progress card + detail views defined. Estimated 1RM available as derived metric in detail, not as headline.

### D-023 — PR definition = best weight for a given rep count
- **Decision:** A "PR" is the heaviest weight ever lifted for a specific rep count. Rep-max grid shows PRs for 1, 3, 5, 8, and 10 reps.
- **Why:** Honest, unambiguous, matches how strength trainees think about progress.
- **Alternatives:** Estimated 1RM as canonical PR; volume-based PR; single "PR" per exercise.
- **Why not:** Estimates are model-dependent; volume mixes weight and reps; single-value loses information.
- **Date:** 2026-09-06
- **Impact:** PR detection compares each new set against the historical maximum for its rep count.

## Anti-product

### D-024 — No gamification, ever
- **Decision:** No streaks, no consistency scores, no badges, no confetti, no artificial achievements. Not V2 material — anti-product.
- **Why:** Violates Constitution §3 (Progress-focused) and §4 (Anti-product).
- **Alternatives:** Ship as V2; ship as optional Settings toggle.
- **Why not:** Once shipped they anchor. Toggle isn't neutral — the fact that it exists implies we thought it was a good idea.
- **Date:** 2026-09-06
- **Impact:** No PR notifications, no achievement views, no streak counters, no confetti animations will be built.

### D-025 — No per-accessory PR notifications
- **Decision:** PRs on non-key exercises do not surface as notifications or dashboard entries.
- **Why:** The purpose of "key lifts" is that non-key noise is filtered. Notifying on every accessory PR undoes the concept.
- **Alternatives:** Notify on any PR; notify on key PRs only.
- **Why not:** Any-PR is noise; key-only isn't V1 (notifications are broadly restricted).
- **Date:** 2026-09-06
- **Impact:** No PR-notification code path in V1.

### D-030 — Sync: SwiftData + CloudKit
- **Decision:** Local persistence and iCloud sync use SwiftData with CloudKit sync enabled. Private database only. Container: `iCloud.<bundle-id>` (to be set on entitlements when we start coding).
- **Why:** Apple-native modern stack, matches Constitution §3 (Apple-first). Built on the mature `NSPersistentCloudKitContainer` engine under the hood. Best Swift ergonomics.
- **Alternatives:** Core Data + CloudKit; raw CloudKit; hybrid local-SwiftData + manual CloudKit.
- **Why not:** Core Data adds boilerplate for no runtime benefit; raw CloudKit reimplements what the stack already gives us; hybrid is worst of both.
- **Date:** 2026-09-06
- **Impact:** Every SwiftData `@Model` must comply with CloudKit constraints (all properties optional or defaulted, no unique constraints, explicit inverse relationships). Sync is best-effort and asynchronous. Local is always source of truth. Closes Q-004.

### D-031 — ExerciseUserFlag overlay pattern for bundled exercises
- **Decision:** The bundled exercise DB is a read-only in-memory value-type collection loaded from JSON. It is NOT imported into SwiftData. Per-user data (currently `isKey`) lives on a separate SwiftData `ExerciseUserFlag` model keyed by `exerciseId: String`, synced via CloudKit.
- **Why:** Clean separation of read-only content vs. user data. Zero merge logic when the bundled DB is updated with a new app version. Sync surface stays small (only user-produced records). Custom exercises (parking-lot from D-011) fit as a third data source without redesign.
- **Alternatives:** Import bundled JSON into SwiftData on first launch (Option A).
- **Why not:** Option A requires custom merge logic on every app update (added/renamed/removed exercises) and bloats sync with content that's already on-device.
- **Date:** 2026-09-06
- **Impact:** Filtering exercises by metadata happens in Swift after loading records; SwiftData `#Predicate` cannot reach into `Exercise` metadata. Rendering an exercise = lookup bundled Exercise + lookup ExerciseUserFlag. Closes Q-010.

### D-032 — TemplateExercise uses a single `targetReps: Int` in V1 · **Superseded by D-039 (2026-09-06)**
The original text is preserved below for audit. See D-039 for the current decision.

Original: 
- **Decision:** Each `TemplateExercise` has `targetSets: Int` and `targetReps: Int`. All sets of the exercise target the same rep count. Pyramid/varying-rep schemes are not supported in V1.
- **Why:** Matches the author's training. Simpler data model and template-editing UI.
- **Alternatives:** `targetSetSpecs: [SetSpec]` from day one.
- **Why not:** More UI complexity for a scheme the user doesn't use. Future migration is non-breaking (existing templates expand to N identical `SetSpec` entries).
- **Date:** 2026-09-06
- **Impact:** Template creation/edit UI shows one reps field per exercise, not one per set.

### D-033 — Data model V1 (see 05 — Technical Architecture)
- **Decision:** The V1 data model consists of: `Template`, `TemplateExercise`, `Session`, `SessionExercise`, `WorkSet`, `ExerciseUserFlag`, `UserPreferences` (SwiftData / CloudKit-synced), and `Exercise` (in-memory value type from bundled JSON). Full entity definitions, relationships, and design rules in `docs/05-technical-architecture.md`.
- **Why:** Represents everything V1 needs, respects all CloudKit constraints, keeps sync surface minimal.
- **Alternatives:** Various single-entity variants (e.g., no snapshot fields; merged Template+Session), each rejected during design.
- **Why not:** Snapshots are cheap and prevent historical rewriting; separate Session/Template preserves history across template deletion.
- **Date:** 2026-09-06
- **Impact:** All future implementation work references this model. Changes require a new decision entry. Closes Q-007.

### D-035 — Exercise DB provenance: Free Exercise DB (Unlicense) → transformed & filtered
- **Decision:** Seed the bundled exercise database from the Free Exercise DB (github.com/yuhonas/free-exercise-db) as source data. That project is released under **The Unlicense** (public-domain dedication) — verified via GitHub API 2026-09-06 — permitting unrestricted use, modification, and bundling. A transformation script filters their 876 exercises to the strength / powerlifting / olympic-weightlifting / strongman categories, maps their fields to Forward's schema, applies the taxonomy collapse rules (D-036), and produces `Forward/Resources/exercises.json`. Bundled images from the source are NOT used in V1 (D-011 context; exercise media is parking-lot).
- **Why:** The Unlicense is the most permissive license possible; no risk of contamination for any OSS license we later choose (Q-009). Their taxonomy is close enough to ours that mechanical transformation works. Their coverage (876 entries) gives us plenty of material to filter down to the user's actual program.
- **Alternatives:** Manually curate seed from scratch; import from wger (GPL); import from proprietary sources.
- **Why not:** Manual is slower for zero material gain; wger contaminates the license; proprietary sources are legally risky.
- **Date:** 2026-09-06
- **Impact:** A `scripts/transform-exercises.py` (or equivalent) is the reproducible pipeline from source to bundled JSON. Attribution to Free Exercise DB in the docs/README (courtesy, not requirement). Closes Q-005.

### D-047 — Program-as-grouping added; rename Template → Workout · Refines D-041
- **Decision:** Add a `Program` entity above `Workout` (renamed from `Template`). Program is a lightweight grouping only — it holds a name and a set of Workouts. **Periodization scaffolding (cycles, blocks, deloads, wave loading) is still explicitly OUT per D-041**; this refinement is naming + grouping only. Data model: `Program → Workout → WorkoutExercise`. Home renders one `Section` per Program, with that program's Workouts inline as cards. Start-workout path stays one tap (no drill-in). `Session` gains `workoutId` + `workoutNameSnapshot` (replacing `templateId` / `templateNameSnapshot`) and `programId` + `programNameSnapshot` for history context.
- **Why:** User's mental model is programs → workouts → exercises, and "Template" is engineer-speak that doesn't match training vocabulary. Adding grouping now (before any user data exists) is a no-cost migration; adding it later is real work. Multi-program support falls out for free.
- **Alternatives:** (A) rename only, no Program layer; (C) full Program screens with drill-in nav.
- **Why not:** (A) leaves multi-program grouping to naming conventions; (C) adds a tap on the workout-start path, violating Constitution §1's "disappear while you work out."
- **Date:** 2026-09-07
- **Impact:** Rename cascade across Models/, Services/, Views/. New `Program.swift` model. `SchemaV1` gains `Program.self`. Home restructures from flat list → sectioned list. New workouts auto-assign to a default program (created lazily as "My Program" on first workout). D-041's periodization restriction stands.

### D-046 — Equipment taxonomy amended: split `machine` into `machine` + `plateLoadedMachine` · Supersedes D-036
- **Decision:** Equipment enum grows from 8 → 9 values. `machine` continues to mean selectorized / pin-loaded / stack-loaded machines (leg extension, leg curl, pec deck, selectorized cable rigs). New value `plateLoadedMachine` covers plate-loaded strength machines (Hammer Strength-style presses, plate-loaded hip thrust, plate-loaded leg press, plate-loaded calf raise). All other values (barbell, dumbbell, cable, bodyweight, kettlebell, band, ezBar) unchanged. MuscleGroup and MovementPattern enums unchanged.
- **Why:** The author's training uses plate-loaded machines named as such (plate-loaded hip thrust, 45° leg press, seated plate-loaded calf raise). The plate-loaded vs. selectorized distinction matters: plate math is different, feel is different, and search filtering benefits from the distinction. Collapsing to just "machine" hides useful information.
- **Alternatives:** (A) Full replacement with 3-value taxonomy (plateLoaded/machineLoaded/bodyweight); (C) two-dimensional Equipment + orthogonal LoadingType.
- **Why not:** (A) drops barbell/dumbbell/cable distinctions that are useful for filter and browse; (C) doubles enum surface for one exercise category's benefit.
- **Date:** 2026-09-07
- **Impact:** Equipment enum in `Forward/Models/Enums.swift` has 9 cases. `scripts/coverage-pass.py` `EQUIPMENT_FIXES` updated to override three exercises (`barbell-hip-thrust`, `leg-press`, `seated-calf-raise`) to include `plateLoadedMachine`. `Forward/Resources/exercises.json` regenerated. `docs/06-exercise-database-specification.md` §2.2 updated. Source `transform-exercises.py` unchanged (Free Exercise DB doesn't distinguish; defaults source `machine` → our `machine`).

### D-045 — Open-source license: MIT
- **Decision:** Forward is released under the MIT License. `LICENSE` file at repo root; copyright holder "Yuri Gurgenidze"; year 2026.
- **Why:** Maximum permissiveness. Anyone can use, modify, redistribute (including commercially) as long as the copyright notice is preserved. Doesn't force downstream licensing choices. Compatible with the Unlicense source of the bundled exercise data (D-035). Simplest possible license to explain.
- **Alternatives:** Apache-2.0 (adds explicit patent grant, more verbose), GPL (copyleft — forces derivatives to be GPL), keep private (no OSS release).
- **Why not:** Apache-2.0's patent grant is nice-to-have but not needed for a personal-use app with no proprietary tech; GPL contaminates any downstream user; private forfeits the open-source stance from the brief.
- **Date:** 2026-09-07
- **Impact:** `LICENSE` file created. README (whenever it exists) should mention MIT. Third-party contributions, if we ever accept any, license their contribution under MIT by default. Closes Q-009.

### D-044 — Product name: Forward
- **Decision:** The product ships as **Forward**. The name is the working name promoted to final. No trademark search / App Store availability check performed yet — deferred until submission because the app may never be submitted (personal use is fine indefinitely).
- **Why:** User is satisfied with the name; the Xcode scaffold, folder, and all docs already use it; delaying further has no upside.
- **Alternatives:** Rename to something from the brief's conceptual territory (Momentum, Ascent, Rep, Practice, etc.); leave as "working name" indefinitely.
- **Why not:** Renaming late is a real cost (Xcode target, bundle ID, CloudKit container, entitlements); leaving as "working" carries the option cost of never committing.
- **Date:** 2026-09-07
- **Impact:** All references to Forward are now canonical. Pre-App-Store checklist adds: trademark search + App Store name availability check. If either fails at submission time, we revisit with the option value of already having built the product. Closes Q-001.

### D-043 — *(accent colour superseded by D-065, 2026-09-07)*
### D-043 — Design System: "Apple language, spoken confidently" (Fitness/Weather reference, not Settings)
- **Decision:** Forward's visual language uses Apple's system components, Dynamic Type, semantic colors, SF Symbols, and standard interaction patterns — but with the visual richness of Fitness / Weather, NOT the utilitarianism of Settings / Notes / Reminders. This means: purposeful gradients (subtle, meaningful), hero rounded-numeric displays for headline stats, muscle-group-tinted card backgrounds, subtle shadows, richer motion, and generous use of `Material` on ambient surfaces. Full spec in `docs/04-design-system.md`.
- **Why:** User pushed back on 2026-09-07 that the initial design-system draft leaned too utilitarian ("just because it's Apple-first doesn't mean it should look like Settings"). Fitness and Weather demonstrate that Apple-native ≠ plain; both use gradients, hero numbers, and tinted surfaces while remaining unmistakably iOS.
- **Alternatives:** Strict Settings/Notes-like utilitarianism (initial draft, superseded); startup-SaaS aesthetics; heavy custom UI.
- **Why not:** Utilitarian is boring for a personal-use daily app; SaaS aesthetics violate Constitution §4; heavy custom UI violates Apple-first.
- **Date:** 2026-09-07
- **Impact:** Progress cards are the flagship visual moment (tinted by muscle group, hero PR number, chart with area-fill gradient). Home template cards are Fitness-tile-inspired. Motion is real (springs, chart draw-in). Muscle-tint palette added to spec for `Assets.xcassets`. Closes Q-008.

### D-042 — Seed templates are reference-only; not bundled; not auto-imported
- **Decision:** `docs/seed-templates-reference.json` documents the author's intended initial templates (Workout A/B/C) but is NOT bundled in the app, and is not published with the repository. First-launch behavior remains per D-017: empty Home + "Create your first template" CTA. The user recreates the 3 templates manually the first time.
- **Why:** Respects D-017 fully (no first-launch special-casing). Keeps the app code path uniform for any distribution. Reference file preserves the intended shape for validation and future re-recreation.
- **Alternatives:** Auto-import on first launch if bundled (Option A); Settings action to import (Option B).
- **Why not:** Auto-import amends D-017; Settings action adds a UI surface with a one-time use case.
- **Date:** 2026-09-06
- **Impact:** No bundle-loading code for templates. Manual template creation is the only path. Reference file is documentation, not runtime data.

### D-041 — Reconfirm D-018: no cycle/block/deload modeling in V1
- **Decision:** The cycle/block/deload structure of the author's previous training app is intentionally NOT represented in the V1 data model. Workout A / B / C / … become independent flat `Template` records. No `Program`, `Cycle`, `Block`, or `Deload` entities.
- **Why:** D-018 (Home = flat template list, no smart prediction) and the user's stated "flex" preference. Adding periodization scaffolding contradicts Constitution simplicity and is not needed to reproduce his actual workouts.
- **Alternatives:** Full periodization modeling (Program → Cycle → Block → Workout).
- **Why not:** Real scope expansion (2–3 more decision cycles at minimum); user can start any template at any time without app help.
- **Date:** 2026-09-06
- **Impact:** Templates seeded from the prior program are flat. No cycle tracking. The imported program name becomes conceptual context only — could optionally become a Template group in the future (parking-lot).

### D-040 — Reconfirm D-010: timed exercises stay out of V1; Side Plank dropped from user's seed
- **Decision:** D-010 stands. Loading modes remain `.weighted` and `.bodyweight`. Side Plank (present in the author's prior program) is not included in V1's user-facing templates. When timed exercises are added (parking-lot), Side Plank comes back.
- **Why:** The author's use of timed exercises amounts to exactly one entry in their program. Adding an entire loading mode + input row + PR logic for one exercise fails cost/benefit.
- **Alternatives:** Add `.timed` loading mode; log Side Plank as reps-only (rules-lawyer).
- **Why not:** Reconfirmed by user after seeing the tradeoff.
- **Date:** 2026-09-06
- **Impact:** Side Plank is filtered out of the seed-template generation. User does Side Plank without logging in the app until timed support ships.

### D-039 — Rep targets are stored as `targetRepsMin` + `targetRepsMax` (Ints) · Supersedes D-032
- **Decision:** `TemplateExercise` uses two Int fields for rep targets: `targetRepsMin` and `targetRepsMax`. When they are equal (e.g., 5–5), the display collapses to a single number ("5"). When they differ, display shows the range ("6–8"). No pyramid support (per-set variation) in V1 — all sets of an exercise share the same range.
- **Why:** The author's training is programmed in rep ranges rather than single targets, confirmed against their existing program on 2026-09-06. Single Int (D-032) doesn't represent this.
- **Alternatives:** Single Int (D-032, superseded); string field ("6-8"); per-set specs.
- **Why not:** Single loses information; string is not queryable and blocks progress-tracking; per-set isn't needed (all sets share the range).
- **Date:** 2026-09-06
- **Impact:** `TemplateExercise` schema in 05-technical-architecture.md updated. Template editing UI needs a min + max input (or a single input when the user wants a fixed number, with an expand-to-range affordance). SuggestionEngine still uses last-session reps for pre-fill (no change).

### D-056 — Workout rows are sibling buttons, not NavigationLinks
- **Decision:** Home workout rows drop `NavigationLink` in favour of a `WorkoutCard` holding two sibling `Button`s — the summary block (`onOpen`, pushing the editor via the existing `navigationDestination(item: $editingWorkout)`) and the play button (`onStart`). The play button is vertically centered in the card and enlarged to a 54pt circle with a 26pt glyph.
- **Why:** A `NavigationLink` row makes `List` draw a disclosure chevron on every workout, which is visual noise on a card that already reads as tappable — and the chevron competed with the play button for the eye. Sibling buttons also remove the nested-button ambiguity of a `Button` living inside a link's label.
- **Alternatives:** Keep the link and hide the chevron with a zero-opacity overlay link; keep the link and shrink the play button; move the play button outside the card.
- **Why not:** The overlay-link trick is a hack that breaks accessibility traversal. Shrinking the play button targets the wrong problem — starting a workout is the card's primary action and should be the biggest thing on it. Moving the button outside the card loses the tinted-card composition from D-043.
- **Date:** 2026-09-07
- **Impact:** `WorkoutCard` gained an `onOpen` closure and split its text block into a `summary` property. The card's `.contentShape` is gone (each button now defines its own hit area; the summary button uses `.frame(maxWidth: .infinity)` + `.contentShape(Rectangle())` so the empty space left of the play button still opens the editor). `.onMove` reordering and `EditButton` behaviour are unchanged.

### D-057 — History declutters by subtraction, not reformatting
- **Decision:** History rows collapse from four lines to two: workout name + duration, with the date right-aligned. Session detail merges its header and stats sections into one hero block (date + program over two stat tiles: Duration / Started) on a clear list background; set rows lose their status-icon column and RIR capsule, and exercise section headers lose their set count.
- **Decision (amended 2026-09-07):** Exercise and set counts are cut from History entirely. Sessions are instantiated from saved workouts, so those counts are identical on every run of a given workout — they take up the row without ever distinguishing one session from another. Date and duration are the only per-session facts that vary, so they are the only ones shown. The program name is also dropped from the row (it remains in the detail hero).
- **Why:** Three stacked grey sublines at the same weight read as mush rather than hierarchy. In a *completed* session almost every set was logged, so a checkmark on every row is a column that marks the default case and says nothing; only the exceptions carry information. The same test kills the counts: a number that is the same on every session of a workout is chrome, not data. What varies across sessions is when you trained and how long it took.
- **Alternatives:** Keep every field and tighten spacing/typography; move the overflow data behind a disclosure; add total volume as a stat tile; keep counts as a completion signal ("18 of 24 sets").
- **Why not:** Tightening reformats clutter rather than removing it — the row was dense because it carried four facts of equal visual weight, not because of leading. A disclosure hides data behind a tap nobody will take. Volume is explicitly out of scope per D-003 ("no volume dashboards").
- **Date:** 2026-09-07
- **Impact:** Skipped and never-logged sets render as dimmed "Skipped" / "Not logged" text instead of printing their weight and reps, which were only ever a `SuggestionEngine` pre-fill and would misread as lifts. `SessionDetailView.completedSetsCount`/`totalSetsCount` and `SessionRow.summaryLine` are gone; `SessionDetailView` gained a `startTimeString`. This decision assumes D-002 (structured programs primary) holds — if freestyle logging ever becomes a real usage pattern, per-session counts start varying and are worth reconsidering.

### D-058 — History detail earns its space with progression data, not counts
- **Decision:** Session detail leads with a hero block — uppercase date, the session duration set as a 40pt rounded headline number, "Started HH:MM · Program" beneath it, and a trophy capsule when the session earned personal records (reusing `ProgressCalculator.prsAchieved`). Each exercise section gains a footer reading "Top set 100 kg × 8 · ↑ 2.5 kg", where the delta compares against the top set of the last session that trained that exercise (new `ProgressCalculator.previousTopSet`). History rows get a calendar-style date chip, accent-tinted for today.
- **Why:** D-057 removed the counts because they never varied, which left the screen honest but thin. The fix for thin is real data, not the counts back. A session-over-session delta is the most on-mission number the app can show: D-003 defines progress as lifting more weight or more reps, and this is literally that comparison. PRs were already computed for the End Workout summary and were simply absent from the permanent record of the same session.
- **Alternatives:** Total volume tile; a per-session muscle-coverage chart; leave the screen sparse; recompute the delta live in the view body rather than in a `.task`.
- **Why not:** Volume remains out per D-003. A coverage chart is decoration — it says what the workout was, which the title already does. Computing deltas in the body would refetch on every render; the `.task` caches raw kg/reps into state and lets the view format them, so a unit change doesn't force a recompute.
- **Date:** 2026-09-07
- **Impact:** Delta precedence is weight first, then reps at equal weight, then "Matched last time" — adding load is the stronger signal and reps is the tiebreak. An exercise with no prior session reads "First time" rather than showing a misleading zero. Improvements are accent-tinted; regressions are secondary grey, not red — a lighter day is a training decision, not an error. `SessionRow`'s "Today"/"Yesterday" labels are gone, replaced by the chip plus its accent state.

### D-059 — Workout cards summarize by muscle coverage, not truncated exercise names
- **Decision:** `WorkoutCard` drops the "first three exercise names, then +N more" preview. It now shows a counts line ("8 exercises · 24 sets") and up to three capsules naming the distinct primary muscles the workout covers, filled with that muscle's `MuscleTint` color at 22% and labelled in secondary text.
- **Why:** Three arbitrary exercise names described the workout less well than its muscle coverage did, and "+5 more" is a truncation artifact wearing the costume of information — it tells you only that the card ran out of room. Counts are legitimate here (unlike in History, D-057) because they genuinely differ between workouts.
- **Alternatives:** List every exercise (card grows unbounded); keep three names with no "+N" line; wrap all names into a two-line truncated run.
- **Why not:** An 8-exercise workout would make a very tall card in a list of several. Silently truncating to three is the same problem without the admission. A wrapped name run reads as a wall of small grey text at card scale.
- **Date:** 2026-09-07
- **Impact:** Chip labels use the *system* text style rather than the muscle color as foreground — these tints are pastel (gold on white is roughly 1.9:1) and would fail contrast. The color lives in the capsule fill. Coverage is capped at three with no overflow indicator; deduplicated primary muscles rarely exceed that. `WorkoutCard.previewLines` is replaced by `muscleCoverage` + `countsLine`.

### D-060 — JSON backup: export everything, import additively by UUID
- **Decision:** Settings gains a Data section with "Export Backup" (via `.fileExporter`) and "Import Backup" (via `.fileImporter`). `DataArchive` serializes every user-owned record — programs, workouts, workout exercises, sessions, session exercises, sets, exercise flags, preferences — as a single nested JSON document with a `formatVersion`. **Import is additive and keyed by UUID: a record whose id already exists is skipped, never overwritten.** There is no "replace all" option.
- **Why:** CloudKit activation migrates the local store, and there is real training data on the device with no way to get it off. An irreversible step needs a reversible escape hatch first. Additive-by-id makes the operation safe in every direction: restoring onto an empty store is a full restore, restoring onto a populated store fills gaps, and running the same file twice is a no-op. A backup tool that can destroy the thing it exists to protect is the wrong shape.
- **Alternatives:** Offer "replace all" alongside merge; last-write-wins by `updatedAt`; export to CSV; rely on Xcode container download for backups.
- **Why not:** "Replace all" is the one button whose misfire loses everything the feature exists to save. `updatedAt` merging silently overwrites local edits and needs conflict UI nobody wants to build. CSV can't carry the nested session→exercise→set graph without inventing a join convention. Xcode container download requires a Mac, a cable, and remembering to do it.
- **Date:** 2026-09-07
- **Impact:** The bundled exercise catalog is deliberately absent from the archive — it ships with the app and is read-only (D-031), and records reference exercises by stable slug, so archives survive catalog updates. `Workout.program` is optional for CloudKit (D-030), so orphaned workouts export under a separate `unassignedWorkouts` key rather than being silently dropped. Imported preferences apply **only** when the store has none, so merging into a configured app can't flip the unit setting. Dates are ISO-8601 and keys are sorted, so two exports of unchanged data are byte-identical and diffable. A file with a `formatVersion` above the reader's is refused rather than partially parsed. 13 tests cover round-trip fidelity, id preservation, idempotency, non-overwrite, orphan handling, and three classes of bad input.

### D-061 — CloudKit sync on, with a local fallback and an honest status row
- **Decision:** `ForwardApp` builds its `ModelContainer` with `cloudKitDatabase: .private(SyncStatus.containerIdentifier)`, matching the entitlement. If that container can't be opened the app falls back to a local-only store for that launch rather than crashing. A new `SyncStatus` observable reports state to a Settings row, combining three signals: whether the container is CloudKit-backed, the `CKAccountStatus`, and completed `NSPersistentCloudKitContainer` mirroring events.
- **Why:** Sync was the last piece of D-030 left unwired, and the paid membership is now in place. The fallback exists because an unprovisioned container or a revoked entitlement should cost sync, not the user's access to their own training history — `fatalError` on launch is the worst possible response to a cloud problem.
- **Alternatives:** `cloudKitDatabase: .automatic`; crash on container failure (the prior behavior); report status from `CKAccountStatus` alone; no status surface at all.
- **Why not:** `.automatic` silently picks the first entitlement container, so a config drift between entitlement and code would go unnoticed; naming it explicitly fails loudly instead. `CKAccountStatus` alone is not sufficient — see Impact.
- **Date:** 2026-09-07
- **Impact:** Verified on simulator: the container opens, CloudKit mirroring initializes, and the only error is `CKAccountStatusNoAccount` (simulator not signed in). Crucially **no schema-validation error**, which confirms the D-030 constraints (defaulted/optional attributes, optional relationships with explicit inverses, no unique attributes) actually hold — an invalid model throws synchronously at container init.
  - The log run also exposed a flaw in the first cut of this work: **`ModelContainer` init succeeds even when CloudKit cannot work at all.** Setup runs asynchronously afterwards, so the fallback path almost never fires for the case it was written for, and a status row built on container-creation success alone would have reported "On" while syncing nothing. `SyncStatus` therefore observes `NSPersistentCloudKitContainer.eventChangedNotification` and reports "Error" / "Starting…" / "On" from completed mirroring events. The fallback stays as a genuine net for synchronous model-incompatibility throws.
  - **Pre-ship requirement:** the CloudKit schema is pushed to the *Development* environment automatically on first Debug run. It must be promoted to *Production* in the CloudKit Dashboard before TestFlight or App Store release, or synced installs will fail against an empty production schema.

### D-062 — Sync toggle lives in UserDefaults and applies on next launch
- **Decision:** Settings gains an "iCloud Sync" toggle backed by `UserDefaults` (`SyncStatus.syncEnabledDefaultsKey`, defaulting to on). `ForwardApp` reads it once at launch to decide whether to build a CloudKit-backed or local-only container. Because a `ModelContainer`'s CloudKit backing is fixed at construction, the change takes effect on the **next launch**, and Settings says so explicitly whenever the toggle disagrees with what's actually running.
- **Why:** Sync should be the user's choice, not a build-time constant. The restart notice exists because the alternative — a switch that flips but changes nothing until an unannounced future launch — is a control that lies about the state of the system.
- **Alternatives:** Store the flag in `UserPreferences` (the SwiftData model); rebuild the `ModelContainer` live on toggle; force-quit the app on toggle; hide the toggle entirely.
- **Why not:** `UserPreferences` is the wrong home twice over — it lives in the store being synced, so a "sync off" flag there would propagate the shutoff to every other device (the opposite of a per-device setting), and it isn't readable before the container it configures exists. SwiftData offers no supported way to swap a live container's backing. Force-quitting an app programmatically is an App Store rejection and looks like a crash.
- **Date:** 2026-09-07
- **Impact:** Turning sync off is non-destructive in both directions: local data stays local, records already in iCloud stay in iCloud, and turning it back on resumes mirroring. No "delete my iCloud data" affordance is offered in V1 — that is a genuinely destructive action deserving its own design. `SyncStatus` distinguishes *user-disabled* ("Off") from *CloudKit unreachable* ("Unavailable"), since conflating them would hide a real failure behind an intentional setting. The restart notice is suppressed when `fallbackReason != nil`, so a failed connection reports itself as a failure rather than as a pending restart.

### D-063 — HealthKit implementation: write-only mirror via HKWorkoutBuilder
- **Decision:** Implements D-028. `HealthKitWorkoutWriter` writes each finished session as an `HKWorkout` of type `.traditionalStrengthTraining` using `HKWorkoutBuilder` (the `HKWorkout` initializers are deprecated as of iOS 17). Entitlement `com.apple.developer.healthkit` plus `NSHealthUpdateUsageDescription` only — no read scope is requested, because the app never reads. The write happens in `EndWorkoutSummary.task`, and deleting a session in History also deletes its mirrored `HKWorkout`.
- **Why:** Activity-ring credit and presence in Health/Fitness, at the cost D-028 budgeted. Doing the write in the summary sheet rather than `SessionLifecycle.end` keeps it to exactly one attempt, only for sessions the user actually finished, and only when opted in — a discarded session never reaches Health.
- **Alternatives:** Write in `SessionLifecycle.end`; request permission at first launch; expose `HKAuthorizationStatus` directly to the views; surface write failures as an alert on the summary screen.
- **Why not:** `SessionLifecycle.end` also runs on paths that shouldn't publish anything. First-launch permission prompts are the pattern D-028 explicitly rejected. Exposing `HKAuthorizationStatus` forced `import HealthKit` into `SettingsView` (it failed to compile that way first), so the writer publishes plain `isAuthorized` / `isDenied` / `isUndecided` Bools instead — the same boundary `SyncStatus` draws around CloudKit. Alerting on failure interrupts a summary screen with a problem the user cannot act on from there.
- **Date:** 2026-09-07
- **Impact:** Verified by device-signed build: `com.apple.developer.healthkit` is present in the signed entitlements and granted by the provisioning profile, so automatic signing registered the capability with no manual portal step.
  - **Permission is requested in two places, deliberately.** `UserPreferences.healthKitEnabled` lives in the CloudKit-synced store, so the *preference* propagates across devices — but HealthKit authorization is per-device and does not. Turning the Settings toggle on asks immediately (that's when the user expressed intent); `EndWorkoutSummary` also asks when the preference arrived over iCloud on a device that was never prompted, which is D-028's "ask at first End Workout" case.
  - Failures are silent by design: the session is already saved in SwiftData before the mirror runs, and `healthKitWorkoutUUID` remaining nil is the record that it didn't happen. Health is a mirror, never the source of truth.
  - No unit tests: `HKHealthStore` needs a real Health database and a permission grant, so any test would assert against a stub rather than the integration. Verification is the signed-entitlement check above plus on-device use.

### D-064 — Build identity lives in a git-ignored xcconfig, not in the project file
- **Decision:** `DEVELOPMENT_TEAM`, `PRODUCT_BUNDLE_IDENTIFIER`, and the CloudKit container identifier are removed from `project.pbxproj`, the entitlements file, and Swift source. They now resolve from three variables in `Config/Forward.xcconfig`, which ships placeholder values and optionally includes a git-ignored `Config/Local.xcconfig` holding the real ones. `SyncStatus.containerIdentifier` reads the value from Info.plist instead of hardcoding it. Repo also gains a README and a NOTICE.
- **Why:** Preparing the project to be open-sourced. The identifiers aren't secrets — team IDs appear in every signed app — but they're personal, and a clone shouldn't carry them. This also fixes a real fork problem: previously a cloner hit signing and CloudKit errors with no explanation, and the container id was duplicated across three files that could silently drift.
- **Alternatives:** Leave the identifiers in and document them in the README; blank them in `pbxproj` and have each developer re-enter them in Xcode; `git update-index --skip-worktree` on the project file.
- **Why not:** Documenting doesn't remove them. Re-entering in Xcode writes straight back into the tracked `pbxproj`, so the next commit re-adds them — the exact loop xcconfig exists to break. `skip-worktree` is a local flag that silently breaks for anyone who doesn't know it's set.
- **Date:** 2026-09-07
- **Impact:** Verified in both directions: a clean checkout builds for the Simulator on placeholders, and a device-signed build resolves the real bundle id and container from `Local.xcconfig` into `Info.plist` and the signed entitlements.
  - Two mistakes worth recording, both caught by building rather than reading. **`$(VAR)` must be quoted in `pbxproj`** — the old-style plist parser treats bare `$` and parentheses as a syntax error, and Xcode then reports only "Unable to read project", which points nowhere near the cause. **An `#include?` must come *after* the defaults it overrides**, since the last assignment wins in an xcconfig; placed first, the placeholders silently overwrote the local values and signing failed with "requires a development team" despite the team being set.
  - The xcconfig is attached to the two **project-level** build configurations, not the app target's, so the test targets inherit the same variables. Their bundle ids derive as `$(FORWARD_BUNDLE_ID)Tests` / `UITests`.
  - `docs/` stays in the repository. It contains design documents, not development-session transcripts; the decision log is the most useful artifact here for anyone trying to understand the codebase.

### D-065 — Accent colour is sampled from the app icon · Supersedes the accent clause of D-043
- **Decision:** The accent is a steel blue taken from the app icon: `#2B6CA8` in light, `#82B6E4` in dark. `Brand` exposes the icon's full sampled palette — background ramp `#1B1F23 → #1B2A3A → #133356 → #103A68`, artwork `#EDF2FA` and `#A8BCD3` — plus `Brand.iconGradient` for hero surfaces. The warm orange `#F97316` from D-043 is withdrawn.
- **Why:** The icon is the app's cover, and it is unambiguously a cool, dark, steel-blue object — a pale chevron over a charcoal-to-blue gradient. An orange interior behind a blue cover reads as two products. The author asked for the app to look like its icon, which settles it: the icon exists, the accent was a proposal.
- **Alternatives:** Keep the orange and treat the icon as a separate mark; redraw the icon in orange; pick a neutral accent that argues with neither.
- **Why not:** Two identities is the problem being fixed. Redrawing the icon discards finished artwork to protect an untested colour proposal. A neutral accent gives up the identity both candidates were trying to establish.
- **Date:** 2026-09-07
- **Impact:** Colours are *sampled* from `Icon-iOS-Default-1024x1024@1x.png` rather than eyeballed, so the app and its icon are provably the same object; `Brand` records the source file. Verified in the Simulator in both appearances.
  - D-043's warning that the accent should not be "Apple's default blue, already every app's tint" still stands and is not dismissed by this. The chosen blue shares Apple's hue (~211°) but at materially lower saturation — steel rather than vivid — so it reads as this icon's blue and not as an untouched system default. Worth re-examining on a real device against other apps' tints.
  - The `MuscleTint` palette stays warm and varied. Those colours differentiate muscle groups; they aren't brand, and cooling them all would cost the differentiation that earns them their place (D-043 §2).
  - `Brand.iconGradient` is defined but not yet applied anywhere. It's the obvious candidate for the End Workout summary hero and a launch screen; neither is built yet.

### D-066 — Destructive confirmations are alerts, not confirmation dialogs
- **Decision:** Every destructive confirmation — delete workout, delete logged session, discard in-progress workout — uses `.alert` rather than `.confirmationDialog`.
- **Why:** On iOS 26 `confirmationDialog` presents as a popover tethered to a source view. Raised from inside a `Form`, it anchors to whatever happens to be nearby rather than to the button that triggered it: observed pointing its callout tail at the tint picker while the trigger sat at the bottom of the screen. The narrow popover also wrapped the title mid-phrase. An alert is centered and modal by definition, which is what a destructive confirmation wants regardless of the bug.
- **Alternatives:** Keep `confirmationDialog` and find an anchor that behaves; wrap the trigger in something that gives the popover a sane source; ship as-is.
- **Why not:** The anchor is chosen by the system, so "find a better one" is guesswork that a future iOS can undo. Adding a wrapper view purely to steer a popover is scaffolding for a presentation detail.
- **Date:** 2026-09-08
- **Impact:** Buttons shorten to "Delete" / "Discard" — an alert already states the object in its title, so repeating it in the button was redundant in a narrower layout. `titleVisibility` goes away; alerts always show their title. This supersedes the mechanism, not the placement decision: destructive actions still live at the bottom of the screen they act on rather than in an overflow menu.

### D-067 — Exercise rows: swipe for Edit, Swap, Delete
- **Decision:** Exercise rows in the workout editor get one swipe action per edge: **right (leading) swaps, left (trailing) deletes**. Full swipe is enabled for swap and disabled for delete. Editing stays a tap on the row's disclosure. The row's inline sets/reps state moves from `WorkoutExerciseRow` to `WorkoutEditor`, keyed by id.
- **Amended 2026-09-08:** an earlier cut stacked Edit, Swap and Delete in a single trailing tray. Splitting them across edges gives each gesture one unambiguous meaning, and dropped Edit — tapping the row already opens that panel, so it was the one action in the tray that duplicated something.
- **Why:** Editing was tap-only on a `DisclosureGroup` whose sole affordance is a small chevron; swap did not exist at all, so changing a movement meant deleting it and re-adding, losing its position, set count and rep range. Grouping all three row actions in one tray makes the row's full capability visible in one gesture.
- **Alternatives:** Leave Edit out since tapping already does it; put Edit on the leading edge; allow full swipe.
- **Why not:** A stacked tray asks the user to read three buttons to find one; a side per action is decided before the tray even opens. Full swipe follows the stakes rather than being uniformly off: swapping only opens a picker that can be cancelled, so a fast flick is safe there, while a flick on the delete side would destroy the row — the same hazard that removed swipe-to-delete from Home.
- **Date:** 2026-09-08
- **Impact:** `WorkoutExerciseRow.expanded` becomes a `@Binding`; the editor holds a `Set<UUID>` of open rows, which also means reordering carries each row's open/closed state with it instead of leaving it attached to a position. Editing a workout's exercise only repoints `exerciseId`, keeping position, set count and rep range — unlike a mid-session swap (D-053) there is no logged data to invalidate.

### D-068 — Dynamic Type is honoured by scaling, and the set row reflows
- **Decision:** Every hero number moves from a literal point size to `@ScaledMetric(relativeTo: .largeTitle)`, keeping its designed size at the default setting while growing with Dynamic Type. The Active Workout set row switches to a two-line layout at `.accessibility1` and above. Touch targets below 44pt — the exercise swap button at 36, the program menu at 32, the set-completion tick — are raised to 44.
- **Why:** A literal `.font(.system(size: 44))` does not respond to Dynamic Type at all, so the largest numbers in the app were the ones that refused to grow for the people who most need them to. The set row packs six controls onto one line; past `.accessibility1` the weight field can no longer show three digits and the effort chip wraps into a column of letters.
- **Alternatives:** Swap the literal sizes for text styles like `.largeTitle`; let the row shrink with `minimumScaleFactor`; leave it and rely on the system.
- **Why not:** A text style would scale but change the design size at default — `.largeTitle` is 34pt where the hero wants 44. `minimumScaleFactor` fixes overflow by making text *smaller* for users who asked for bigger, which inverts the intent.
- **Date:** 2026-09-08
- **Impact:** `@ScaledMetric` applies to `ProgressCard`, `ExerciseDetailView`, `EndWorkoutSummary`, and `SessionDetailView`. The set row keeps one layout below `.accessibility1` so normal use is unchanged. **Not yet verified visually** — the Simulator would not stay booted long enough to capture a large-text screenshot, so this rests on the layout logic rather than observation, and should be checked on a device with text size at maximum.

### D-069 — Test coverage for the catalog loader and session lifecycle
- **Decision:** `ExerciseCatalogTests` (17) and `SessionLifecycleTests` (16) added, taking the suite to 66.
- **Why:** These were the two riskiest untested surfaces. `ExerciseCatalog.load()` indexes with `Dictionary(uniqueKeysWithValues:)`, which **traps on a duplicate id** — a bad `exercises.json` was a launch crash with no test to catch it. `SessionLifecycle` is the only code that creates and rewrites logged training data, and `swapExercise` destroys set state by design.
- **Alternatives:** Test through the UI; trust the bundled data; cover only `SessionLifecycle`.
- **Why not:** UI tests are slow and would not have located a duplicate id. The bundled file is generated by a script and hand-edited afterwards, which is precisely when duplicates appear.
- **Date:** 2026-09-08
- **Impact:** Catalog tests assert on the real bundled file, so they fail if a future edit introduces a duplicate id, a blank name, an entry with no primary muscle, an uppercase alias, or a muscle filter with no results. Lifecycle tests cover target snapshotting, suggestion seeding, the `max(targetSets, 1)` floor, swap reset and re-seeding, cascade on discard, and history exclusion of the in-flight session.
  - One test was written wrong and corrected rather than the code: it asserted that a name-prefix match always outranks a mid-name match. Per docs/06 §6 an alias is worth +3 each, so "Barbell Bench Press" (three alias hits, score 15) correctly beats "Bench Dips" (prefix, score 11) — which is the right answer for someone typing "bench". The test now checks prefix ordering only among entries with no alias hits, plus a second test asserting the alias boost surfaces the canonical lift.

### D-052 — Set completion advances focus to the next set's weight field
- **Decision:** Tapping a set's complete button moves keyboard focus to the *next* unlogged, non-skipped set's weight field. When no sets remain, focus drops and the next exercise with remaining sets expands and scrolls into view. Focus state lives on `ExpandedExerciseSection` (shared `@FocusState<SetFieldFocus?>` passed into each `WorkSetRow` as a binding), not inside the row.
- **Why:** Real-workout feedback: completing a set left the keyboard parked on the set just finished, so every set cost an extra tap to re-target. Logging should be tap-check, type, tap-check, type.
- **Alternatives:** Keep per-row `@FocusState` and do nothing; auto-advance only the "current set" highlight without moving the keyboard; also auto-focus the first set of the next exercise.
- **Why not:** A row's `@FocusState` is unreachable from its siblings, so per-row state can't express "advance." Highlight-only leaves the extra tap in place. Auto-focusing across an exercise boundary pops the keyboard on a movement the user hasn't walked to yet.
- **Date:** 2026-09-07
- **Impact:** `WorkSetRow` no longer owns focus; it takes a `@FocusState.Binding var focusedField: SetFieldFocus?`. New top-level `SetFieldFocus` enum keyed by `WorkSet.id`. `ExpandedExerciseSection` gained `onExerciseFinished`; `onSetCompleted` was removed (it was unused). `ActiveWorkoutView` wraps its `ScrollView` in a `ScrollViewReader` and gives both expanded and collapsed rows an `.id(se.id)` so the advance can scroll.

### D-053 — Mid-session exercise swap resets sets and re-seeds from the new exercise's history
- **Decision:** The expanded exercise card carries a swap button (`arrow.triangle.2.circlepath`) in its header, which presents the standard `ExercisePicker` directly — no intervening menu, since swapping is the only exercise-level action during a session. `SessionLifecycle.swapExercise(_:to:engine:context:)` rewrites `exerciseId` + `exerciseNameSnapshot` in place, keeps the slot / set count / target rep range, and resets every set (weight, reps, RIR, completion, skip) — re-seeding weight and reps from the **new** exercise's history via the `SuggestionEngine`.
- **Why:** Real-workout feedback: the planned machine is occupied, or the movement doesn't feel right that day. Without a swap the only options were to skip the exercise entirely or log it as something it wasn't.
- **Alternatives:** Carry the old exercise's logged weights over to the new one; delete the `SessionExercise` and add a fresh one; only allow swaps before any set is logged.
- **Why not:** Carrying weights over is actively dangerous — 100 kg on leg press is not 100 kg on hack squat. Delete-and-recreate loses the slot ordering and the snapshotted target range. Gating on "no sets logged" fails the common case of swapping out after a warm-up set reveals the machine is wrong.
- **Date:** 2026-09-07
- **Impact:** `SessionLifecycle.fetchHistory` is no longer `private`. `ExpandedExerciseSection` refreshes its history-derived pill via `.task(id: sessionExercise.exerciseId)` so a swap re-reads. The source `Workout` is untouched — a swap is session-local, and does not edit the program.

### D-054 — Elapsed-time readout in the Active Workout title
- **Decision:** The Active Workout navigation bar shows the workout name over a live elapsed timer (`Text(session.startedAt, style: .timer)`) in a `.principal` toolbar item. This is a session clock, not a rest timer.
- **Why:** Real-workout feedback: no sense of how long the session had been running. `startedAt` was already persisted; the readout is free.
- **Alternatives:** A rest timer between sets (D-014 declined it); a large timer card in the scroll content; no timer.
- **Why not:** D-014 stands — rest timing is not something the user wants the app to police. A content card costs vertical space that belongs to sets. `Text(_:style:.timer)` self-updates without a `Timer` or a redraw loop of our own.
- **Date:** 2026-09-07
- **Impact:** `.navigationTitle` is retained for accessibility but visually replaced by the principal item. Does not reopen D-014.

### D-055 — "Last" pill shows the heaviest past set inside the target rep range
- **Decision:** The expanded exercise header shows a `Last {weight} × {reps}` pill next to the target. `ProgressCalculator.recentBest(for:targetReps:excluding:in:)` walks completed sessions newest-first and returns the top set from the most recent session containing a rep count inside the target range, flagged `withinTarget: true` and accent-tinted. If no session ever hit the range, it falls back to the latest session's top set, flagged `withinTarget: false` and rendered in secondary grey. The in-progress session is excluded so today's sets aren't their own reference.
- **Why:** Real-workout feedback: progressive overload needs a like-for-like number. "Last time you did 100 kg × 8, and today you're targeting 6–8" is actionable; "last time you did a heavy triple" is not, when today is an 8-rep day.
- **Alternatives:** Keep the existing `lastSessionSummary` footnote ("3d ago: 100 kg × 5, 5, 4"); show the all-time rep-max for the target range; show nothing when there's no in-range match.
- **Why not:** The footnote reported the previous session verbatim regardless of rep range and was hardcoded to kg, so it read wrong for lb users. An all-time max is a PR, not a "what should I load today" reference — and PRs already live on Progress. Showing nothing hides useful context the first time a rep range changes.
- **Date:** 2026-09-07
- **Impact:** Replaces the `lastSessionSummary` line in `ExpandedExerciseSection` (that field is unchanged and still used by `ProgressCard` and `ExerciseDetailView`). The pill is unit-aware via the existing `displayUnit`, using the same locale-independent formatting rule as `WorkSetRow`. The header pill row is a horizontal `ScrollView` with `.fixedSize` pills so three pills never letter-stack.

### D-038 — RIR 0–5 (reps-in-reserve) · Supersedes D-013
- **Decision:** Effort per set is captured as RIR (reps-in-reserve, 0–5), NOT RPE (1–10). RIR 0 = failure; RIR 5 = very easy (5 reps left). `Set.rir: Int?` (optional). If a user prefers RPE mentally, they can convert (RPE = 10 - RIR).
- **Why:** The author's training is already logged in RIR, confirmed against their existing program on 2026-09-06. The earlier answer in D-013 was given without seeing the concrete tradeoff.
- **Alternatives:** RPE 1–10 (D-013, superseded); support both with user preference toggle.
- **Why not:** RPE forces user to mentally convert every set; toggle is small V1 tax but not needed since RIR matches their actual practice.
- **Date:** 2026-09-06
- **Impact:** `Set.rpe` renamed to `Set.rir` in the data model (both are `Int?` with different value ranges). UI shows an RIR chip 0–5. Progress-related derived metrics (e.g., "same weight, same reps, lower effort") use RIR ascending = harder inverted. Import from the author's prior CSV logs is now 1-to-1.

### D-037 — Ship full 584-exercise transformed seed; coverage pass improves quality on active subset
- **Decision:** V1 bundles all 584 exercises produced by the transformation script (no seed-size trim). A coverage pass is performed on the user's active exercise subset (~30–50 exercises) to (a) rename ugly source names to preferred display names, (b) populate `aliases` for common terminology (OHP, SLDL, etc.), and (c) correct primary muscles where the source data is wrong. Unused entries retain their as-transformed state.
- **Why:** Zero risk of missing an exercise the user needs; DB is complete on day one. Coverage pass focuses effort where it matters (search/browse quality on active exercises). Individual unused entries can be edited later via one-line PRs.
- **Alternatives:** Trim seed to ~80; ship 584 with no coverage pass; trim to ~150.
- **Why not:** Trimming reintroduces the "did we miss something" risk; skipping the coverage pass leaves ugly names and broken metadata in the user's daily-use exercises.
- **Date:** 2026-09-06
- **Impact:** Coverage-pass edits are recorded directly in `Forward/Resources/exercises.json` (not in the transformation script — that stays pure). If we ever re-run the transformation, we'd need to re-apply the coverage edits (documented in a manifest, TBD when we do the actual pass). Modifies RISK-001: risk is now "quality of search results on the user's active exercises" rather than "missing exercises."

### D-036 — Exercise DB taxonomy (finalized enum values) · **Superseded by D-046 (2026-09-07)**
The original text is preserved below for audit. See D-046 for the current taxonomy.

Original: 
- **Decision:** Forward's exercise taxonomy uses these enum values:
  - **MuscleGroup (13):** chest, back, lats, shoulders, biceps, triceps, quads, hamstrings, glutes, calves, core, forearms, traps.
  - **Equipment (8):** barbell, dumbbell, cable, machine, bodyweight, kettlebell, band, ezBar.
  - **MovementPattern (7):** push, pull, squat, hinge, lunge, carry, isolate.
  - Collapse rules from Free Exercise DB source: `abdominals→core`, `quadriceps→quads`, `middle back` + `lower back` → `back` (kept distinct from `lats`), `abductors/adductors/neck` dropped. `body only→bodyweight`, `bands→band`, `kettlebells→kettlebell`, `e-z curl bar→ezBar`, and `exercise ball / foam roll / medicine ball / other` exercises are filtered out.
- **Why:** Balances programming precision (lats separate from back matters for pull vs. row) against enum-surface parsimony. Drops values the user will never need.
- **Alternatives:** Fold lats into back (simpler); split back into upper/lower (more granular).
- **Why not:** Fold loses programming distinction; split adds noise for negligible benefit.
- **Date:** 2026-09-06
- **Impact:** Enum types locked. Any addition/removal requires a decision entry. Transformation script uses these collapse rules.

### D-034 — VersionedSchema from V1
- **Decision:** SwiftData schema is defined via `VersionedSchema` from the first release. Future migrations use `SchemaMigrationPlan`.
- **Why:** CloudKit-synced data must survive schema changes when users have devices on multiple app versions. Adding `VersionedSchema` retroactively is significantly harder than starting with it.
- **Alternatives:** Start with a flat schema; migrate to `VersionedSchema` later.
- **Why not:** Late migration is a real risk once users have data on iCloud.
- **Date:** 2026-09-06
- **Impact:** Small extra ceremony on V1 model definitions. Buys frictionless V2+ evolution.

### D-029 — Session persistence & interruption behavior
- **Decision:** Every action during an active session is immediately persisted; there is no in-memory-only mid-workout state. On cold-launch with an in-progress session, the app opens to Home showing a subtle banner ("Resume workout • Started X ago"). Only one in-progress session at a time; starting a new workout while one is in progress prompts (resume / save what you have / discard). No auto-end regardless of session age. No system notifications about in-progress sessions. HealthKit write happens only on End Workout.
- **Why:** Persist-on-every-action makes crash recovery free. Soft banner is least surprising, respects user autonomy. Modal-on-launch is obtrusive; auto-return can be confusing when sessions are old.
- **Alternatives:** In-memory session with save-on-end; auto-return to Active Workout on cold-launch (always, or if <4h old); modal resume prompt on launch; auto-end after N hours; system notification for stale sessions.
- **Why not:** In-memory loses data on kill; auto-return is confusing across long gaps; modal is obtrusive; auto-end punishes edge cases; notifications are anti-product.
- **Date:** 2026-09-06
- **Impact:** Session entity is written to SwiftData on `Start Workout`. Every set completion, deviation, and navigation triggers a save. Home queries for `Session.endedAt == nil` to show the banner. Starting a new session with one in progress uses a confirmation sheet. Closes Q-006.

### D-028 — HealthKit V1: minimum-viable workout write
- **Decision:** V1 adds the `com.apple.developer.healthkit` entitlement and writes each completed session to HealthKit as an `HKWorkout` of type `.traditionalStrengthTraining` (start/end/duration + source). No calorie estimation. No per-set `HKSample` records. No HealthKit reads. Permission is requested at first End Workout, not first launch. If permission is denied, the session still saves locally; user can grant later via system Settings.
- **Why:** Activity ring credit + presence in Health.app / Fitness.app are meaningful for Apple-ecosystem users. Cost is small (~50 LOC + one entitlement). Skipping calories and per-set samples avoids two categories of misleading or high-cost data.
- **Alternatives:** No HealthKit in V1; write + read body weight; fuller integration with per-set samples.
- **Why not:** Skipping loses Activity ring credit; adding body-weight reads adds a second permission scope for marginal V1 value; per-set samples are diminishing returns for the code cost.
- **Date:** 2026-09-06
- **Impact:** Adds HealthKit entitlement to `Forward.entitlements`. Introduces a `HealthKitWorkoutWriter` (or equivalent) module. Requires graceful denial handling. Body-weight read stays in the parking lot.

### D-027 — History screen: chronological session list
- **Decision:** History tab is a chronological list of past sessions (most recent first). Each row: date, template name, summary (exercise count + total sets + duration), PR badge if applicable. Tap → session detail showing every exercise with all sets, PR markers, notes, and Edit/Delete in a menu. Delete also via swipe on the list row. No calendar view, no filter, no mid-workout "see history" affordance in V1.
- **Why:** Per-exercise history is already covered by Progress detail (D-022). Per-template history is inferable from row labels. Mid-workout, the SuggestionEngine covers the primary "what did I do?" query.
- **Alternatives:** Calendar-first view; filter by template or exercise; two-mode (Sessions / By Exercise) segmented control; mid-workout "see history" chip on the exercise card.
- **Why not:** Calendar approaches heatmap territory (D-026); filter isn't earned until session count grows; two-mode duplicates Progress; mid-workout chip adds UI without evidence it's needed.
- **Date:** 2026-09-06
- **Impact:** History tab is a `List` with navigation to a session-detail view. Session editing and deletion are exposed but tucked. Closes Q-002.

### D-026 — Workout-frequency heatmaps require an argument to revisit
- **Decision:** GitHub-style "days you trained" heatmaps are in the parking lot with a high bar: revisiting requires an argument for how they help log a workout or see progress on key lifts.
- **Why:** Feels informative; is actually engagement chum. Whether you trained on the 14th vs. 15th is not a meaningful data point.
- **Alternatives:** Include in V2; include as a Settings toggle.
- **Why not:** Would drift toward being a default view; toggle isn't neutral.
- **Date:** 2026-09-06
- **Impact:** Not built in V1. Any V2 proposal must justify against Constitution §2.

---

## Risks

### RISK-001 — V1 exercise DB must cover the author's training
- **Description:** Because custom exercises are not user-creatable in V1 (D-011), the bundled exercise DB must contain every exercise the user does regularly. Missing an exercise means the user is blocked from logging a set.
- **Mitigation:** Before V1 ships, walk through the author's program exercise-by-exercise and confirm every exercise is present in the seed data. Add any gaps.
- **Owner:** Product team
- **Date raised:** 2026-09-06

---

## Parking Lot

Features that may or may not happen later. Adding an item here does not commit to shipping.

- Rest timer (auto-start / manual-start / toggle)
- Warm-up set type (`Set.type` enum extension)
- AMRAP / failure set flag
- Drop sets
- Supersets (requires `ExerciseGroup` entity)
- Cluster / rest-pause / myo-reps
- Timed exercises (plank, hang, carry)
- Bodyweight-assisted exercises
- Distance-based exercises
- Estimated 1RM as headline metric
- Volume dashboards (weekly / monthly tonnage)
- Muscle-group balance charts
- Workout-frequency heatmaps *(high bar — see D-026)*
- Auto-progression SuggestionEngine variants (Simple-2, Simple-3)
- User-created custom exercises
- Exercise animations / GIFs / videos / muscle diagrams
- Apple Watch app
- Widgets / Live Activities
- HealthKit workout writeback *(TBD — may be revisited for V1)*
- Import from other workout apps
- Multi-language / localization
- iPad-specific layout

---

## Anti-Product

Not "later" — declined.

- Gamification (streaks, badges, confetti, achievements) — D-024
- Engagement-driven notifications
- Per-accessory PR notifications — D-025
- Social features (feed, followers, comments, likes, leaderboards, sharing surface)
- AI coach behavior (nudges to train, deload advice, program recommendations)
- Subscriptions, in-app purchases, advertising, third-party analytics
- Behavioral tracking of any kind
- Required user account / login
- Custom UI patterns that fight iOS conventions

---

## Open questions

Tracked here so we don't forget. Each will become a decision when addressed.

- ~~Q-001 — Product name~~ *(closed by D-044; trademark/App Store check deferred to pre-submission)*
- ~~Q-002 — History screen design~~ *(closed by D-027)*
- ~~Q-003 — HealthKit go/no-go for V1~~ *(closed by D-028)*
- ~~Q-004 — iCloud sync approach~~ *(closed by D-030)*
- ~~Q-005 — Bundled exercise DB source and open-source licensing~~ *(closed by D-035 + D-036; see 06-exercise-database-specification.md)*
- ~~Q-006 — App-killed-mid-workout behavior (session recovery)~~ *(closed by D-029)*
- ~~Q-007 — Full data-model entity diagram~~ *(closed by D-033; see 05-technical-architecture.md)*
- ~~Q-008 — Design system~~ *(closed by D-043; see 04-design-system.md)*
- ~~Q-009 — Open-source license choice~~ *(closed by D-045: MIT)*
- ~~Q-010 — Persistence pattern for user flags on bundled read-only exercises~~ *(closed by D-031)*
