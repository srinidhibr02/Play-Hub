import 'package:flutter/material.dart';
import 'package:play_hub/constants/models.dart';
import 'package:play_hub/screens/selection_confirmation_screens.dart';
import 'package:play_hub/service/booking_service.dart';

class SelectCourtScreen extends StatelessWidget {
  final Club club;
  final String sport;

  const SelectCourtScreen({super.key, required this.club, required this.sport});

  @override
  Widget build(BuildContext context) {
    final bookingService = BookingService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Court'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      body: Column(
        children: [
          // Club Info Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.sports, size: 48, color: Colors.teal.shade700),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sport,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Courts List
          Expanded(
            child: StreamBuilder<List<Court>>(
              stream: bookingService.getCourts(club.id, sport),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No courts available',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                }

                final courts = snapshot.data!;
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  itemCount: courts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildCourtCard(context, courts[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourtCard(BuildContext context, Court court) {
    return Material(
      elevation: court.isAvailable ? 4 : 1,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.teal.shade200,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: court.isAvailable
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SelectDateTimeScreen(
                      club: club,
                      court: court,
                      sport: sport,
                    ),
                  ),
                );
              }
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: court.isAvailable ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: court.isAvailable
                  ? Colors.teal.shade200
                  : Colors.grey.shade300,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: court.isAvailable
                      ? Colors.teal.shade50
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSportIcon(court.sport),
                  color: court.isAvailable
                      ? Colors.teal.shade700
                      : Colors.grey.shade600,
                  size: 32,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: court.isAvailable
                            ? Colors.black87
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      court.surface,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: court.isAvailable
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  court.isAvailable ? 'Available' : 'Unavailable',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: court.isAvailable
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'badminton':
        return Icons
            .sports_tennis; // No dedicated badminton icon, using tennis as closest
      case 'cricket':
        return Icons.sports_cricket;
      case 'tennis':
        return Icons.sports_tennis;
      case 'swimming':
        return Icons.pool;
      case 'table tennis':
        return Icons.sports_tennis; // reuse tennis icon
      case 'basketball':
        return Icons.sports_basketball;
      default:
        return Icons.sports; // generic sports icon fallback
    }
  }
}
