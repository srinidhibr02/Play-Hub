import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

Future<void> initializeSampleData() async {
  final firestore = FirebaseFirestore.instance;

  await _addSampleTournaments(firestore);
}

Future<void> _addSampleTournaments(FirebaseFirestore firestore) async {
  final tournaments = [
    {
      'clubId': 'P1DgudkAn76ItbzfS8bp',
      'name': 'City Badminton Championship 2026',
      'sport': 'Badminton',
      'description':
          'Annual city-level badminton championship open to all age groups',
      'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 20))),
      'registrationDeadline': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 15)),
      ),
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
      'clubId': 'lwfHYaLEWARzSaSOs5Bo',
      'name': 'Inter-Club Cricket Tournament',
      'sport': 'Cricket',
      'description': 'T20 format cricket tournament for club teams',
      'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 20))),
      'registrationDeadline': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 12)),
      ),
      'maxParticipants': 12,
      'currentParticipants': 8,
      'entryFee': 2000.0,
      'prizePool': 50000.0,
      'status': 'open',
      'organizer': 'Davanagere Cricket Association',
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
      'clubId': 'Qxy1OOYSnuSBl3slXOV8',
      'name': 'National Swimming Gala',
      'sport': 'Swimming',
      'description': 'Competitive swimming event for all age groups',
      'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
      'registrationDeadline': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 25)),
      ),
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
      'clubId': 'Qxy1OOYSnuSBl3slXOV8',
      'name': 'City Level Badminton Tournament',
      'sport': 'Badminton',
      'description': 'Competitive badminton event for all age groups',
      'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
      'registrationDeadline': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 25)),
      ),
      'maxParticipants': 50,
      'currentParticipants': 20,
      'entryFee': 750.0,
      'prizePool': 30000.0,
      'status': 'open',
      'organizer': 'Chennai MLA',
      'contactNumber': '+91 9876543220',
      'rules': [
        'Bring your own equipments',
        'Age categories apply',
        'Events per participant',
      ],
      'imageUrl':
          'https://images.unsplash.com/photo-1508609349937-5ec4ae374ebf?w=800',
    },
    {
      'clubId': 'Qxy1OOYSnuSBl3slXOV8',
      'name': 'Annual Fitness Challenge',
      'sport': 'Gym',
      'description':
          'A month-long fitness challenge including strength and endurance tests',
      'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 40))),
      'registrationDeadline': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 35)),
      ),
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
    } catch (e) {
      debugPrint('Error adding tournament: $e');
    }
  }
}
