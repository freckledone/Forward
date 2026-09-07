# 06 — Exercise Database Specification

Source of truth for Forward's bundled exercise database. All schema, taxonomy, and provenance decisions here are backed by decision-log entries. Changing the schema or enum values requires a new decision entry.

---

## 1. Source & licensing

- **Source:** [Free Exercise DB](https://github.com/yuhonas/free-exercise-db)
- **License:** The Unlicense (public-domain dedication). Verified via GitHub API on 2026-09-06.
- **Terms:** unrestricted use, modification, redistribution. No attribution required.
- **Courtesy attribution:** We credit Free Exercise DB in the Forward README when the repo goes public (Q-009 pending). Not a legal obligation.

Per **D-035**, we ingest their data via a reproducible transformation script; we do NOT vendor their raw JSON. The bundled `exercises.json` in the app is a filtered, remapped, quality-controlled subset.

---

## 2. Taxonomy (D-036)

### 2.1 MuscleGroup (13 values)

```swift
enum MuscleGroup: String, Codable, CaseIterable {
    case chest
    case back           // rows, deadlift lockout, general back thickness
    case lats           // pulldowns, pull-ups — kept distinct from `back`
    case shoulders
    case biceps
    case triceps
    case quads
    case hamstrings
    case glutes
    case calves
    case core
    case forearms
    case traps
}
```

### 2.2 Equipment (9 values, per D-046)

```swift
enum Equipment: String, Codable, CaseIterable {
    case barbell
    case dumbbell
    case cable
    case machine              // selectorized / pin-loaded / stack-loaded
    case plateLoadedMachine   // Hammer Strength-style, plate-loaded hip thrust, plate-loaded leg press
    case bodyweight
    case kettlebell
    case band
    case ezBar
}
```

The `machine` vs. `plateLoadedMachine` split reflects a real training distinction (plate math + feel). Free Exercise DB source doesn't distinguish; transformation defaults all source `machine` → `machine`, and specific known plate-loaded exercises are overridden to `plateLoadedMachine` via `scripts/coverage-pass.py` `EQUIPMENT_FIXES`.

### 2.3 MovementPattern (7 values)

```swift
enum MovementPattern: String, Codable, CaseIterable {
    case push       // horizontal or vertical pressing
    case pull       // horizontal or vertical pulling
    case squat      // knee-dominant lower body
    case hinge      // hip-dominant lower body (deadlift, RDL, hip thrust)
    case lunge      // unilateral / split stance
    case carry      // loaded carry (farmer's, sled)
    case isolate    // single-joint isolation
}
```

---

## 3. JSON schema

Every entry in the bundled `exercises.json` conforms to:

```json
{
  "id": "bench-press-barbell",
  "name": "Barbell Bench Press",
  "aliases": ["flat bench", "bb bench"],
  "loadingMode": "weighted",
  "primaryMuscles": ["chest"],
  "secondaryMuscles": ["triceps", "shoulders"],
  "equipment": ["barbell"],
  "movementPattern": "push",
  "instructions": "Lie on the bench with your feet flat on the floor. Grip the bar just outside shoulder width. Lower the bar to your mid-chest with control. Press back to lockout."
}
```

**Field rules:**

- `id`: kebab-case, URL-safe, stable forever. Must be unique in the file. Once shipped, an id may not be reused for a different exercise.
- `name`: display name.
- `aliases`: array of alternate names used to boost search matches. May be empty. All lowercase.
- `loadingMode`: `"weighted"` or `"bodyweight"` (D-010).
- `primaryMuscles`: non-empty array of MuscleGroup enum raw values.
- `secondaryMuscles`: array (may be empty) of MuscleGroup values, disjoint from `primaryMuscles`.
- `equipment`: array of Equipment enum raw values. Bodyweight exercises are `["bodyweight"]`.
- `movementPattern`: single MovementPattern value, or null. Assigned during transformation.
- `instructions`: single string (join their instruction steps with `\n\n`). May be null.

**Fields intentionally omitted in V1:**
- `difficulty` — irrelevant for audience of 1
- `mediaReference` — parking-lot per D-011 context
- `notes` — not needed until custom exercises exist

---

## 4. Transformation pipeline

A script at `scripts/transform-exercises.py` (or equivalent) performs:

### 4.1 Category filter
Keep only exercises with `category` in: `strength`, `powerlifting`, `olympic weightlifting`, `strongman`. Drop: `cardio`, `plyometrics`, `stretching`.

### 4.2 Equipment filter
Drop entries where the source `equipment` is `exercise ball`, `foam roll`, `medicine ball`, or `other`. Their exercises don't map cleanly to our loading modes.

### 4.3 Field mapping
| Source | Target | Transform |
|---|---|---|
| `id` | `id` | Kebab-case normalize (`3_4_Sit-Up` → `3-4-sit-up`), lowercase |
| `name` | `name` | Keep as-is |
| — | `aliases` | Empty by default; populated in curation pass |
| `equipment` | `loadingMode` | `body only` → `bodyweight`, everything else → `weighted` |
| `equipment` | `equipment` | Map per D-036 rules, wrap in array |
| `primaryMuscles` | `primaryMuscles` | Enum-map per D-036 collapse rules; deduplicate |
| `secondaryMuscles` | `secondaryMuscles` | Same |
| `force` + `mechanic` + name heuristic | `movementPattern` | Rule-based (see 4.4) |
| `instructions` | `instructions` | `"\n\n".join(steps)` |
| `category`, `level`, `mechanic`, `force`, `images` | dropped | Not in target schema |

### 4.4 Movement pattern derivation

Priority order (first match wins):
1. Name contains "squat" and not "swing" → `squat`
2. Name contains "deadlift" | "romanian" | "hip thrust" | "good morning" → `hinge`
3. Name contains "lunge" | "step-up" | "split squat" | "bulgarian" → `lunge`
4. Name contains "carry" | "farmer" | "sled" → `carry`
5. `mechanic` == "isolation" → `isolate`
6. `force` == "push" → `push`
7. `force` == "pull" → `pull`
8. Otherwise → null

Reviewed post-generation for miscategorizations.

### 4.5 Deduplication & sanity checks
- No duplicate `id` values.
- No exercise has an empty `primaryMuscles` array.
- No `primaryMuscles` overlaps with `secondaryMuscles`.
- All enum values validate against D-036.

### 4.6 Coverage pass
After transformation, the resulting ~600-exercise pool is filtered to the ~60–80 exercises the author actually needs, plus reasonable substitutions. This is done interactively with the user. This closes **RISK-001**.

---

## 5. Bundled loading

- File path in Xcode target: `Forward/Resources/exercises.json`.
- Loaded once at app startup by an `ExerciseCatalog` (or similarly named) service.
- Parsed into a `[String: Exercise]` dictionary keyed by `id`.
- Held in memory for the app's lifetime; not written to SwiftData (D-031).
- Reload happens only on app relaunch (JSON is bundled with the app version).

---

## 6. Search behavior (V1)

**Requirements:**
- Fast enough to feel instant on a modern iPhone (single-digit millisecond query time on 100 exercises — trivial).
- Forgiving: tolerates typos, matches partial words, matches aliases, is case-insensitive.

**V1 algorithm:**
1. Lowercase the query.
2. For each exercise, compute a match score:
   - +10 if `name` starts with the query.
   - +5 if `name` contains the query.
   - +3 for each `alias` that contains the query.
   - +1 if the query matches any word boundary in `name`.
3. Sort by score desc, then alphabetically.
4. Return top 20.

This is not fuzzy search (no Levenshtein). For V1 volumes it's plenty. If typo tolerance becomes annoying, upgrade to a Levenshtein-based scorer.

---

## 7. Category / filter UI

Search is only one path. Users can also browse by:
- **Muscle group** (chest, back, lats, etc.)
- **Equipment** (barbell, dumbbell, etc.)

Filter UI shows the enum values as chips. Filtering happens in Swift against the in-memory catalog (no `#Predicate` — Exercise isn't a SwiftData model).

Combined filters use AND logic: `equipment=[barbell] AND primaryMuscles CONTAINS chest`.

---

## 8. Coverage validation (RISK-001)

Before V1 ships, walk through the author's program exercise-by-exercise and confirm every one is in the seed. Add any missing ones by:
1. Fetching from Free Exercise DB (via slug) if it exists
2. Otherwise, hand-writing a new entry conforming to the schema

This step is required to ship. Track completion in the project's TODO or roadmap.

---

## 9. Future evolution

Not in scope for V1 but tracked here:

- **User-created custom exercises** (parking-lot from D-011): when added, they'll live in a `CustomExercise` SwiftData model, keyed by UUID, unioned into search results with a visual distinction.
- **Media** (parking-lot): when added, an `imageReference: String?` field with content addressed via a licensed CDN or bundled assets. Requires resolving image licensing separately from the Unlicense source data.
- **Localization** (parking-lot): exercise names in multiple languages. Requires per-locale JSON files or a keyed lookup approach.
