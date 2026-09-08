# 05 — Technical Architecture

Source of truth for the technical design of Further V1. Every claim below is either backed by a decision entry (D-XXX in `decision-log.md`) or is a downstream consequence of one. Do not change this document without a corresponding decision-log entry.

---

## 1. Tech stack

- **Language:** Swift
- **UI:** SwiftUI (D-030 implies; Constitution §3)
- **Local persistence:** SwiftData
- **Cloud sync:** CloudKit via SwiftData's built-in integration (D-030)
- **Schema versioning:** `VersionedSchema` + `SchemaMigrationPlan` from V1 (D-034)
- **Health integration:** HealthKit — write-only, workouts only (D-028)
- **Third-party dependencies:** none, unless a specific need is justified in a future decision entry

No networking layer. No analytics SDK. No custom logging framework. No third-party UI or state libraries.

---

## 2. Application shape

```
Root (App)
└─ RootView (TabView)
   ├─ WorkoutsTab       Home = template list + Recent + in-progress banner
   │  └─ TemplateEditor
   │  └─ ActiveWorkout    (presented modally / full-screen when session in progress)
   │  └─ EndWorkoutSummary (modal after End Workout)
   │  └─ Settings         (via gear icon in Workouts nav bar)
   ├─ HistoryTab        Chronological session list
   │  └─ SessionDetail
   └─ ProgressTab       Dashboard of key-lift cards
      └─ ExerciseDetail    per-key-lift chart + rep-max grid + session list
      └─ AllExercises      link at bottom of dashboard
```

Tab structure is tentative per D-019.

---

## 3. Data model

### 3.1 Bundled content (read-only, in-memory)

Loaded once at app launch from a bundled JSON resource. Represented as Swift value types. **Not** a SwiftData model.

```swift
struct Exercise: Codable, Identifiable, Hashable {
    let id: String                        // stable slug, e.g. "bench-press-barbell"
    let name: String
    let aliases: [String]                 // for forgiving search
    let loadingMode: LoadingMode
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
    let equipment: [Equipment]
    let movementPattern: MovementPattern?
    let instructions: String?
}

enum LoadingMode: String, Codable {
    case weighted           // weight + reps
    case bodyweight         // reps + optional added weight (dip belt, vest)
}

// MuscleGroup, Equipment, MovementPattern — enums to be finalized in
// 06 — Exercise Database Specification.
```

**Interpretation rules:**

- On `.bodyweight` exercises, `WorkSet.weightKg` means **added** weight, not total. Zero = bodyweight only.
- `id` is a stable string slug. Sessions and templates reference exercises by this slug. Renaming an exercise in the bundled DB does not break historical data because sessions snapshot the display name (see 3.2).

### 3.2 User data (SwiftData; CloudKit private database)

All models below sync via CloudKit. All properties are optional or defaulted (CloudKit constraint). No `@Attribute(.unique)` anywhere.

```swift
@Model
final class Template {
    var id: UUID = UUID()
    var name: String = ""
    var displayOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]? = []
}

@Model
final class TemplateExercise {
    var id: UUID = UUID()
    var exerciseId: String = ""          // → Exercise (by slug, D-031)
    var displayOrder: Int = 0
    var targetSets: Int = 0
    var targetRepsMin: Int = 0           // rep range min (D-039)
    var targetRepsMax: Int = 0           // rep range max (D-039); equal to min for fixed reps
    var template: Template?
}

@Model
final class Session {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?                   // nil == in-progress (D-029)
    var templateId: UUID?                // reference (not a @Relationship); nil = freestyle
    var templateNameSnapshot: String?    // preserved even if template deleted
    var note: String?
    var healthKitWorkoutUUID: UUID?      // set when HKWorkout written (D-028)
    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise]? = []
}

@Model
final class SessionExercise {
    var id: UUID = UUID()
    var exerciseId: String = ""          // → Exercise (by slug)
    var exerciseNameSnapshot: String = ""  // preserved even if DB renames/removes
    var displayOrder: Int = 0
    var session: Session?
    @Relationship(deleteRule: .cascade, inverse: \WorkSet.sessionExercise)
    var sets: [WorkSet]? = []
}

@Model
final class WorkSet {
    var id: UUID = UUID()
    var order: Int = 0
    var weightKg: Double = 0             // canonical kg (D-004); on .bodyweight = added
    var reps: Int = 0
    var rir: Int?                        // reps-in-reserve 0–5, optional (D-038); 0 = failure
    var completedAt: Date?               // nil = not yet completed
    var skipped: Bool = false
    var sessionExercise: SessionExercise?
}

@Model
final class ExerciseUserFlag {
    var id: UUID = UUID()
    var exerciseId: String = ""          // → Exercise (by slug)
    var isKey: Bool = false              // Progress-dashboard membership (D-020, D-031)
    var updatedAt: Date = Date()
}

@Model
final class UserPreferences {
    var id: UUID = UUID()
    var displayUnit: String = "kg"       // "kg" | "lb" (String for CloudKit-safety)
    var healthKitEnabled: Bool = false   // mirrors actual OS permission
    // future prefs added here
}
```

**Naming note:** `WorkSet` avoids collision with Swift's `Set` type.

**Enum serialization:** Enums are stored as `String` raw values, not Int, to survive schema changes gracefully.

### 3.3 Relationships (visual)

```
Template ─(cascade)─→ TemplateExercise ──(by exerciseId)──→ Exercise
                                                                ▲
Session ─(cascade)─→ SessionExercise ─(cascade)─→ WorkSet       │
   │                     │                                       │
   │                     └─────────────(by exerciseId)───────────┤
   └─(by templateId; weak reference)─→ Template                  │
                                                                 │
ExerciseUserFlag ────────────(by exerciseId)────────────────────┘

UserPreferences (singleton, queried lazily)
```

### 3.4 Design rules

1. **All IDs are UUIDs** except `Exercise.id` which is a stable string slug.
2. **`exerciseId` string slugs are the reference type.** Never a SwiftData `@Relationship` to `Exercise` — Exercise isn't a SwiftData model.
3. **Filtering by exercise metadata happens in Swift**, not in `#Predicate`. Load records, then filter in-memory using the bundled Exercise dictionary. Data volumes are small enough that this is fine.
4. **Templates and Sessions are independent.** Deleting a template does NOT cascade to sessions. `Session.templateNameSnapshot` preserves the label. `Session.templateId` becomes a dangling reference — that's fine; UI treats missing template as "freestyle" or shows the snapshot name.
5. **Snapshot names on `SessionExercise`.** Historical sessions display the name as it was at the time the set was logged.
6. **Do NOT snapshot names on `TemplateExercise`.** Templates re-render from the live bundled DB. If an exercise disappears, template UI shows a fallback placeholder.
7. **PRs are computed on demand.** No PR cache in V1. If performance shows the need at scale, add a `PersonalRecord` model later.
8. **UserPreferences is a singleton** by convention. Query for the single record; create if none exists.
9. **In-progress session query:** `Session.endedAt == nil`. Used for the Home resume banner (D-029).

---

## 4. Persistence & sync

### 4.1 SwiftData + CloudKit setup

- One `ModelContainer` for the whole app, configured with CloudKit sync enabled.
- CloudKit container identifier: `iCloud.<bundle-id>` (to be set on `Further.entitlements` when we start coding). The scaffold's identifier array is currently empty.
- Private database only. No shared or public zones.

### 4.2 CloudKit constraints (already reflected in the model above)

- All model properties must be optional or have default values.
- No unique constraints (`@Attribute(.unique)`); we generate UUIDs.
- All `@Relationship` must specify an explicit `inverse`.
- Enums stored as raw values (String) survive schema changes better.
- `Date` and `UUID` are CloudKit-compatible.

### 4.3 Sync behavior

- **Local is always source of truth.** Every action writes to SwiftData immediately (D-029). CloudKit sync is best-effort and asynchronous.
- **Sync latency:** typically seconds; can extend to minutes on poor networks. Never surface CloudKit progress as blocking UI.
- **First-launch on a new device:** CloudKit pulls existing user data. Home shows a subtle "iCloud syncing…" indicator only if the local DB is empty AND CloudKit is available AND account status is signed in. Never surface errors as modals.
- **iCloud unavailable / signed out / restricted:** the app is fully functional locally. When iCloud returns, sync catches up. No prompts, no nags.

### 4.4 Multi-device edge cases

- **Two devices with in-progress sessions:** each device generates a separate `Session` record with `endedAt == nil`. CloudKit sync reconciles both. The Home banner uses the most recent `startedAt`. When Start Workout is tapped with ≥1 in-progress session anywhere, the confirm sheet (D-029) lists all in-progress sessions and offers resume / save-as-is / discard per each.
- **Template concurrent edits:** last-write-wins per CloudKit default. Rare in practice for a single-user app.
- **Deleted session on Device A, still visible on Device B until sync:** normal CloudKit behavior. No special handling.
- **HealthKit workout duplication:** guarded by `Session.healthKitWorkoutUUID`. If the field is non-nil, the workout is already written; do not re-write. If the session is deleted, delete the corresponding `HKWorkout` if the UUID is present.

---

## 5. Session lifecycle

### 5.1 Start Workout

1. User taps a template on Home (or "Start Empty Workout" — freestyle path).
2. Check for existing in-progress sessions. If any, present the confirm sheet.
3. Create a `Session` with `startedAt = now`, `templateId = template.id` (or nil), `templateNameSnapshot = template.name`.
4. For each `TemplateExercise`, create a `SessionExercise` with `exerciseNameSnapshot = current name from bundled DB`, `displayOrder`, and `exerciseId`.
5. For each expected set, create a `WorkSet` with `weightKg`, `reps` pre-filled by the SuggestionEngine (D-007) and `completedAt = nil`.
6. Save to SwiftData.
7. Navigate to Active Workout.

### 5.2 During the workout

- **Every field edit persists immediately.** Weight change → save. RIR tap → save. Reps change → save.
- **Set completion:** `WorkSet.completedAt = now`. Persist.
- **Skip set:** `WorkSet.skipped = true`. Persist.
- **Add set:** append a new `WorkSet` to the `SessionExercise`. Persist.
- **Add exercise not in template:** append new `SessionExercise`. Persist. Template unchanged (D-015).
- **Skip / swap exercise:** remove or replace the `SessionExercise`. Persist. Template unchanged.

### 5.3 End Workout

1. User taps End Workout.
2. `Session.endedAt = now`. Persist.
3. If HealthKit permission granted OR not-yet-asked: request permission (only on first End Workout). If granted, write `HKWorkout` with type `.traditionalStrengthTraining`, start/end/duration, set `Session.healthKitWorkoutUUID`. If denied, skip HealthKit silently.
4. Compute PRs (in-memory scan of past sets for each exercise in the session).
5. Present summary sheet: totals, PRs, optional note field.
6. On Done: dismiss to Home.

### 5.4 Interruption / resume

- **Cold-launch with `Session.endedAt == nil`:** Home shows the resume banner. Tap → navigate to Active Workout with the session loaded.
- **Warm-launch (background → foreground):** if the user was on Active Workout when backgrounded, restore that screen. Otherwise Home + banner.
- **No auto-end.** A session with `endedAt == nil` from a week ago is still resumable.

### 5.5 Session deletion

- Deleting a session cascades to `SessionExercise` and `WorkSet` (SwiftData delete rules).
- If `Session.healthKitWorkoutUUID` is non-nil, delete the corresponding `HKWorkout` from HealthKit best-effort.
- Deletion is always confirmed before executing.

---

## 6. First-launch flow

1. `ModelContainer` initializes with CloudKit-enabled schema.
2. Load bundled exercise JSON into an in-memory `ExerciseCatalog` (dictionary keyed by slug).
3. Query for `UserPreferences`; if none, create one with defaults (`displayUnit = "kg"`, `healthKitEnabled = false`).
4. Query for `Template.count`; if zero AND CloudKit account is available AND signed in → show subtle "iCloud syncing…" indicator briefly (max ~5 seconds).
5. Once done: Home renders. If no templates exist locally after sync attempt → empty state + CTA (D-017).
6. No welcome screens, no sample data, no permission prompts on first launch. HealthKit permission is requested at first End Workout (D-028), not before.

---

## 7. HealthKit integration

Per D-028:

- Entitlement: `com.apple.developer.healthkit` (to be added).
- **Write-only.** No reads in V1.
- **Workouts only.** No per-set `HKSample` records.
- **No calorie estimation.** Never write a fake number.
- **Permission timing:** first End Workout, not first launch.
- **Denial handling:** session still saves locally. User can grant later via system Settings → Privacy → Health → Further.
- **Deletion sync:** deleting a session in Further attempts to delete the corresponding `HKWorkout` if `healthKitWorkoutUUID` is set. Best-effort; if HealthKit deletion fails, the local session deletion still succeeds.

`HealthKitWorkoutWriter` (or similar) module encapsulates all HealthKit code so the rest of the app has no HealthKit imports.

---

## 8. SuggestionEngine

Per D-006 and D-007:

```swift
protocol SuggestionEngine {
    func suggest(
        for exerciseId: String,
        setIndex: Int,
        history: [SessionExercise]  // past SessionExercises for this exerciseId,
                                    // ordered most-recent-first
    ) -> SuggestedSet?
}

struct SuggestedSet {
    let weightKg: Double
    let reps: Int
}
```

V1 implementation:

```swift
struct LastSessionSuggestionEngine: SuggestionEngine {
    func suggest(
        for exerciseId: String,
        setIndex: Int,
        history: [SessionExercise]
    ) -> SuggestedSet? {
        guard let lastSession = history.first,
              let lastSets = lastSession.sets?.sorted(by: { $0.order < $1.order }),
              setIndex < lastSets.count else { return nil }
        let set = lastSets[setIndex]
        return SuggestedSet(weightKg: set.weightKg, reps: set.reps)
    }
}
```

The Active Workout view calls the engine when populating a `Session` (D-029 §5.1 step 5). It never calls the engine again during the session; the pre-fill happens once at session creation.

---

## 9. Migrations

- Ship V1 with a `VersionedSchema` even though there is nothing to migrate from (D-034).
- Every V2+ change adds a new schema version and a `SchemaMigrationPlan` step.
- Lightweight migrations (add optional field, rename with `@Attribute(originalName:)`) are preferred.
- Custom migrations (data reshaping) are documented in the corresponding decision entry and unit-tested.

---

## 10. Testing considerations

- **Unit tests** for: `SuggestionEngine` implementations, unit conversion (kg↔lb), PR computation, HealthKit workout mapping.
- **Model tests** (SwiftData with an in-memory container): CRUD for each entity, cascade delete rules, snapshot preservation on template deletion.
- **UI tests** for the critical path: create template → start workout → log sets → end workout → verify summary shows PRs.
- **HealthKit tests** are limited on simulator; real-device manual verification is required for the write path.
- **CloudKit sync tests** cannot be run in CI reliably. Manual multi-device verification pre-release.

---

## 11. Open architectural questions

Tracked in `decision-log.md` under Open questions. Currently blocking implementation:

- ~~Q-004 iCloud sync approach~~ (closed by D-030)
- ~~Q-007 Full data model~~ (closed by D-033, this document)
- ~~Q-010 User flag persistence~~ (closed by D-031)

Still open, not blocking implementation start but needed before ship:

- **Q-005** — Exercise DB source and OSS licensing (blocks exercise-catalog population)
- **Q-008** — Design system (blocks visual polish)
- **Q-001** — Product name (blocks final rename and App Store submission)
- **Q-009** — Open-source license choice (blocks public repo)

Not yet raised as questions but relevant to note:

- **CloudKit container provisioning.** When we start coding, we set `iCloud.<bundle-id>` and provision the container in the Apple Developer portal. First app run creates the schema.
- **CloudKit schema deployment.** Development schema is live during Xcode debug runs; production schema deploys via the CloudKit Dashboard before App Store release. Standard workflow.
- **PR-caching threshold.** When (if ever) we introduce a `PersonalRecord` cache model. Not needed for V1; revisit if profiling shows Progress detail lagging past ~500 sets per exercise.
