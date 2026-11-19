import 'package:firebase_core/firebase_core.dart';

import 'package:play_hub/services/tournament_repository.dart';

/// Turns an error from the repository into a sentence a person can act on.
String describeError(Object error) {
  if (error is ResultException) return error.message;

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to do that. If you are the '
            'organizer, check that the latest Firestore rules are deployed.';
      case 'unavailable':
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      case 'not-found':
        return 'That no longer exists. It may have been deleted.';
    }
  }
  return 'Something went wrong. Please try again.';
}
