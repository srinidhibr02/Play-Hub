import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> initializeSampleData() async {
  final firestore = FirebaseFirestore.instance;

  // Sample Clubs
  final clubs = [
    {
      'name': 'Rachana Sports Club',
      'address': 'HP Circle, Beside Gandhi Maidhan, Harihar',
      'city': 'Davanagere',
      'rating': 4.0,
      'amenities': ['Parking', 'Changing Room'],
      'sports': ['Badminton'],
      'imageUrl': 'https://example.com/club1.jpg',
      'pricing': {'Badminton': 200.0},
      'phone': '+91 9876543210',
      'latitude': 14.515739,
      'longitude': 75.808205,
    },
    {
      'name': 'CFC',
      'address': 'Vidhya Nagar, CFC, Harihar',
      'city': 'Davanagere',
      'rating': 4.3,
      'amenities': ['Parking', 'Changing Room', 'Gym'],
      'sports': ['Badminton', 'Table Tennis'],
      'imageUrl': 'https://example.com/club2.jpg',
      'pricing': {'Badminton': 250.0, 'Gym': 300.0},
      'phone': '+91 9876543211',
      'latitude': 14.500333,
      'longitude': 75.807361,
    },
    {
      'name': 'Mask Turf Play Arena',
      'address': 'Near NH4 Shivamogga Road, Harihar',
      'city': 'Davanagere',
      'rating': 3.9,
      'amenities': ['Parking', 'Cafeteria', 'First Aid'],
      'sports': ['Football', 'Cricket'],
      'imageUrl': 'https://example.com/club3.jpg',
      'pricing': {'Cricket': 400.0, 'Football': 500.0},
      'phone': '+91 9876543212',
      'latitude': 14.489080,
      'longitude': 75.804803,
    },
  ];

  for (var club in clubs) {
    // Add the club document and get the DocumentReference
    final clubRef = await firestore.collection('clubs').add(club);

    final sports = club['sports'] as List;

    for (final sport in sports) {
      // Create a subcollection named exactly as the sport inside the club document
      final sportSubcollection = clubRef.collection(sport.toString());

      if (sport.toString().toLowerCase() == 'badminton') {
        await sportSubcollection.add({
          'name': 'Court 1',
          'sport': 'Badminton',
          'isAvailable': true,
          'surface': 'Wooden',
        });
        await sportSubcollection.add({
          'name': 'Court 2',
          'sport': 'Badminton',
          'isAvailable': true,
          'surface': 'Synthetic',
        });
      } else if (sport.toString().toLowerCase() == 'tennis') {
        await sportSubcollection.add({
          'name': 'Court 1',
          'sport': 'Tennis',
          'isAvailable': true,
          'surface': 'Hard Court',
        });
      } else if (sport.toString().toLowerCase() == 'cricket') {
        await sportSubcollection.add({
          'name': 'Ground 1',
          'sport': 'Cricket',
          'isAvailable': true,
          'surface': 'Turf',
        });
      }
    }
  }

  print("Added Sample data to firebase");
}
