import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:play_hub/constants/models.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all clubs
  Stream<List<Club>> getClubs() {
    return _firestore
        .collection('clubs')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Club.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Get clubs by sport
  Stream<List<Club>> getClubsBySport(String sport) {
    return _firestore
        .collection('clubs')
        .where('sports', arrayContains: sport)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Club.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Get courts for a club and sport
  Stream<List<Court>> getCourts(String clubId, String sport) {
    return _firestore
        .collection('clubs')
        .doc(clubId)
        .collection(sport) // sport-named subcollection holds courts
        .snapshots()
        .map(
          (querySnapshot) => querySnapshot.docs
              .map((doc) => Court.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Get available time slots for a court on a specific date
  // Updated getAvailableSlots with sport parameter
  Future<List<TimeSlot>> getAvailableSlots({
    required String clubId,
    required String sport,
    required String courtId,
    required DateTime date,
  }) async {
    final bookings = await _firestore
        .collection('bookings')
        .where('clubId', isEqualTo: clubId)
        .where('sport', isEqualTo: sport)
        .where('courtId', isEqualTo: courtId)
        .where(
          'date',
          isEqualTo: Timestamp.fromDate(
            DateTime(date.year, date.month, date.day),
          ),
        )
        .where('status', whereIn: ['pending', 'confirmed'])
        .get();

    final bookedSlots = bookings.docs
        .map((doc) => doc.data()['timeSlot'] as String)
        .toSet();

    final slots = <TimeSlot>[];
    for (int hour = 6; hour < 23; hour++) {
      final start = '${hour.toString().padLeft(2, '0')}:00';
      final end = '${(hour + 1).toString().padLeft(2, '0')}:00';
      final slotKey = '$start-$end';

      slots.add(
        TimeSlot(
          startTime: start,
          endTime: end,
          isBooked: bookedSlots.contains(slotKey),
        ),
      );
    }
    return slots;
  }

  // Create a booking
  Future<String?> createBooking({
    required String userId,
    required String clubId,
    required String sport,
    required String courtId,
    required DateTime date,
    required String timeSlot,
    required double price,
  }) async {
    try {
      final existingBookings = await _firestore
          .collection('bookings')
          .where('clubId', isEqualTo: clubId)
          .where('sport', isEqualTo: sport)
          .where('courtId', isEqualTo: courtId)
          .where(
            'date',
            isEqualTo: Timestamp.fromDate(
              DateTime(date.year, date.month, date.day),
            ),
          )
          .where('timeSlot', isEqualTo: timeSlot)
          .where('status', whereIn: ['pending', 'confirmed'])
          .get();

      if (existingBookings.docs.isNotEmpty) {
        return null; // Slot already booked
      }

      final docRef = await _firestore.collection('bookings').add({
        'userId': userId,
        'clubId': clubId,
        'sport': sport,
        'courtId': courtId,
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'timeSlot': timeSlot,
        'price': price,
        'status': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      print('Error creating booking: $e');
      return null;
    }
  }

  // Get user bookings
  Stream<List<Booking>> getUserBookings(String userId) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Booking.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Cancel booking
  Future<bool> cancelBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
      });
      return true;
    } catch (e) {
      print('Error cancelling booking: $e');
      return false;
    }
  }

  // Get club details
  Future<Club?> getClubDetails(String clubId) async {
    try {
      final doc = await _firestore.collection('clubs').doc(clubId).get();
      if (doc.exists) {
        return Club.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting club details: $e');
      return null;
    }
  }

  // Get court details (now requires clubId + sport + courtId, so adjust as needed)
  Future<Court?> getCourtDetails(
    String clubId,
    String sport,
    String courtId,
  ) async {
    try {
      final courtDoc = await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection(sport)
          .doc(courtId)
          .get();
      if (courtDoc.exists) {
        return Court.fromMap(courtDoc.data()!, courtDoc.id);
      }
      return null;
    } catch (e) {
      print('Error getting court details: $e');
      return null;
    }
  }
}
