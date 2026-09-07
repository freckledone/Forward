# 00 — Constitution

Non-negotiable principles for **Forward** (working name).

This document changes only through an explicit, dated entry in `decision-log.md`. It is not modified silently.

---

## 1. Core purpose

The app exists to help one kind of person do one thing well:

> Log strength workouts and see progress on the lifts they care about, with as little friction as possible.

## 2. The one question

Every product decision is answered against this test:

> Does this help the user log their workout or understand their progress?

If the answer is no, the feature does not ship. It goes to the parking lot, or — if it violates a principle below — to the anti-product list.

## 3. Product values

- **Simplicity.** Every feature must justify its existence. If a feature adds power but also adds complexity, we question whether it belongs.
- **Low friction.** Logging a set requires as little interaction as reasonably possible. The user does not fight the interface while exercising.
- **Progress-focused.** The central purpose of the app is helping the user understand whether they are progressing on the lifts they care about.
- **Privacy.** No account. No advertising. No behavioral tracking. No unnecessary analytics. No cloud backend beyond iCloud sync of the user's own data.
- **Free forever.** No subscription. No upsells. No advertisements. No artificial feature restrictions. No Pro tier. No manipulative monetization.
- **Apple-first.** SwiftUI, SwiftData, CloudKit, HealthKit (only if it earns its place), Dynamic Type, SF Symbols, standard iOS interaction patterns. We do not reinvent Apple's UI unnecessarily.
- **Offline-first.** The app remains fully useful with no Wi-Fi, no cellular, airplane mode, or an iCloud outage. Local storage is primary; sync is secondary.
- **The app disappears while you work out.** During training, the interface fades into the background of the user's attention.

## 4. Anti-product

Things the app will never do. Not deferred — declined.

- **Gamification.** No streaks, no consistency scores, no badges, no confetti, no artificial achievements.
- **Engagement notifications.** No notifications designed to bring users back into the app.
- **Per-accessory PR notifications.** The "key lifts" concept exists so non-key lifts don't ping you. Notifying on every accessory PR undoes the concept.
- **Social features.** No feed, followers, likes, comments, leaderboards, public profiles, workout-sharing surface.
- **Monetization surfaces.** No subscriptions, no in-app purchases, no upsell prompts, no advertising, no third-party analytics.
- **Behavioral tracking of any kind.** No pixel, no SDK, no funnel instrumentation.
- **Required accounts or logins.** The app has no user account layer.
- **AI coach behavior.** The SuggestionEngine is a data lookup, not a coach. It never nudges you to train, deload, or "trust the process."
- **Custom UI that fights iOS.** No custom navigation, exotic gradients, glass effects, or floating dashboards that ignore system conventions unless there is an overwhelming reason.

## 5. Audience

V1 is designed for one user: the author. The audience is one.

The question "will other users want X" is not asked in V1. It is replaced by "does the author want X." If the app is later opened to a wider audience or open-sourced, the audience assumption may relax — but until then, this discipline is what protects scope.

## 6. Working process

- Design → define → challenge → document → break into small tasks → implement → test → review → refine.
- No silent architectural invention. If a decision hasn't been made, ask.
- If implementation reveals a problem with the specification, stop and surface it.
- Maintain `decision-log.md`. Do not re-litigate settled questions.
- Maintain a parking lot. Do not let out-of-scope ideas derail the current milestone.
- Every important architectural choice is documented with: what, why, alternatives, why not, impact.

## 7. Success

The app is successful when:

- The author uses it as their primary workout log without exceptions.
- Opening the app, starting a workout, and logging the first set takes seconds and requires no thought.
- The Progress screen answers "am I getting stronger?" at a glance for the lifts the user cares about.
- The app has never nudged, prompted, or manipulated the user into engagement.
- The app has zero paywalls, zero ads, zero third-party trackers, and zero required accounts.

Success is not measured in DAU, retention, session length, or any other engagement metric. Those metrics reward the wrong things.
