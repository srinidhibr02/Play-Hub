import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/models.dart';
import 'package:play_hub/screens/booking/booking_success_screen.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/service/booking_service.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final Club club;
  final Court court;
  final String sport;
  final DateTime date;
  final String timeSlot;

  const BookingConfirmationScreen({
    super.key,
    required this.club,
    required this.court,
    required this.sport,
    required this.date,
    required this.timeSlot,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final bookingService = BookingService();
  final authService = AuthService();
  bool isProcessing = false;

  Future<void> _confirmBooking() async {
    setState(() => isProcessing = true);

    final userId = authService.currentUserEmailId;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login to continue')));
      return;
    }

    final price = widget.club.pricing[widget.sport] ?? 0.0;

    final bookingId = await bookingService.createBooking(
      userId: userId,
      clubId: widget.club.id,
      courtId: widget.court.id,
      sport: widget.sport,
      date: widget.date,
      timeSlot: widget.timeSlot,
      price: price,
    );

    setState(() => isProcessing = false);

    if (bookingId != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(bookingId: bookingId),
        ),
        (route) => route.isFirst,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slot already booked. Please select another.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.club.pricing[widget.sport] ?? 0.0;
    final gst = price * 0.18;
    final total = price + gst;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Booking'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Success Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 60,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Booking Details Card
                  _buildDetailsCard(
                    title: 'Booking Details',
                    children: [
                      _buildDetailRow('Club', widget.club.name),
                      _buildDetailRow('Court', widget.court.name),
                      _buildDetailRow('Sport', widget.sport),
                      _buildDetailRow('Surface', widget.court.surface),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Date & Time Card
                  _buildDetailsCard(
                    title: 'Date & Time',
                    children: [
                      _buildDetailRow(
                        'Date',
                        DateFormat('EEEE, MMM dd, yyyy').format(widget.date),
                      ),
                      _buildDetailRow('Time Slot', widget.timeSlot),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Location Card
                  _buildDetailsCard(
                    title: 'Location',
                    children: [
                      _buildDetailRow('Address', widget.club.address),
                      _buildDetailRow('Phone', widget.club.phone),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Price Breakdown Card
                  _buildDetailsCard(
                    title: 'Price Breakdown',
                    children: [
                      _buildDetailRow(
                        'Court Charge',
                        '₹${price.toStringAsFixed(2)}',
                      ),
                      _buildDetailRow(
                        'GST (18%)',
                        '₹${gst.toStringAsFixed(2)}',
                      ),
                      const Divider(height: 24),
                      _buildDetailRow(
                        'Total Amount',
                        '₹${total.toStringAsFixed(2)}',
                        isTotal: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Confirm Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : _confirmBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Confirm & Pay',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Colors.teal.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
