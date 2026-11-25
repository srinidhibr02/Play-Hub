# Manual test checklist

Automated tests (`flutter test`) cover the logic and the Firestore code. This
list covers what only a person on a device can check: layout, animations,
permissions and real Firebase behaviour.

Use two accounts: **Organizer** (account 1, on the emulator) and **Team**
(account 2, on a second emulator, a phone, or after signing out). Run with
`flutter run --flavor dev --dart-define=FLAVOR=dev`.

## Setup
- [ ] Email/Password sign-in is enabled in the Firebase console.
- [ ] Firestore rules from `firestore.rules` are published (see its header).
- [ ] Sign up, sign out, sign in again. Google sign-in works if you use it.
- [ ] Splash, sign-in and Profile screens show the PlayHub logo.

## Friendly tournament (Organizer)
- [ ] Create a football friendly tournament: it is created in a few taps and
      opens straight away.
- [ ] Teams tab: Add one team with players, then Quick add three names. Rules
      reject duplicates.
- [ ] Fixtures tab: generate a league. Matches appear, Teams tab locks.
- [ ] Schedule a match (date, time, venue). It shows on the match tile.
- [ ] Score a match with goals, a scorer, an assist, a yellow card and a
      substitution. Raising events raises the score; a third yellow is refused.
- [ ] Set a lineup, then substitute a player who is not on the pitch: refused.
- [ ] Table tab shows points, GD and the leader highlighted. Overview shows
      stats and Player leaders.
- [ ] Reset fixtures: scores disappear, teams unlock.

## Hosted tournament (Organizer + Team)
- [ ] Organizer: create a hosted badminton tournament with capacity 4, an entry
      fee and a UPI ID. Overview shows an invite code. Share invite opens the
      share sheet.
- [ ] Team: Discover > Join, enter the code (try lower case and a space).
      Register a team. It appears under Mine.
- [ ] Team: Pay in UPI app opens a UPI app (or shows the fallback message).
      Tap "I have paid" with a reference.
- [ ] Organizer: Requests tab shows the registration with "Verify payment".
      Confirm payment, approve. The team appears in Teams.
- [ ] Register 4 teams total. The 5th cannot register ("full").
- [ ] Approve an unpaid team: a confirm prompt appears.
- [ ] Generate fixtures: registration closes, a pending request is warned about.
- [ ] Team: sees fixtures, can open a started match (read-only screen) but
      cannot score.
- [ ] Team withdraws a pending registration: it disappears for the organizer.

## Knockout
- [ ] Create a knockout with 5 teams (odd number, a bye). Bracket tab shows
      rounds, byes are hidden, later rounds say "To be decided".
- [ ] Score round 1: winners appear in the next round. Final shows the
      champion banner.
- [ ] Edit a round 1 result after the next match started: refused with a clear
      message.

## Cricket
- [ ] Create a cricket tournament (6 overs). Score a match with both innings.
- [ ] Add batters and bowlers. Totals that disagree with the scorecard are
      refused (for example bowlers taking more wickets than fell).
- [ ] Table shows net run rate. Overview shows most runs, wickets and sixes.
- [ ] Match detail (as the Team account) shows both scorecards.

## Badminton
- [ ] Score a best-of-3 match. An invalid game (for example 21-20) is refused.
- [ ] Doubles: add a team named "A / B" with two players. Overview "Most wins"
      credits both players.

## Edit and polish
- [ ] Edit details: change the name, venue and description; reopen to confirm.
- [ ] Rotate the phone and use a large font size (Settings > Display): nothing
      overflows, the table scrolls sideways.
- [ ] Dark mode looks right on every screen.
- [ ] Turn on airplane mode: lists still show cached data; writes show a
      friendly error or sync when back online.
- [ ] Sign out and back in: Mine shows the same tournaments.

Write down anything that looks wrong with the screen name and the steps; that
is enough for a fix.
