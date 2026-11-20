# Play Hub: Sports Event & Tournament Manager

Host and track local **badminton**, **cricket** and **football** tournaments
from your phone. Run a **friendly** tournament in seconds, or **host** one with invite codes,
team registration, organizer approval and entry-fee tracking. Then draw
fixtures and score matches.

## Two kinds of tournament

| | Friendly | Hosted |
|---|---|---|
| Created | Instantly (name, sport, format) | Same, plus registration settings |
| Teams | Organizer adds them directly (Quick add takes a pasted list) | Teams register with an invite code; the organizer approves; walk-ins can still be added |
| Entry fee | None | Optional, with payment tracking |
| Discover list | Optional | Optional (invite code works either way) |

**Registration flow (hosted):** organizer shares the invite code, a team opens
*Join* and enters it, fills in team details, and the request shows up under
*Requests*. Approving creates the team (capacity is checked in a transaction).
Registration closes when fixtures are drawn, the deadline passes, or the
tournament is full.

**Payments (manual for now):** the app never moves money. The organizer sets a
fee, a UPI ID and/or cash. Teams pay outside the app, tap *I have paid*
(optionally adding the UTR reference), and the organizer marks it *paid*. An
unpaid team can still be approved after a confirm prompt. An online gateway
(for example Razorpay) needs a backend to verify payments and is on the
roadmap.

## Status

Rewrite of the previous Play Hub (club booking) app on branch
`feature/tournament-manager-reset`, built in phases.

| Phase | Scope | State |
|-------|-------|-------|
| 1 | Auth, theme, models, create tournament, teams, fixtures (league + knockout) | Done |
| 2 | Manual scoring for football, cricket and badminton; knockout advancement | Done |
| 2.5 | Friendly vs hosted, invite codes, registrations, approval, manual payment tracking, logo restored | Done, **not yet compiled or run** |
| 3 | Standings table (points, goal difference, net run rate, game/point difference) and knockout bracket with champion banner | Done, **not yet compiled or run** |
| 4 | Match scheduling (date, time, venue), edit tournament details, share sheet for invites, open UPI app to pay | Done, **not yet compiled or run** |
| 5 | Tournament stats on the overview (totals, averages, biggest win, highest score) | Done, **not yet compiled or run** |
| 6a | Football match events (scorers, assists, penalties, own goals, cards) and player leaders (top scorers, assists, discipline) | Done, **not yet compiled or run** |
| 6b | Cricket scorecards (batters and bowlers per innings), run, wicket and six leaders, read-only match detail screen for everyone | Done, **not yet compiled or run** |
| 7 | Release prep, online payments (needs a backend) | Planned |

## Architecture

```
lib/
  core/        theme, shared animated widgets, helpers
  models/      Sport, Tournament, Team, Registration, TournamentMatch
  logic/       pure Dart: FixtureGenerator, MatchRules, MatchEvents, PlayerStats, Scorecard, Standings, TournamentStats, InviteCode, Payments
  services/    AuthService, TournamentRepository (all Firestore access)
  providers/   Riverpod providers (streams for live updates)
  features/    auth, home, tournament/{create,detail,registration,score}
```

Firestore layout (new root collections, so old data is untouched):

```
sportsTournaments/{id}                 tournament, rules, fee, counters
  teams/{teamId}                       name, colour, players, seed
  matches/{matchId}                    round, teams, status, score, next-match link
  registrations/{uid}                  pending/approved/rejected + payment status
sportsInviteCodes/{CODE}               code -> tournament id lookup
sportsUsers/{uid}/joined/{id}          tournaments a person registered for
```

## Firebase

Uses the existing project `play-hub02`; the Firebase config files are unchanged.

**Rules warning:** Firebase keeps one ruleset per project, and deploying
replaces it. `firestore.rules` holds only the new `sports*` blocks. If the old
app is still live on this project, paste those blocks into your existing rules
in the console instead of deploying the file. `firebase.json` does not
reference the file, so a plain `firebase deploy` will not touch your rules. If
the project is only used by this app, deploy it with a config that points to
the file, or paste it into the console.

Sign-in: Email/Password and Google. Enable Email/Password in the console
(Authentication > Sign-in method).

## Running

```
flutter pub get
flutter test
flutter run --flavor dev --dart-define=FLAVOR=dev
```

Android needs `--flavor dev` (or `prod`).
