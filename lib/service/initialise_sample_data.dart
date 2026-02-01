import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

Future<void> initializeSampleData() async {
  final firestore = FirebaseFirestore.instance;

  // Tournament ID where registrations will be added
  const String tournamentId = 'Rmi6yzdNfOEAk5HTB3E9';

  await _addSampleRegistrations(firestore, tournamentId);
}

Future<void> _addSampleRegistrations(
  FirebaseFirestore firestore,
  String tournamentId,
) async {
  final registrations = [
    //Male Doubles
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
    {
      'bookingAmount': 25,
      'category': 'Male Doubles',
      'fullName': 'Badminton Folks',
      'participants': ['Arjun', 'Nandish'],
      'paymentId': 'jkl1OOYSnuSBl',
      'phoneNumber': '+91 9123456780',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'nandishng999@gmail.com',
    },
    {
      'bookingAmount': 25,
      'category': 'Male Doubles',
      'fullName': 'Sanjay N K',
      'participants': ['Sanjay', 'Bharat'],
      'paymentId': 'tuv1OOYSnuSBl',
      'phoneNumber': '+91 7892750858',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'jarwasanju@gmail.com',
    },

    //Male Singles
    {
      'bookingAmount': 17.5,
      'category': 'Male Singles',
      'fullName': 'Dev B R',
      'participants': ['Abhishek'],
      'paymentId': 'Xyz1OOYSnuSBl',
      'phoneNumber': '+91 8050820700',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'devbr1998@gmail.com',
    },
    {
      'bookingAmount': 17.5,
      'category': 'Male Singles',
      'fullName': 'Sample User',
      'participants': ['Pratap'],
      'paymentId': 'Bbc1OOYSnuUBl',
      'phoneNumber': '+91 9113083983',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'arjunbhandiwad02@gmail.com',
    },
    {
      'bookingAmount': 17.5,
      'category': 'Male Singles',
      'fullName': 'Badminton Folks',
      'participants': ['Vinay'],
      'paymentId': 'Uvw1OOYSnuSBl',
      'phoneNumber': '+91 9123456780',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'b.folks.2022@gmail.com',
    },
    {
      'bookingAmount': 17.5,
      'category': 'Male Singles',
      'fullName': 'Srinidhi B R',
      'participants': ['Vinod'],
      'paymentId': 'Abc1OOYSnuSBl',
      'phoneNumber': '+91 7892750858',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'srinidhibr02@gmail.com',
    },
    {
      'bookingAmount': 17.5,
      'category': 'Male Singles',
      'fullName': 'Badminton Folks',
      'participants': ['Nandish'],
      'paymentId': 'jkl1OOYSnuSBl',
      'phoneNumber': '+91 9123456780',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'nandishng999@gmail.com',
    },
    {
      'bookingAmount': 17.5,
      'category': 'Male Singles',
      'fullName': 'Sanjay N K',
      'participants': ['Sanjay'],
      'paymentId': 'tuv1OOYSnuSBl',
      'phoneNumber': '+91 7892750858',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'jarwasanju@gmail.com',
    },
    //Female Doubles
    {
      'bookingAmount': 17.5,
      'category': 'Female Doubles',
      'fullName': 'Badminton Folks',
      'participants': ['Anusha', 'Priya'],
      'paymentId': 'jkl1OOYSnuSBl',
      'phoneNumber': '+91 9123456780',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'nandishng999@gmail.com',
    },
    {
      'bookingAmount': 17.5,
      'category': 'Female Doubles',
      'fullName': 'Sanjay N K',
      'participants': ['Saraswathi', 'Anitha'],
      'paymentId': 'tuv1OOYSnuSBl',
      'phoneNumber': '+91 7892750858',
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      'userId': 'jarwasanju@gmail.com',
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
