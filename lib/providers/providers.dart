import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final matchesProvider =
    StreamProvider.autoDispose.family<List<TournamentMatch>, String>(
  (ref, id) => ref.watch(tournamentRepositoryProvider).watchMatches(id),
);
