import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> initializeSampleData() async {
  final firestore = FirebaseFirestore.instance;
  print('Starting to add sample data...');

  final clubs = [
    {
      'name': 'Rachana Sports Club',
      'address': 'HP Circle, Beside Gandhi Maidhan, Harihar',
      'city': 'Davanagere',
      'imageUrl':
          'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=800',
      'sports': ['Badminton', 'Gym'],
      'pricePerHour': {'Badminton': 200.0, 'Gym': 100.0},
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
      'name': 'Mask Turf Play Arena',
      'address': 'Near NH4 Shivamogga Road, Harihar',
      'city': 'Davanagere',
      'imageUrl':
          'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800',
      'sports': ['Football', 'Cricket', 'Swimming'],
      'pricePerHour': {'Football': 500.0, 'Cricket': 400.0, 'Swimming': 150.0},
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
      'sports': ['Badminton', 'Gym', 'Swimming'],
      'pricePerHour': {'Badminton': 300.0, 'Gym': 120.0, 'Swimming': 180.0},
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
    {
      'name': 'Metro Sports Complex',
      'address': 'Sector 18, Noida',
      'city': 'Noida',
      'imageUrl':
          'https://images.unsplash.com/photo-1546484959-f5b1548b6b92?w=800',
      'sports': ['Football', 'Gym'],
      'pricePerHour': {'Football': 550.0, 'Gym': 110.0},
      'rating': 4.4,
      'totalRatings': 102,
      'phoneNumber': '+91 9876543214',
      'amenities': {
        'parking': true,
        'changingRoom': true,
        'cafeteria': true,
        'firstAid': false,
        'wifi': true,
      },
      'location': GeoPoint(28.5672, 77.3210),
      'images': [
        'https://images.unsplash.com/photo-1546484959-f5b1548b6b92?w=800',
        'https://images.unsplash.com/photo-1508609349937-5ec4ae374ebf?w=800',
      ],
      'openingHours': {
        'Monday': '6:00 AM - 10:00 PM',
        'Tuesday': '6:00 AM - 10:00 PM',
        'Wednesday': '6:00 AM - 10:00 PM',
        'Thursday': '6:00 AM - 10:00 PM',
        'Friday': '6:00 AM - 10:00 PM',
        'Saturday': '8:00 AM - 9:00 PM',
        'Sunday': '8:00 AM - 9:00 PM',
      },
    },
  ];

  for (var clubData in clubs) {
    try {
      final clubRef = await firestore.collection('clubs').add(clubData);
      print('Added club: ${clubData['name']}');

      final List sports = clubData['sports'] as List<dynamic>;

      for (final sport in sports) {
        final sportStr = sport.toString().toLowerCase();

        List<Map<String, dynamic>> courtsToAdd = [];

        if (sportStr == 'badminton') {
          courtsToAdd = List.generate(3, (i) {
            return {
              'clubId': clubRef.id,
              'name': 'Badminton Court ${i + 1}',
              'sport': 'Badminton',
              'type': 'Indoor',
              'capacity': 4,
              'isActive': true,
            };
          });
        } else if (sportStr == 'gym') {
          courtsToAdd = List.generate(2, (i) {
            return {
              'clubId': clubRef.id,
              'name': 'Gym Area ${i + 1}',
              'sport': 'Gym',
              'type': 'Indoor',
              'capacity': 20,
              'isActive': true,
            };
          });
        } else if (sportStr == 'football') {
          courtsToAdd = [
            {
              'clubId': clubRef.id,
              'name': 'Football Turf 1',
              'sport': 'Football',
              'type': 'Outdoor',
              'capacity': 22,
              'isActive': true,
            },
          ];
        } else if (sportStr == 'cricket') {
          courtsToAdd = [
            {
              'clubId': clubRef.id,
              'name': 'Cricket Ground 1',
              'sport': 'Cricket',
              'type': 'Outdoor',
              'capacity': 22,
              'isActive': true,
            },
          ];
        } else if (sportStr == 'swimming') {
          courtsToAdd = List.generate(2, (i) {
            return {
              'clubId': clubRef.id,
              'name': 'Swimming Pool ${i + 1}',
              'sport': 'Swimming',
              'type': 'Indoor',
              'capacity': 10,
              'isActive': true,
            };
          });
        }

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

  // Add sample tournaments
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
      'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 15))),
      'registrationDeadline': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 10)),
      ),
      'location': 'Rachana Sports Club, Davanagere',
      'maxParticipants': 32,
      'currentParticipants': 24,
      'entryFee': 500.0,
      'prizePool': 25000.0,
      'status': 'open',
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
      'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 20))),
      'registrationDeadline': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 12)),
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
    {
      'name': 'National Swimming Gala',
      'sport': 'Swimming',
      'description': 'Competitive swimming event for all age groups',
      'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
      'registrationDeadline': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 25)),
      ),
      'location': 'City Aquatic Center',
      'maxParticipants': 50,
      'currentParticipants': 20,
      'entryFee': 750.0,
      'prizePool': 30000.0,
      'status': 'open',
      'organizer': 'National Swimming Federation',
      'contactNumber': '+91 9876543220',
      'rules': [
        'Swimwear and caps mandatory',
        'Age categories apply',
        'Multiple events per participant',
      ],
      'imageUrl':
          'https://images.unsplash.com/photo-1508609349937-5ec4ae374ebf?w=800',
    },
    {
      'name': 'Annual Fitness Challenge',
      'sport': 'Gym',
      'description':
          'A month-long fitness challenge including strength and endurance tests',
      'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 40))),
      'registrationDeadline': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 35)),
      ),
      'location': 'Elite Sports Hub Gym',
      'maxParticipants': 100,
      'currentParticipants': 80,
      'entryFee': 1000.0,
      'prizePool': 40000.0,
      'status': 'open',
      'organizer': 'Elite Sports Hub',
      'contactNumber': '+91 9876543213',
      'rules': [
        'Daily attendance required',
        'Follow fitness coach guidelines',
        'Multiple fitness disciplines included',
      ],
      'imageUrl':
          'https://images.unsplash.com/photo-1546484959-f5b1548b6b92?w=800',
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
