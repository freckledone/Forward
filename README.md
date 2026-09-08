# Further

An iOS strength-training tracker. Log your sets, see whether you're progressing
on the lifts you care about, and nothing else.

Further is built for one kind of person doing one thing well:

> Log strength workouts and see progress on the lifts they care about, with as
> little friction as possible.

Every feature is answered against that test. If it doesn't help you log a
workout or understand your progress, it doesn't ship.

## What it does

- **Programs → Workouts → Exercises.** Save the workout days you actually run,
  with set counts and target rep ranges. Start one and log against it.
- **Active workout on a hybrid grid.** Every exercise stays visible; the
  current one expands with its set grid. Completing a set moves the keyboard to
  the next set's weight field.
- **Suggestions from your own history.** Each set is pre-filled with what you
  did in the same slot last time. No algorithm deciding you should add 2.5 kg.
- **Effort as RIR (0–5).** Reps in reserve, not RPE.
- **Progress on key lifts.** Star the lifts that matter; per-rep-count personal
  records and a session-over-session weight/rep comparison.
- **iCloud sync** through your private CloudKit database.
- **Apple Health** — finished sessions are written as strength-training
  workouts so they count toward your rings.
- **JSON backup** — export everything, import it back. Import is additive and
  keyed by UUID, so it never overwrites or deletes what you already have.

## What it will never do

Not deferred — declined. No gamification, streaks, or badges. No engagement
notifications. No social features. No subscriptions, in-app purchases, ads, or
analytics. No behavioral tracking. No account or login. No AI coach — the
suggestion engine is a data lookup, and it will never tell you to train.

The full list lives in [`docs/00-constitution.md`](docs/00-constitution.md).

## Building

Requires Xcode 16+ and iOS 17+.

```sh
git clone git@github.com:freckledone/Further.git
cd Further
open Further.xcodeproj
```

It builds and runs in the Simulator immediately, with placeholder identifiers.

**To run on a device, or use iCloud sync and Apple Health**, supply your own
Apple Developer identifiers:

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Then edit that file:

```
FURTHER_TEAM_ID          = YOURTEAMID
FURTHER_BUNDLE_ID        = com.yourname.Further
FURTHER_ICLOUD_CONTAINER = iCloud.com.yourname.Further
```

`Config/Local.xcconfig` is git-ignored. Those three values feed the project's
signing settings, the entitlements file, and the container identifier the app
reads at runtime — so this is the only file you need to touch.

In Xcode, provision the CloudKit container under **Signing & Capabilities →
iCloud** so it matches `FURTHER_ICLOUD_CONTAINER`. Without it the app still
runs; it falls back to a local-only store and says so in Settings.

## Architecture

SwiftUI and SwiftData throughout, on a `VersionedSchema` from day one. Every
model is written to CloudKit's constraints — defaulted or optional attributes,
optional relationships with explicit inverses, no unique attributes — so sync
is a configuration change rather than a migration.

```
Further/
  Models/      SwiftData models + the V1 schema
  Services/    Suggestions, progress math, backup, sync + Health status
  Views/       Workouts, Active Workout, History, Progress, Settings
  Resources/   Bundled exercise catalog (read-only)
docs/          Constitution, product vision, design system, architecture,
               and the decision log
```

The suggestion engine sits behind a protocol so the algorithm can change
without touching the UI.

### `docs/07-roadmap.md`

What happens next and why: what is left before V1 ships, what V2 might contain,
and — more usefully — what has been declined and on what grounds.

### `docs/decision-log.md`

Every product, UX, and architectural decision, with the alternatives that were
considered and why they lost. Decisions are never edited in place — a change
gets a new entry that supersedes the old one. If you want to know why the app
is shaped this way, read that file rather than guessing from the code.

## Testing

```sh
xcodebuild test -project Further.xcodeproj -scheme Further \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Unit tests cover unit conversion, progress and personal-record calculation, and
the backup format's round-trip fidelity, idempotency, and rejection of
malformed input.

## Credits

The bundled exercise catalog is derived from
[Free Exercise DB](https://github.com/yuhonas/free-exercise-db), released into
the public domain under the [Unlicense](https://unlicense.org). Entries were
transformed into Further's schema by
[`scripts/transform-exercises.py`](scripts/transform-exercises.py), then
hand-corrected for naming, aliases, and muscle assignments. See
[`docs/06-exercise-database-specification.md`](docs/06-exercise-database-specification.md).

## License

[MIT](LICENSE) © Yuri Gurgenidze
