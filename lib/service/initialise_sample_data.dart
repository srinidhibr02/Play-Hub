import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> initializeSampleData() async {
  final firestore = FirebaseFirestore.instance;

  print('Starting to add sample data...');

  // Sample Clubs with complete data
  final clubs = [
    {
      'name': 'Rachana Sports Club',
      'address': 'HP Circle, Beside Gandhi Maidhan, Harihar',
      'city': 'Davanagere',
      'imageUrl':
          'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=800',
      'sports': ['Badminton', 'Table Tennis'],
      'pricePerHour': {'Badminton': 200.0, 'Table Tennis': 150.0},
      'rating': 4.5,
      'totalRatings': 124,
      'phoneNumber': '+91 9876543210',
      'amenities': {
        'parking': true,
        'changingRoom': true,
        'cafeteria': false,
        'firstAid': true,
        'wifi': true,
      },
      'location': GeoPoint(14.515739, 75.808205),
      'images': [
        'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=800',
        'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=800',
      ],
      'openingHours': {
        'Monday': '6:00 AM - 11:00 PM',
        'Tuesday': '6:00 AM - 11:00 PM',
        'Wednesday': '6:00 AM - 11:00 PM',
        'Thursday': '6:00 AM - 11:00 PM',
        'Friday': '6:00 AM - 11:00 PM',
        'Saturday': '6:00 AM - 11:00 PM',
        'Sunday': '6:00 AM - 11:00 PM',
      },
    },
    {
      'name': 'CFC Sports Complex',
      'address': 'Vidhya Nagar, CFC, Harihar',
      'city': 'Davanagere',
      'imageUrl':
          'https://images.unsplash.com/photo-1552667466-07770ae110d0?w=800',
      'sports': ['Badminton', 'Tennis', 'Basketball'],
      'pricePerHour': {
        'Badminton': 250.0,
        'Tennis': 300.0,
        'Basketball': 350.0,
      },
      'rating': 4.3,
      'totalRatings': 89,
      'phoneNumber': '+91 9876543211',
      'amenities': {
        'parking': true,
        'changingRoom': true,
        'cafeteria': true,
        'firstAid': true,
        'wifi': true,
      },
      'location': GeoPoint(14.500333, 75.807361),
      'images': [
        'https://images.unsplash.com/photo-1552667466-07770ae110d0?w=800',
        'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=800',
      ],
      'openingHours': {
        'Monday': '6:00 AM - 10:00 PM',
        'Tuesday': '6:00 AM - 10:00 PM',
        'Wednesday': '6:00 AM - 10:00 PM',
        'Thursday': '6:00 AM - 10:00 PM',
        'Friday': '6:00 AM - 10:00 PM',
        'Saturday': '7:00 AM - 11:00 PM',
        'Sunday': '7:00 AM - 11:00 PM',
      },
    },
    {
      'name': 'Mask Turf Play Arena',
      'address': 'Near NH4 Shivamogga Road, Harihar',
      'city': 'Davanagere',
      'imageUrl':
          'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800',
      'sports': ['Football', 'Cricket'],
      'pricePerHour': {'Football': 500.0, 'Cricket': 400.0},
      'rating': 4.7,
      'totalRatings': 156,
      'phoneNumber': '+91 9876543212',
      'amenities': {
        'parking': true,
        'changingRoom': true,
        'cafeteria': true,
        'firstAid': true,
        'wifi': false,
      },
      'location': GeoPoint(14.489080, 75.804803),
      'images': [
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800',
        'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?w=800',
      ],
      'openingHours': {
        'Monday': '5:00 AM - 10:00 PM',
        'Tuesday': '5:00 AM - 10:00 PM',
        'Wednesday': '5:00 AM - 10:00 PM',
        'Thursday': '5:00 AM - 10:00 PM',
        'Friday': '5:00 AM - 10:00 PM',
        'Saturday': '5:00 AM - 11:00 PM',
        'Sunday': '5:00 AM - 11:00 PM',
      },
    },
    {
      'name': 'Elite Sports Hub',
      'address': 'MG Road, City Center, Chennai',
      'city': 'Chennai',
      'imageUrl':
          'https://images.unsplash.com/photo-1519505907962-0a6cb0167c73?w=800',
      'sports': ['Badminton', 'Squash', 'Table Tennis'],
      'pricePerHour': {
        'Badminton': 300.0,
        'Squash': 350.0,
        'Table Tennis': 200.0,
      },
      'rating': 4.8,
      'totalRatings': 234,
      'phoneNumber': '+91 9876543213',
      'amenities': {
        'parking': true,
        'changingRoom': true,
        'cafeteria': true,
        'firstAid': true,
        'wifi': true,
      },
      'location': GeoPoint(13.0827, 80.2707),
      'images': [
        'https://images.unsplash.com/photo-1519505907962-0a6cb0167c73?w=800',
        'https://images.unsplash.com/photo-1622163642998-1ea32b0bbc67?w=800',
      ],
      'openingHours': {
        'Monday': '6:00 AM - 11:00 PM',
        'Tuesday': '6:00 AM - 11:00 PM',
        'Wednesday': '6:00 AM - 11:00 PM',
        'Thursday': '6:00 AM - 11:00 PM',
        'Friday': '6:00 AM - 11:00 PM',
        'Saturday': '6:00 AM - 12:00 AM',
        'Sunday': '6:00 AM - 12:00 AM',
      },
    },
  ];

  // Add clubs and their courts
  for (var clubData in clubs) {
    try {
      // Add the club document
      final clubRef = await firestore.collection('clubs').add(clubData);
      print('Added club: ${clubData['name']}');

      final sports = clubData['sports'] as List;

      // Add courts for each sport
      for (final sport in sports) {
        final sportStr = sport.toString();

        // Define courts based on sport type
        List<Map<String, dynamic>> courtsToAdd = [];

        if (sportStr.toLowerCase() == 'badminton') {
          courtsToAdd = [
            {
              'clubId': clubRef.id,
              'name': 'Court 1',
              'sport': 'Badminton',
              'type': 'Indoor',
              'capacity': 4,
              'isActive': true,
            },
            {
              'clubId': clubRef.id,
              'name': 'Court 2',
              'sport': 'Badminton',
              'type': 'Indoor',
              'capacity': 4,
              'isActive': true,
            },
            {
              'clubId': clubRef.id,
              'name': 'Court 3',
              'sport': 'Badminton',
              'type': 'Indoor',
              'capacity': 4,
              'isActive': true,
            },
          ];
        } else if (sportStr.toLowerCase() == 'tennis') {
          courtsToAdd = [
            {
              'clubId': clubRef.id,
              'name': 'Court 1',
              'sport': 'Tennis',
              'type': 'Outdoor',
              'capacity': 4,
              'isActive': true,
            },
            {
              'clubId': clubRef.id,
              'name': 'Court 2',
              'sport': 'Tennis',
              'type': 'Outdoor',
              'capacity': 4,
              'isActive': true,
            },
          ];
        } else if (sportStr.toLowerCase() == 'cricket') {
          courtsToAdd = [
            {
              'clubId': clubRef.id,
              'name': 'Ground 1',
              'sport': 'Cricket',
              'type': 'Outdoor',
              'capacity': 22,
              'isActive': true,
            },
          ];
        } else if (sportStr.toLowerCase() == 'football') {
          courtsToAdd = [
            {
              'clubId': clubRef.id,
              'name': 'Turf 1',
              'sport': 'Football',
              'type': 'Outdoor',
              'capacity': 22,
              'isActive': true,
            },
          ];
        } else if (sportStr.toLowerCase() == 'basketball') {
          courtsToAdd = [
            {
              'clubId': clubRef.id,
              'name': 'Court 1',
              'sport': 'Basketball',
              'type': 'Indoor',
              'capacity': 10,
              'isActive': true,
            },
          ];
        } else if (sportStr.toLowerCase() == 'table tennis') {
          courtsToAdd = [
            {
              'clubId': clubRef.id,
              'name': 'Table 1',
              'sport': 'Table Tennis',
              'type': 'Indoor',
              'capacity': 2,
              'isActive': true,
            },
            {
              'clubId': clubRef.id,
              'name': 'Table 2',
              'sport': 'Table Tennis',
              'type': 'Indoor',
              'capacity': 2,
              'isActive': true,
            },
          ];
        } else if (sportStr.toLowerCase() == 'squash') {
          courtsToAdd = [
            {
              'clubId': clubRef.id,
              'name': 'Court 1',
              'sport': 'Squash',
              'type': 'Indoor',
              'capacity': 2,
              'isActive': true,
            },
          ];
        }

        // Add all courts for this sport
        for (var court in courtsToAdd) {
          await firestore.collection('courts').add(court);
          print('  Added ${court['sport']} - ${court['name']}');
        }
      }

      print('Completed: ${clubData['name']}\n');
    } catch (e) {
      print('Error adding club ${clubData['name']}: $e');
    }
  }

  // Add sample tournaments (optional)
  await _addSampleTournaments(firestore);

  print('✅ Successfully added all sample data to Firebase!');
}

Future<void> _addSampleTournaments(FirebaseFirestore firestore) async {
  print('\nAdding sample tournaments...');

  final tournaments = [
    {
      'name': 'City Badminton Championship 2024',
      'sport': 'Badminton',
      'description':
          'Annual city-level badminton championship open to all age groups',
      'date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 15))),
      'registrationDeadline': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 10)),
      ),
      'location': 'Rachana Sports Club, Davanagere',
      'maxParticipants': 32,
      'currentParticipants': 24,
      'entryFee': 500.0,
      'prizePool': 25000.0,
      'status': 'open', // open, closed, ongoing, completed
      'organizer': 'Davanagere Sports Association',
      'contactNumber': '+91 9876543210',
      'rules': [
        'Age limit: 18-45 years',
        'Valid ID proof required',
        'Participants must bring their own equipment',
      ],
      'imageUrl':
          'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=800',
    },
    {
      'name': 'Inter-Club Cricket Tournament',
      'sport': 'Cricket',
      'description': 'T20 format cricket tournament for club teams',
      'date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 20))),
      'registrationDeadline': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 12)),
      ),
      'location': 'Mask Turf Play Arena, Davanagere',
      'maxParticipants': 12,
      'currentParticipants': 8,
      'entryFee': 2000.0,
      'prizePool': 50000.0,
      'status': 'open',
      'organizer': 'Karnataka Cricket Association',
      'contactNumber': '+91 9876543212',
      'rules': [
        'Team of 11 players + 4 substitutes',
        'T20 format',
        'Professional umpires will be provided',
      ],
      'imageUrl':
          'https://images.unsplash.com/photo-1531415074968-036ba1b575da?w=800',
    },
  ];

  for (var tournament in tournaments) {
    try {
      await firestore.collection('tournaments').add(tournament);
      print('Added tournament: ${tournament['name']}');
    } catch (e) {
      print('Error adding tournament: $e');
    }
  }
}

// Helper function to clear all sample data (use with caution!)
Future<void> clearSampleData() async {
  final firestore = FirebaseFirestore.instance;

  print('⚠️  WARNING: Clearing all sample data...');

  // Delete all clubs
  final clubsSnapshot = await firestore.collection('clubs').get();
  for (var doc in clubsSnapshot.docs) {
    await doc.reference.delete();
  }
  print('Deleted ${clubsSnapshot.docs.length} clubs');

  // Delete all courts
  final courtsSnapshot = await firestore.collection('courts').get();
  for (var doc in courtsSnapshot.docs) {
    await doc.reference.delete();
  }
  print('Deleted ${courtsSnapshot.docs.length} courts');

  // Delete all bookings
  final bookingsSnapshot = await firestore.collection('bookings').get();
  for (var doc in bookingsSnapshot.docs) {
    await doc.reference.delete();
  }
  print('Deleted ${bookingsSnapshot.docs.length} bookings');

  // Delete all tournaments
  final tournamentsSnapshot = await firestore.collection('tournaments').get();
  for (var doc in tournamentsSnapshot.docs) {
    await doc.reference.delete();
  }
  print('Deleted ${tournamentsSnapshot.docs.length} tournaments');

  print('✅ All sample data cleared!');
}
