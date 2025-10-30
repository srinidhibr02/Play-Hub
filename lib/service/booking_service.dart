import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:play_hub/constants/models.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all clubs
  Stream<List<Club>> getClubs({String? city, String? sport}) {
    Query query = _firestore.collection('clubs');

    if (city != null && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }

    if (sport != null && sport.isNotEmpty) {
      query = query.where('sports', arrayContains: sport);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList();
    });
  }

  // Get club by ID
  Future<Club?> getClubById(String clubId) async {
    try {
      final doc = await _firestore.collection('clubs').doc(clubId).get();
      if (doc.exists) {
        return Club.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting club: $e');
      return null;
    }
  }

  // Get courts for a club and sport
  Stream<List<Court>> getCourts(String clubId, String sport) {
    return _firestore
        .collection('courts')
        .where('clubId', isEqualTo: clubId)
        .where('sport', isEqualTo: sport)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Court.fromFirestore(doc)).toList();
        });
  }

  // Get available time slots for a court on a specific date
  Future<List<TimeSlot>> getAvailableSlots({
    required String clubId,
    required String courtId,
    required DateTime date,
    required double pricePerHour,
  }) async {
    try {
      // Generate time slots from 6 AM to 11 PM
      final slots = <TimeSlot>[];
      final startHour = 6;
      final endHour = 23;

      // Get existing bookings for this court on this date
      final dateStart = DateTime(date.year, date.month, date.day);
      final dateEnd = dateStart.add(const Duration(days: 1));

      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('courtId', isEqualTo: courtId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateStart))
          .where('date', isLessThan: Timestamp.fromDate(dateEnd))
          .where('status', whereIn: ['confirmed', 'pending'])
          .get();

      // Create a map of booked slots with who booked them
      final bookedSlots = <String, String>{};
      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final slotKey = '${data['startTime']}-${data['endTime']}';
        final bookedBy =
            data['bookedBy'] ??
            data['userId']; // Fallback to userId if bookedBy not present
        bookedSlots[slotKey] = bookedBy;
      }

      // Generate slots
      for (int hour = startHour; hour < endHour; hour++) {
        final startTime = _formatTime(hour);
        final endTime = _formatTime(hour + 1);
        final slotKey = '$startTime-$endTime';

        slots.add(
          TimeSlot(
            startTime: startTime,
            endTime: endTime,
            isAvailable: !bookedSlots.containsKey(slotKey),
            price: pricePerHour,
            bookedBy: bookedSlots[slotKey], // Add who booked this slot
          ),
        );
      }

      return slots;
    } catch (e) {
      print('Error getting available slots: $e');
      return [];
    }
  }

  // Create a booking
  Future<BookingResult> createBooking({
    required String userId,
    required String userEmailId,
    required String clubId,
    required String clubName,
    required String courtId,
    required String courtName,
    required String sport,
    required DateTime date,
    required String startTime,
    required String endTime,
    required double price,
    required Map<String, dynamic> userDetails,
  }) async {
    try {
      // Check if slot is still available
      final dateStart = DateTime(date.year, date.month, date.day);
      final dateEnd = dateStart.add(const Duration(days: 1));

      final existingBooking = await _firestore
          .collection('bookings')
          .where('courtId', isEqualTo: courtId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateStart))
          .where('date', isLessThan: Timestamp.fromDate(dateEnd))
          .where('startTime', isEqualTo: startTime)
          .where('endTime', isEqualTo: endTime)
          .where('status', whereIn: ['confirmed', 'pending'])
          .get();

      if (existingBooking.docs.isNotEmpty) {
        return BookingResult(
          success: false,
          message: 'This slot is no longer available',
        );
      }

      // Create booking
      final bookingData = {
        'userId': userId,
        'clubId': clubId,
        'clubName': clubName,
        'courtId': courtId,
        'courtName': courtName,
        'sport': sport,
        'date': Timestamp.fromDate(date),
        'startTime': startTime,
        'endTime': endTime,
        'price': price,
        'status': 'confirmed', // In real app, would be 'pending' until payment
        'createdAt': FieldValue.serverTimestamp(),
        'userDetails': userDetails,
        'bookedBy': userEmailId, // Add this field!
      };

      final docRef = await _firestore.collection('bookings').add(bookingData);

      return BookingResult(
        success: true,
        message: 'Booking confirmed successfully!',
        bookingId: docRef.id,
      );
    } catch (e) {
      print('Error creating booking: $e');
      return BookingResult(
        success: false,
        message: 'Failed to create booking. Please try again.',
      );
    }
  }

  // Get user's bookings
  Stream<List<Booking>> getUserBookings(String userId) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Booking.fromFirestore(doc))
              .toList();
        });
  }

  // Cancel booking
  Future<BookingResult> cancelBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      return BookingResult(
        success: true,
        message: 'Booking cancelled successfully',
      );
    } catch (e) {
      print('Error cancelling booking: $e');
      return BookingResult(success: false, message: 'Failed to cancel booking');
    }
  }

  // Helper method to format time
  String _formatTime(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }

  // Search clubs
  Future<List<Club>> searchClubs(String query) async {
    try {
      final snapshot = await _firestore
          .collection('clubs')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      return snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error searching clubs: $e');
      return [];
    }
  }

  // Get popular clubs
  Stream<List<Club>> getPopularClubs({int limit = 10}) {
    return _firestore
        .collection('clubs')
        .orderBy('rating', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList();
        });
  }
}

// Result classes
class BookingResult {
  final bool success;
  final String message;
  final String? bookingId;

  BookingResult({required this.success, required this.message, this.bookingId});
}
