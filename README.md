# Play Hub: Sports Event & Tournament Manager

Host and track local **badminton**, **cricket** and **football** tournaments
from your phone. Create a tournament, add teams, draw fixtures, and (soon)
score matches live with standings that update automatically.

## Status

This is a ground-up rewrite of the previous Play Hub (club booking) app, on
the branch `feature/tournament-manager-reset`. It is being built in phases.

| Phase | Scope | State |
|-------|-------|-------|
| 1 | Foundation: auth, theme, models, create tournament, teams, fixture generation (league + knockout) | Done |
| 2 | Manual scoring: football goals, cricket runs/wickets/overs, badminton games; match status | Next |
| 3 | Standings tables (points, goal difference, net run rate), knockout bracket view, auto-advance winners | Planned |
| 4 | Scheduling (date, time, venue per match), edit tournament, share link / code | Planned |
| 5 | Player stats, top scorers, polish, offline behaviour, store release | Planned |

## Architecture

```
lib/
  core/        theme, shared animated widgets, helpers
  models/      Sport, Tournament, Team, TournamentMatch, MatchScore
  logic/       pure Dart (no Firebase): FixtureGenerator
  services/    AuthService, TournamentRepository (all Firestore access)
  providers/   Riverpod providers (streams for live updates)
  features/    auth, home, tournament/create, tournament/detail
```

Firestore layout (new root collection, so old data is untouched):

```
sportsTournaments/{id}            tournament + rules + counters
  teams/{teamId}                  name, colour, players, seed
  matches/{matchId}               round, teams, status, score, next-match link
```

Knockout matches store `nextMatchId` and `nextSlot`, so entering a result can
move the winner into the next round without re-computing the bracket.

## Firebase

Uses the existing project `play-hub02` (`lib/firebase_options.dart`, the
`google-services.json` per flavor, and `GoogleService-Info.plist` are
unchanged).

**Before the app can read or write data you must deploy the rules:**

```
firebase deploy --only firestore:rules
```

Rules live in `firestore.rules`: public tournaments are readable by anyone,
everything is writable only by the owner.

Sign-in methods used: Email/Password and Google. Make sure Email/Password is
enabled in the Firebase console (Authentication > Sign-in method).

## Running

```
flutter pub get
flutter test
flutter run --dart-define=FLAVOR=dev
```

Android has two flavors (`dev`, `prod`); pass `--flavor dev` on Android.
