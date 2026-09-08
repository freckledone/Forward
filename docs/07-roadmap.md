# 07 — Roadmap

What happens next, and why. Like every other document here, this one is
subordinate to `00-constitution.md` and answers to its one question:

> Does this help the user log their workout or understand their progress?

A roadmap is not a promise. Items below move only when a decision entry in
`decision-log.md` says they move.

---

## Where V1 stands

Feature-complete as of 2026-09-09. Workouts, Active Workout, History, Progress
and Settings are built. CloudKit private-database sync, Apple Health workout
writeback, JSON backup export/import, app icon, dark mode. 66 unit tests pass.
The Release archive builds clean at 1.0 (1).

---

## Phase A — Ship V1

Nothing here is a feature. It is the distance between "works on my machine" and
"installed on a phone."

**A1 · Verify on a real device.** Still unconfirmed, and everything downstream
assumes it:

- CloudKit sync actually moving records. The container opens and the schema
  validates, but the Simulator has no iCloud account, so records flowing has
  never been observed. Settings should read "On" with a *Last activity* that
  moves; the CloudKit Dashboard should show `CD_*` record types.
- Apple Health producing a real `HKWorkout` on End Workout.
- The large-text layout. `@ScaledMetric` hero numbers and the two-line set row
  past `.accessibility1` are reasoned but unobserved (D-068).

**A2 · CloudKit schema to Production.** Development schema does not carry to
production. Without this, TestFlight installs hit an empty schema (D-061). The
container changed with the rename, so this applies to the new one.

**A3 · TestFlight.** Confirm `aps-environment` flips from `development` at
export; a development APS environment can break CloudKit push in TestFlight.

**Exit criteria:** the author has trained with a TestFlight build, and their
data survived the trip.

---

## Phase B — Train on it

**No feature work. Deliberately.**

The strongest evidence this project has produced about what to build next came
from a single real workout: set completion should advance and open the keyboard,
exercises need swapping mid-session, the session needs a clock, and the target
needs last time's number beside it. All four shipped. **None of them were on the
parking lot** — three days of planning did not surface any of them.

The parking lot is not a backlog waiting for capacity. Read the deferrals back
and most are the author's own refusals: custom exercises were "explicit user
preference" (D-011), the rest timer was "explicitly rejected" (D-014), smarter
suggestions would put the app "in the coach's seat" (D-007). Re-opening one
needs a new reason, not elapsed time.

So: use the app for roughly a month and keep a friction list. That list is
Phase C's input. Anything planned before it exists is a guess competing with
evidence that hasn't arrived yet.

---

## Phase C — V2 candidates

Unordered until Phase B produces its list. Recorded now so the reasoning isn't
re-derived later.

### In progress

**Timed exercises** (D-010, D-042). The only parking-lot item that is a concrete
hole rather than a preference: Side Plank is in the author's own program and the
data model cannot represent it. Shipped 2026-09-09 (D-072): a `.timed` loading mode, a
duration field on `WorkSet`, hold targets on the workout and its session
snapshot, and a "best set = longest hold" rule for progress.

**Custom exercises** (D-011). Shipped 2026-09-09 (D-073): a `CustomExercise`
model projected into an `Exercise`, merged into the catalog so every existing
lookup, search and filter path works unchanged, with a form mirroring the
bundled JSON schema field-for-field.

**Live Activity.** Still to build. Needs a Widget Extension target, which has to
be added through Xcode's template rather than by editing the project file.

### Planned, not started — Apple Watch app

Accepted into the roadmap 2026-09-09; **no implementation yet, deliberately.**

The single largest possible reduction in logging friction: the phone stays in
the bag and sets are logged from the wrist. It serves the constitution's first
clause more directly than anything else in this document, and it is also the
largest scope in it by a wide margin — a second target, a second interface, and
a sync story between them.

Two things should happen before any code:

1. **Phase B's friction list.** A Watch app is a bet on *where* logging is
   awkward. Wearing V1 to the gym for a month is how that gets answered rather
   than assumed.
2. **Its own decisions.** Whether the Watch is a remote for the phone or an
   independent logger; what happens when they disagree; whether the phone app
   changes at all. Each is a decision-log entry, not an implementation detail.

### Explicitly not planned

- **Exercise media / images** (D-011, docs/06). Licensing must be resolved
  separately from the Unlicense source data, for near-zero value to someone who
  already knows their lifts.
- **Localization** (docs/06). Audience of one (D-001).
- **Periodization — cycles, blocks, deloads** (D-041). The reasoning holds: any
  template can be started at any time without the app's help.
- **Workout-frequency heatmaps** (D-026). The bar set for revisiting is an
  argument for how it helps log a workout or see progress on key lifts. That
  argument has not been made, and the feature is gamification-adjacent.
- **Auto-adjusting suggestions** (D-007). The useful half — "last time: 100 kg ×
  8, inside your target range" — already shipped as the Last pill (D-055).
  Anything beyond it is prescription, which the constitution rules out.
- **Everything on the anti-product list** (`00-constitution.md` §4). Not
  deferred. Declined.

---

## Open questions

- **Q-011 — Does D-024 stand as written?** It records gamification as
  permanently anti-product, "not V2 material." The author's actual answer when
  asked was "these are all nice, maybe add them to V2" — softer than the
  decision that got written. Until this is settled, it is unclear whether
  streaks and badges are even discussable.
- ~~Q-012 — Do the identifiers move to `Further`?~~ *(closed 2026-09-09.*
  *D-070 kept them on `Forward` deliberately, since changing them is a data*
  *migration rather than a rename. They then had to move anyway when the*
  *bundle id turned out not to be unique: `com.freckledone.Further` with a*
  *matching container. No `Forward` strings remain in any identifier.)*
