import 'package:cloud_firestore/cloud_firestore.dart';

// Club Model
import 'package:cloud_firestore/cloud_firestore.dart';

class Club {
  final String id;
  final String name;
  final String address;
  final String city;
  final String imageUrl;
  final List<String> sports; // Available sports
  final Map<String, double> pricePerHour; // Sport -> Price
  final double rating;
  final int totalRatings;
  final String phoneNumber;
  final Map<String, dynamic> amenities;
  final GeoPoint location;
  final List<String> images;
  final Map<String, String> openingHours; // Day -> Hours
  final bool allowBookings; // NEW: Booking status

  Club({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.imageUrl,
    required this.sports,
    required this.pricePerHour,
    required this.rating,
    required this.totalRatings,
    required this.phoneNumber,
    required this.amenities,
    required this.location,
    required this.images,
    required this.openingHours,
    this.allowBookings = true, // Default to true
  });

  factory Club.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Club(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      sports: List<String>.from(data['sports'] ?? []),
      pricePerHour: Map<String, double>.from(
        (data['pricePerHour'] ?? {}).map(
          (key, value) => MapEntry(key, value.toDouble()),
        ),
      ),
      rating: (data['rating'] ?? 0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      phoneNumber: data['phoneNumber'] ?? '',
      amenities: data['amenities'] ?? {},
      location: data['location'] ?? const GeoPoint(0, 0),
      images: List<String>.from(data['images'] ?? []),
      openingHours: Map<String, String>.from(data['openingHours'] ?? {}),
      allowBookings: data['allowBookings'] ?? true, // NEW: Default to true
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'imageUrl': imageUrl,
      'sports': sports,
      'pricePerHour': pricePerHour,
      'rating': rating,
      'totalRatings': totalRatings,
      'phoneNumber': phoneNumber,
      'amenities': amenities,
      'location': location,
      'images': images,
      'openingHours': openingHours,
      'allowBookings': allowBookings, // NEW: Include in map
    };
  }
}

// Court Model
class Court {
  final String id;
  final String clubId;
  final String name;
  final String sport;
  final String type; // Indoor/Outdoor
  final int capacity;
  final bool isActive;

  Court({
    required this.id,
    required this.clubId,
    required this.name,
    required this.sport,
    required this.type,
    required this.capacity,
    required this.isActive,
  });

  factory Court.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Court(
      id: doc.id,
      clubId: data['clubId'] ?? '',
      name: data['name'] ?? '',
      sport: data['sport'] ?? '',
      type: data['type'] ?? '',
      capacity: data['capacity'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clubId': clubId,
      'name': name,
      'sport': sport,
      'type': type,
      'capacity': capacity,
      'isActive': isActive,
    };
  }
}

// TimeSlot Model
class TimeSlot {
  final String startTime;
  final String endTime;
  final bool isAvailable;
  final double price;
  final String? bookedBy; // Add this field to track who booked the slot

  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    required this.price,
    this.bookedBy,
  });

  String get displayTime => '$startTime - $endTime';
  bool get isBooked => !isAvailable;
}

// Booking Model
class Booking {
  final String id;
  final String userId;
  final String clubId;
  final String clubName;
  final String courtId;
  final String courtName;
  final String sport;
  final DateTime date;
  final String startTime;
  final String endTime;
  final double price;
  final String status; // pending, confirmed, cancelled, completed
  final DateTime createdAt;
  final String? paymentId;
  final Map<String, dynamic>? userDetails;

  Booking({
    required this.id,
    required this.userId,
    required this.clubId,
    required this.clubName,
    required this.courtId,
    required this.courtName,
    required this.sport,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.status,
    required this.createdAt,
    this.paymentId,
    this.userDetails,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      userId: data['userId'] ?? '',
      clubId: data['clubId'] ?? '',
      clubName: data['clubName'] ?? '',
      courtId: data['courtId'] ?? '',
      courtName: data['courtName'] ?? '',
      sport: data['sport'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      paymentId: data['paymentId'],
      userDetails: data['userDetails'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'paymentId': paymentId,
      'userDetails': userDetails,
    };
  }

  String get displayDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDate = DateTime(date.year, date.month, date.day);

    if (bookingDate == today) {
      return 'Today';
    } else if (bookingDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  String get displayTime => '$startTime - $endTime';

  bool get isPast => date.isBefore(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get isUpcoming => date.isAfter(DateTime.now());
}
