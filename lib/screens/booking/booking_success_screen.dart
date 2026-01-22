import 'package:flutter/material.dart';
import 'package:play_hub/screens/tabs/bookings_page.dart';
import 'package:play_hub/service/auth_service.dart';

class BookingSuccessScreen extends StatelessWidget {
  final String bookingId;
  final bool isMultipleBooking;
  final int slotsCount;

  BookingSuccessScreen({
    super.key,
    required this.bookingId,
    this.isMultipleBooking = false,
    this.slotsCount = 1,
  });

  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final currentUserEmailId = _authService.currentUserEmailId;
    final displayBookingId = bookingId.length > 8
        ? bookingId.substring(0, 8).toUpperCase()
        : bookingId.toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon with Animation
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isMultipleBooking
                        ? [Colors.purple.shade50, Colors.purple.shade100]
                        : [Colors.green.shade50, Colors.green.shade100],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isMultipleBooking
                                  ? Colors.purple.shade300
                                  : Colors.green.shade300)
                              .withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  isMultipleBooking ? Icons.layers_rounded : Icons.check_circle,
                  size: 100,
                  color: isMultipleBooking
                      ? Colors.purple.shade600
                      : Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Success Title
              Text(
                isMultipleBooking
                    ? 'All Bookings Confirmed!'
                    : 'Booking Confirmed!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Success Message
              Text(
                isMultipleBooking
                    ? 'Your $slotsCount bookings have been confirmed successfully.'
                    : 'Your booking has been confirmed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Booking Details Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMultipleBooking
                        ? Colors.purple.shade200
                        : Colors.green.shade200,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Booking ID Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Booking ID',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              displayBookingId,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Booking ID copied!'),
                                backgroundColor: Colors.green.shade600,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMultipleBooking
                                  ? Colors.purple.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.content_copy_rounded,
                              size: 20,
                              color: isMultipleBooking
                                  ? Colors.purple.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Slots Info (if multiple)
                    if (isMultipleBooking)
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Slots Booked',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.purple.shade50,
                                          Colors.purple.shade100,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.purple.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      '$slotsCount time slot${slotsCount > 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.purple.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.check_circle,
                                size: 40,
                                color: Colors.purple.shade600,
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                        ],
                      ),

                    // Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Confirmed',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Icon(
                          Icons.verified_rounded,
                          size: 40,
                          color: Colors.green.shade600,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Info Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      size: 20,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A confirmation email has been sent to your registered email.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingsScreen(
                          userId: currentUserEmailId as String,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(
                      color: isMultipleBooking
                          ? Colors.purple.shade700
                          : Colors.teal.shade700,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: isMultipleBooking
                            ? Colors.purple.shade700
                            : Colors.teal.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'View My Bookings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isMultipleBooking
                              ? Colors.purple.shade700
                              : Colors.teal.shade700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
