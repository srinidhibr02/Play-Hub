import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/models/registration.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';
import 'package:play_hub/services/auth_service.dart';
import 'package:play_hub/services/tournament_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

final tournamentRepositoryProvider = Provider<TournamentRepository>(
  (ref) => TournamentRepository(),
);

/// Sport filter shared by the home tabs. Null means "all sports".
final sportFilterProvider = StateProvider<Sport?>((ref) => null);

final myTournamentsProvider = StreamProvider.autoDispose<List<Tournament>>((
  ref,
) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const <Tournament>[]);
  return ref.watch(tournamentRepositoryProvider).watchMyTournaments(user.uid);
});

final publicTournamentsProvider = StreamProvider.autoDispose<List<Tournament>>(
  (ref) => ref.watch(tournamentRepositoryProvider).watchPublicTournaments(),
);

final tournamentProvider = StreamProvider.autoDispose.family<Tournament?, String>(
  (ref, id) => ref.watch(tournamentRepositoryProvider).watchTournament(id),
);

final teamsProvider = StreamProvider.autoDispose.family<List<Team>, String>(
  (ref, id) => ref.watch(tournamentRepositoryProvider).watchTeams(id),
);

/// Every registration for a tournament. Only the organizer may read these,
/// so watch it only when the signed-in user owns the tournament.
final registrationsProvider =
    StreamProvider.autoDispose.family<List<Registration>, String>(
  (ref, id) => ref.watch(tournamentRepositoryProvider).watchRegistrations(id),
);

/// The signed-in user's own registration for a tournament.
final myRegistrationProvider =
    StreamProvider.autoDispose.family<Registration?, String>((ref, id) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref
      .watch(tournamentRepositoryProvider)
      .watchMyRegistration(id, user.uid);
});

/// Ids of tournaments the signed-in user registered for.
final joinedIdsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const <String>[]);
  return ref.watch(tournamentRepositoryProvider).watchJoinedIds(user.uid);
});

/// Tournaments the signed-in user registered for, loaded one by one (a
/// tournament that has since been deleted is skipped).
final joinedTournamentsProvider =
    Provider.autoDispose<AsyncValue<List<Tournament>>>((ref) {
  final ids = ref.watch(joinedIdsProvider);
  return ids.when(
    loading: () => const AsyncValue<List<Tournament>>.loading(),
    error: (error, stack) => AsyncValue<List<Tournament>>.error(error, stack),
    data: (list) {
      final tournaments = <Tournament>[];
      for (final id in list) {
        final item = ref.watch(tournamentProvider(id));
        // Wait until every tournament has loaded so the list does not flash
        // an empty state while they arrive.
        if (item.isLoading && !item.hasValue) {
          return const AsyncValue<List<Tournament>>.loading();
        }
        final tournament = item.valueOrNull;
        if (tournament != null) tournaments.add(tournament);
      }
      return AsyncValue<List<Tournament>>.data(tournaments);
    },
  );
});

final matchesProvider =
    StreamProvider.autoDispose.family<List<TournamentMatch>, String>(
  (ref, id) => ref.watch(tournamentRepositoryProvider).watchMatches(id),
);
