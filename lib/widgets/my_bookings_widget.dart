import 'package:flutter/material.dart';
import 'package:play_hub/constants/models.dart';
import 'package:play_hub/screens/tabs/bookings_page.dart';
import 'package:play_hub/service/booking_service.dart';

class MyBookingsWidget extends StatelessWidget {
  final String userId;

  const MyBookingsWidget({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcomming',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade900,
                fontSize: 22,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingsScreen(userId: userId),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('View All'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal.shade700,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildBookingsList(context),
      ],
    );
  }

  Widget _buildBookingsList(BuildContext context) {
    final bookingService = BookingService();

    return StreamBuilder<List<Booking>>(
      stream: bookingService.getUserBookings(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (snapshot.hasError) {
          return _buildErrorCard();
        }

        final allBookings = snapshot.data ?? [];

        final now = DateTime.now();

        // Filter active bookings
        final activeBookings = allBookings.where((booking) {
          // Parse booking start DateTime
          final bookingStart = _parseBookingDateTime(
            booking.date,
            booking.startTime,
          );
          // Filter only if start time is in the future
          return ((booking.isUpcoming || booking.isToday) &&
              (booking.status == 'confirmed' || booking.status == 'pending') &&
              (bookingStart.isAfter(now) ||
                  bookingStart.isAtSameMomentAs(now)));
        }).toList();

        if (activeBookings.isEmpty) {
          return _buildNoBookingsCard(context);
        }

        // Sort by start datetime
        activeBookings.sort(
          (a, b) => _parseBookingDateTime(
            a.date,
            a.startTime,
          ).compareTo(_parseBookingDateTime(b.date, b.startTime)),
        );

        final nearestBooking = activeBookings.first;

        return _buildBookingCard(context: context, booking: nearestBooking);
      },
    );
  }

  DateTime _parseBookingDateTime(DateTime date, String timeString) {
    final timeParts = timeString.trim().split(' ');
    if (timeParts.length != 2) return date;

    final hourMinute = timeParts[0].split(':');
    if (hourMinute.length != 2) return date;

    int hour = int.tryParse(hourMinute[0]) ?? 0;
    final minute = int.tryParse(hourMinute[1]) ?? 0;
    final isPM = timeParts[1].toUpperCase() == 'PM';

    if (isPM && hour != 12) {
      hour += 12;
    } else if (!isPM && hour == 12) {
      hour = 0;
    }

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Widget _buildBookingCard({
    required BuildContext context,
    required Booking booking,
  }) {
    final now = DateTime.now();

    // Parse the start time from the booking (e.g., "6:00 PM")
    final bookingDateTime = _parseBookingDateTime(
      booking.date,
      booking.startTime,
    );
    final timeDifference = bookingDateTime.difference(now);

    String timeUntil;
    Color timeColor;

    if (booking.isToday) {
      final hours = timeDifference.inHours;
      final minutes = timeDifference.inMinutes % 60;

      if (timeDifference.isNegative) {
        // Booking time has passed
        timeUntil = 'In Progress';
        timeColor = Colors.green.shade700;
      } else if (hours > 0) {
        timeUntil = 'In $hours hr ${minutes}min';
        timeColor = hours <= 2 ? Colors.orange.shade700 : Colors.teal.shade700;
      } else if (minutes > 0) {
        timeUntil = 'In $minutes min';
        timeColor = Colors.red.shade700;
      } else {
        timeUntil = 'Now';
        timeColor = Colors.red.shade700;
      }
    } else {
      final days = timeDifference.inDays;
      if (days == 1) {
        timeUntil = 'Tomorrow';
        timeColor = Colors.teal.shade700;
      } else {
        timeUntil = '$days days';
        timeColor = Colors.grey.shade700;
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade200.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingsScreen(userId: userId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getSportIcon(booking.sport),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.sport,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking.clubName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: timeColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        timeUntil,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          icon: Icons.calendar_today,
                          text: booking.displayDate,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          icon: Icons.access_time,
                          text: booking.displayTime,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: Colors.white.withOpacity(0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        booking.courtName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${booking.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String text}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: CircularProgressIndicator(color: Colors.teal.shade700),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unable to load bookings',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBookingsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No Active Bookings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Book your next game to see it here',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
        return Icons.sports_soccer;
      case 'basketball':
        return Icons.sports_basketball;
      case 'tennis':
        return Icons.sports_tennis;
      case 'badminton':
        return Icons.sports_baseball;
      case 'cricket':
        return Icons.sports_cricket;
      case 'volleyball':
        return Icons.sports_volleyball;
      default:
        return Icons.sports;
    }
  }
}
