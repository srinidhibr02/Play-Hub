import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

Future<void> initializeSampleData() async {
  final firestore = FirebaseFirestore.instance;

  // Tournament ID where registrations will be added
  const String tournamentId = '8tyieLvyTtzW4x70IhFZ';

  await _addSampleRegistrations(firestore, tournamentId);
}

Future<void> _addSampleRegistrations(
  FirebaseFirestore firestore,
  String tournamentId,
) async {
  final registrations = [
    {
      'bookingAmount': 25,
      'category': 'Male Doubles',
      'fullName': 'Dev B R',
      'participants': ['Abhishek', 'Basheer'],
      'paymentId': 'Xyz1OOYSnuSBl',
      'phoneNumber': '+91 8050820700',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'devbr1998@gmail.com',
    },
    {
      'bookingAmount': 25,
      'category': 'Male Doubles',
      'fullName': 'Sample User',
      'participants': ['Pratap', 'Abhi'],
      'paymentId': 'Bbc1OOYSnuUBl',
      'phoneNumber': '+91 9113083983',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'arjunbhandiwad02@gmail.com',
    },
    {
      'bookingAmount': 25,
      'category': 'Male Doubles',
      'fullName': 'Badminton Folks',
      'participants': ['Vinay', 'Pramod'],
      'paymentId': 'Uvw1OOYSnuSBl',
      'phoneNumber': '+91 9123456780',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'b.folks.2022@gmail.com',
    },
    {
      'bookingAmount': 25,
      'category': 'Male Doubles',
      'fullName': 'Srinidhi B R',
      'participants': ['Vinod', 'Pavan'],
      'paymentId': 'Abc1OOYSnuSBl',
      'phoneNumber': '+91 7892750858',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'srinidhibr02@gmail.com',
    },
  ];

  // Reference to tournament document -> registrations subcollection
  final tournamentRef = firestore.collection('tournaments').doc(tournamentId);
  final registrationsRef = tournamentRef.collection('registrations');

  // Use batch write for atomic operation (all or nothing)
  WriteBatch batch = firestore.batch();

  for (var registration in registrations) {
    // Generate unique doc ID for each registration
    final docRef = registrationsRef.doc();
    batch.set(docRef, registration);
  }

  try {
    await batch.commit();
    debugPrint(
      '✅ Successfully added ${registrations.length} registrations to tournament $tournamentId',
    );
  } catch (e) {
    debugPrint('❌ Error adding registrations: $e');
  }
}
