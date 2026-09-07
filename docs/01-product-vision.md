# 01 — Product Vision

## The problem

Modern workout tracking apps have drifted away from being tools. They ship with:

- Aggressive subscription paywalls
- Overwhelming feature surfaces (coaching, nutrition, social feeds, communities)
- Engagement mechanics (streaks, badges, notifications) designed to keep users opening the app rather than to help them train
- Custom UI that fights iOS conventions
- Buried historical data — the numbers you actually need are three taps away

For someone who just wants to lift, log what they did, and see whether they're getting stronger, every one of those features makes the app *worse* at its actual job.

## What we're building

A native iOS strength-training tracker that does one thing well:

> Help the user log workouts and see progress on the lifts they care about, with as little friction as possible.

Concretely:

- **Log workouts.** Templates saved once; sessions that pre-fill from your last performance; per-set weight, RPE, and reps captured without ceremony.
- **See progress.** A dashboard of your starred key lifts, each with a current PR, trend chart, and rep-max grid. No dashboards for metrics you didn't ask for.
- **Own your data.** Local-first storage. iCloud sync between your own devices. No account. No backend. No analytics. Yours to export at any time.

## Who it's for

**V1 is designed for one person: the author.** This is a real product principle, not a placeholder. It means:

- No onboarding tour.
- No beginner-mode features.
- Exercises the author doesn't do are not first-class in V1.
- Training patterns the author doesn't follow are not accommodated in the UI.

If the app is later opened to a broader audience or open-sourced, this assumption may be revisited. Until then, "audience of 1" protects scope from every *"but what if a user wants…"* argument.

## What makes it different

Almost every difference from existing apps comes from things we *don't* do:

- No subscription — free forever.
- No account — nothing to sign up for.
- No engagement mechanics — no streaks, no badges, no notifications urging you back.
- No AI coach — the app doesn't tell you what to train; you told it.
- No custom UI — the app looks and feels like iOS, because it is iOS.
- No social layer — no feed, no followers, no sharing surface.

The positive differences are consequences of those:

- The Active Workout screen shows only what you need mid-set. Templates are living documents that carry history.
- The Progress screen shows only the lifts you starred. No noise.
- The whole app is offline-first. iCloud is a sync mechanism, not a dependency.
- Every architectural choice is designed for open-source clarity — no keys, no secrets, no proprietary media.

## Boundaries — what this app is not

This app is not:

- A nutrition tracker.
- A cardio / running app.
- An AI coach.
- A social fitness network.
- A programming platform for coaches and clients.
- A general fitness dashboard.
- A wearables ecosystem product.

Each of those is a real product; none of them is this product.

## The mood

Beyond features, the app should feel a specific way:

- **Calm.** Nothing is flashing, animating for attention, or asking to be noticed.
- **Confident.** The app makes clear decisions about what matters and doesn't apologize.
- **Native.** It could sit next to Notes, Reminders, and Fitness on the home screen without looking out of place.
- **Honest.** Data is presented plainly. No inflated numbers, no manipulative framings, no engagement-friendly rounding.

The user should close the app after a workout and not remember using it.
