// Club Model
import 'package:cloud_firestore/cloud_firestore.dart';

class Club {
  final String id;
  final String name;
  final String address;
  final String city;
  final double rating;
  final List<String> amenities;
  final List<String> sports;
  final String imageUrl;
  final Map<String, double> pricing; // sport: price per hour
  final String phone;
  final double latitude;
  final double longitude;

  Club({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.rating,
    required this.amenities,
    required this.sports,
    required this.imageUrl,
    required this.pricing,
    required this.phone,
    required this.latitude,
    required this.longitude,
  });

  factory Club.fromMap(Map<String, dynamic> map, String id) {
    return Club(
      id: id,
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      amenities: List<String>.from(map['amenities'] ?? []),
      sports: List<String>.from(map['sports'] ?? []),
      imageUrl: map['imageUrl'] ?? '',
      pricing: Map<String, double>.from(map['pricing'] ?? {}),
      phone: map['phone'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'rating': rating,
      'amenities': amenities,
      'sports': sports,
      'imageUrl': imageUrl,
      'pricing': pricing,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

// Court Model
class Court {
  final String id;
  final String clubId;
  final String name;
  final String sport;
  final bool isAvailable;
  final String surface; // e.g., "Wooden", "Synthetic", "Grass"

  Court({
    required this.id,
    required this.clubId,
    required this.name,
    required this.sport,
    required this.isAvailable,
    required this.surface,
  });

  factory Court.fromMap(Map<String, dynamic> map, String id) {
    return Court(
      id: id,
      clubId: map['clubId'] ?? '',
      name: map['name'] ?? '',
      sport: map['sport'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      surface: map['surface'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clubId': clubId,
      'name': name,
      'sport': sport,
      'isAvailable': isAvailable,
      'surface': surface,
    };
  }
}

// Time Slot Model
class TimeSlot {
  final String startTime;
  final String endTime;
  final bool isBooked;
  final String? bookedBy;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
    this.bookedBy,
  });

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      isBooked: map['isBooked'] ?? false,
      bookedBy: map['bookedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'isBooked': isBooked,
      'bookedBy': bookedBy,
    };
  }
}

// Booking Model
class Booking {
  final String id;
  final String userId;
  final String clubId;
  final String courtId;
  final String sport;
  final DateTime date;
  final String timeSlot;
  final double price;
  final String status; // pending, confirmed, cancelled, completed
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.userId,
    required this.clubId,
    required this.courtId,
    required this.sport,
    required this.date,
    required this.timeSlot,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  factory Booking.fromMap(Map<String, dynamic> map, String id) {
    return Booking(
      id: id,
      userId: map['userId'] ?? '',
      clubId: map['clubId'] ?? '',
      courtId: map['courtId'] ?? '',
      sport: map['sport'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      timeSlot: map['timeSlot'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'clubId': clubId,
      'courtId': courtId,
      'sport': sport,
      'date': Timestamp.fromDate(date),
      'timeSlot': timeSlot,
      'price': price,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
