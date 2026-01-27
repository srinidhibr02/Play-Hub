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

  ({int? startHour, int? endHour}) parseOpeningHours(
    dynamic openingHoursData,
    DateTime date,
  ) {
    try {
      if (openingHoursData is Map) {
        final dayName = _getDayName(date.weekday);
        final dayHours = openingHoursData[dayName];

        if (dayHours is String) {
          // Parse "6:00 AM - 11:00 PM" with full AM/PM support
          final timeMatch = RegExp(
            r'(\d{1,2}):(\d{2})\s*([AP]M)\s*-\s*(\d{1,2}):(\d{2})\s*([AP]M)',
          );
          final match = timeMatch.firstMatch(dayHours.trim());

          if (match != null) {
            // Parse START time with AM/PM
            int startHour = int.parse(match.group(1)!);
            final startPeriod = match.group(3)!.toUpperCase();

            // Convert 12h AM/PM → 24h
            if (startPeriod == 'PM' && startHour != 12) startHour += 12;
            if (startPeriod == 'AM' && startHour == 12) startHour = 0;

            // Parse END time with AM/PM
            int endHour = int.parse(match.group(4)!);
            final endPeriod = match.group(6)!.toUpperCase();

            // Convert 12h AM/PM → 24h
            if (endPeriod == 'PM' && endHour != 12) endHour += 12;
            if (endPeriod == 'AM' && endHour == 12) endHour = 0;

            return (startHour: startHour, endHour: endHour);
          }
        }
      }

      // Fallback for simple string format
      if (openingHoursData is String) {
        final startMatch = RegExp(r'^(\d{1,2}):').firstMatch(openingHoursData);
        final endMatch = RegExp(r'- (\d{1,2}):').firstMatch(openingHoursData);
        return (
          startHour: int.tryParse(startMatch?.group(1) ?? ''),
          endHour: int.tryParse(endMatch?.group(1) ?? ''),
        );
      }

      return (startHour: 6, endHour: 23);
    } catch (e) {
      return (startHour: 6, endHour: 23);
    }
  }

  String _getDayName(int weekday) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday];
  }

  Future<List<TimeSlot>> getAvailableSlots({
    required String clubId,
    required String courtId,
    required DateTime date,
    required double pricePerHour,
  }) async {
    try {
      final slots = <TimeSlot>[];
      final now = DateTime.now();

      final dateStart = DateTime(date.year, date.month, date.day);
      final dateEnd = dateStart.add(const Duration(days: 1));

      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('courtId', isEqualTo: courtId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateStart))
          .where('date', isLessThan: Timestamp.fromDate(dateEnd))
          .where('status', whereIn: ['confirmed', 'pending'])
          .get();

      final clubSnapshot = await _firestore
          .collection('clubs')
          .doc(clubId)
          .get();
      final clubData = clubSnapshot.data() ?? {};
      final openingHours = clubData['openingHours'];

      final hours = parseOpeningHours(openingHours, date);
      final startHour = hours.startHour ?? 6;
      final endHour = hours.endHour ?? 23;

      final bookedSlots = <String, String>{};
      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final slotKey = '${data['startTime']}-${data['endTime']}';
        final bookedBy = data['bookedBy'] ?? data['userId'];
        bookedSlots[slotKey] = bookedBy;
      }

      // Generate slots within opening hours
      for (int hour = startHour; hour < endHour; hour++) {
        final startTime = _formatTime(hour);
        final endTime = _formatTime(hour + 1);
        final slotKey = '$startTime-$endTime';

        // ✅ NEW: Check if slot is elapsed
        final slotDateTime = _getSlotDateTime(startTime, date);
        final isElapsed = slotDateTime.isBefore(now);

        // Skip if slot time has already passed
        if (isElapsed) {
          continue;
        }

        slots.add(
          TimeSlot(
            startTime: startTime,
            endTime: endTime,
            isAvailable: !bookedSlots.containsKey(slotKey),
            price: pricePerHour,
            bookedBy: bookedSlots[slotKey],
          ),
        );
      }

      return slots;
    } catch (e) {
      return [];
    }
  }

  // ✅ NEW: Helper to convert time string to DateTime for comparison
  DateTime _getSlotDateTime(String timeString, DateTime date) {
    // Parse time string like "10:00" or "12:00 PM"
    String cleanTime = timeString.trim();
    bool isPM = cleanTime.toUpperCase().contains('PM');
    bool isAM = cleanTime.toUpperCase().contains('AM');

    cleanTime = cleanTime
        .replaceAll(RegExp(r'[AP]M', caseSensitive: false), '')
        .trim();

    final parts = cleanTime.split(':');
    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    // Convert to 24-hour format
    if (isPM && hour != 12) {
      hour += 12;
    } else if (isAM && hour == 12) {
      hour = 0;
    }

    return DateTime(date.year, date.month, date.day, hour, minute);
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
    required String paymentMethod,
    required String paymentId,
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
        .where('bookedBy', isEqualTo: userId)
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
