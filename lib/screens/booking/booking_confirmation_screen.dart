import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
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
  final List<String>? multipleSlots;

  const BookingConfirmationScreen({
    super.key,
    required this.club,
    required this.court,
    required this.sport,
    required this.date,
    required this.timeSlot,
    this.multipleSlots,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final bookingService = BookingService();
  final authService = AuthService();
  late Razorpay _razorpay;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  bool get isMultipleBooking =>
      widget.multipleSlots != null && widget.multipleSlots!.isNotEmpty;

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => isProcessing = true);

    try {
      final user = authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final userData = await authService.getCurrentUserData();
      final price = widget.club.pricePerHour[widget.sport] ?? 0.0;

      if (isMultipleBooking) {
        final firstSlot = widget.multipleSlots!.first;
        final lastSlot = widget.multipleSlots!.last;

        final firstSlotParts = firstSlot.split('-');
        final lastSlotParts = lastSlot.split('-');

        final startTime = firstSlotParts[0].trim();
        final endTime = lastSlotParts[1].trim();

        final multiplier = widget.multipleSlots!.length;
        final subtotal = price * multiplier;
        final platformFee = subtotal * 0.05;
        final total = subtotal + platformFee;

        final result = await bookingService.createBooking(
          userId: user.uid,
          userEmailId: user.email as String,
          clubId: widget.club.id,
          clubName: widget.club.name,
          courtId: widget.court.id,
          courtName: widget.court.name,
          sport: widget.sport,
          date: widget.date,
          startTime: startTime,
          endTime: endTime,
          price: total,
          userDetails: {
            'name': userData?['fullName'] ?? user.displayName ?? 'User',
            'email': user.email ?? '',
            'phone': userData?['phoneNumber'] ?? '',
          },
          paymentId: response.paymentId as String,
          paymentMethod: 'Razorpay',
        );

        setState(() => isProcessing = false);

        if (!mounted) return;

        if (result.success && result.bookingId != null) {
          _showSuccessDialog(
            'Booking Confirmed!',
            'Your ${widget.multipleSlots!.length} slots have been booked successfully.\nPayment ID: ${response.paymentId}',
            result.bookingId!,
            isMultiple: true,
            slotsCount: widget.multipleSlots!.length,
          );
        } else {
          _showErrorDialog('Booking Failed', result.message);
        }
      } else {
        final timeSlotParts = widget.timeSlot.split('-');
        if (timeSlotParts.length != 2) {
          throw Exception('Invalid time slot format');
        }

        final startTime = timeSlotParts[0].trim();
        final endTime = timeSlotParts[1].trim();

        final result = await bookingService.createBooking(
          userId: user.uid,
          userEmailId: user.email as String,
          clubId: widget.club.id,
          clubName: widget.club.name,
          courtId: widget.court.id,
          courtName: widget.court.name,
          sport: widget.sport,
          date: widget.date,
          startTime: startTime,
          endTime: endTime,
          price: price,
          userDetails: {
            'name': userData?['fullName'] ?? user.displayName ?? 'User',
            'email': user.email ?? '',
            'phone': userData?['phoneNumber'] ?? '',
          },
          paymentId: response.paymentId as String,
          paymentMethod: 'Razorpay',
        );

        setState(() => isProcessing = false);

        if (!mounted) return;

        if (result.success && result.bookingId != null) {
          _showSuccessDialog(
            'Booking Confirmed!',
            'Your booking has been confirmed successfully.\nPayment ID: ${response.paymentId}',
            result.bookingId!,
          );
        } else {
          _showErrorDialog('Booking Failed', result.message);
        }
      }
    } catch (e) {
      setState(() => isProcessing = false);
      if (!mounted) return;
      _showErrorDialog('Error', 'Error creating booking: $e');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => isProcessing = false);
    if (!mounted) return;
    _showErrorDialog(
      'Payment Failed',
      'Code: ${response.code}\nDescription: ${response.message}',
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() => isProcessing = false);
    if (!mounted) return;
    _showErrorDialog('External Wallet', '${response.walletName}');
  }

  void _proceedToPayment() {
    final price = widget.club.pricePerHour[widget.sport] ?? 0.0;
    final multiplier = isMultipleBooking ? widget.multipleSlots!.length : 1;
    final subtotal = price * multiplier;
    final platformFee = subtotal * 0.05;

    final user = authService.currentUser;
    if (user == null) {
      _showErrorDialog('Error', 'Please login to continue');
      return;
    }

    try {
      setState(() => isProcessing = true);

      var options = {
        'key': 'rzp_live_S1intCExDSf19z', // Replace with your Razorpay Key ID
        'amount': (platformFee * 100).toInt(), // Total amount in paise
        'name': 'PlayHub',
        'description': isMultipleBooking
            ? 'Platform Fee for ${widget.multipleSlots!.length} ${widget.sport} Slots'
            : 'Platform Fee for ${widget.sport} Booking',
        'retry': {'enabled': true, 'max_count': 1},
        'send_sms_hash': true,
        'prefill': {
          'contact': user.phoneNumber ?? '9999999999',
          'email': user.email ?? 'user@example.com',
        },
        'external': {
          'wallets': ['paytm'],
        },
        'notes': {
          'booking_type': isMultipleBooking ? 'multiple' : 'single',
          'slots_count': isMultipleBooking ? widget.multipleSlots!.length : 1,
          'club_id': widget.club.id,
          'club_name': widget.club.name,
          'court_id': widget.court.id,
          'sport': widget.sport,
        },
      };

      _razorpay.open(options);
    } catch (e) {
      setState(() => isProcessing = false);
      _showErrorDialog('Payment Error', 'Error initiating payment: $e');
    }
  }

  void _showSuccessDialog(
    String title,
    String message,
    String bookingId, {
    bool isMultiple = false,
    int slotsCount = 1,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => BookingSuccessScreen(
                      bookingId: bookingId,
                      isMultipleBooking: isMultiple,
                      slotsCount: slotsCount,
                    ),
                  ),
                  (route) => route.isFirst,
                );
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.club.pricePerHour[widget.sport] ?? 0.0;
    final multiplier = isMultipleBooking ? widget.multipleSlots!.length : 1;
    final subtotal = price * multiplier;
    final platformFee = subtotal * 0.05;
    final total = subtotal + platformFee;

    return PopScope(
      canPop: !isProcessing,
      child: Scaffold(
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
                          color: isMultipleBooking
                              ? Colors.purple.shade50
                              : Colors.teal.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isMultipleBooking
                              ? Icons.layers
                              : Icons.event_available,
                          size: 60,
                          color: isMultipleBooking
                              ? Colors.purple.shade700
                              : Colors.teal.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: Text(
                        isMultipleBooking
                            ? 'Review Your Bookings'
                            : 'Review Your Booking',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (isMultipleBooking)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.purple.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '${widget.multipleSlots!.length} time slots selected',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Booking Details Card
                    _buildDetailsCard(
                      title: 'Booking Details',
                      icon: Icons.sports,
                      children: [
                        _buildDetailRow('Club', widget.club.name),
                        _buildDetailRow('Court', widget.court.name),
                        _buildDetailRow('Sport', widget.sport),
                        _buildDetailRow('Type', widget.court.type),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Date & Time Card
                    _buildDetailsCard(
                      title: 'Date & Time',
                      icon: Icons.calendar_today,
                      children: [
                        _buildDetailRow(
                          'Date',
                          DateFormat('EEEE, MMM dd, yyyy').format(widget.date),
                        ),
                        if (!isMultipleBooking)
                          _buildDetailRow('Time Slot', widget.timeSlot)
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  'Selected Slots',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: widget.multipleSlots!
                                    .map(
                                      (slot) => Container(
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.purple.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Text(
                                          slot,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.purple.shade700,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Location Card
                    _buildDetailsCard(
                      title: 'Location',
                      icon: Icons.location_on,
                      children: [
                        _buildDetailRow('Address', widget.club.address),
                        _buildDetailRow('Phone', widget.club.phoneNumber),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Price Breakdown Card
                    _buildDetailsCard(
                      title: 'Price Breakdown',
                      icon: Icons.receipt,
                      children: [
                        if (isMultipleBooking)
                          Column(
                            children: [
                              _buildDetailRow(
                                'Court Charge per Slot',
                                '₹${price.toStringAsFixed(2)}',
                              ),
                              _buildDetailRow(
                                'Number of Slots',
                                '${widget.multipleSlots!.length}',
                              ),
                              const Divider(height: 24),
                              _buildDetailRow(
                                'Subtotal',
                                '₹${subtotal.toStringAsFixed(2)}',
                              ),
                            ],
                          )
                        else
                          _buildDetailRow(
                            'Court Charge',
                            '₹${price.toStringAsFixed(2)}',
                          ),
                        _buildDetailRow(
                          'Platform Fee (5%)',
                          '₹${platformFee.toStringAsFixed(2)}',
                          isHighlighted: true,
                        ),
                        const Divider(height: 24),
                        _buildDetailRow(
                          'Total Amount',
                          '₹${total.toStringAsFixed(2)}',
                          isTotal: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Platform Fee Info Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purple.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_rounded,
                            size: 20,
                            color: Colors.purple.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Platform fee (₹${platformFee.toStringAsFixed(2)}) is non-refundable',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.purple.shade900,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Important Information
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Important Information',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Please arrive 10 minutes before your slot\n'
                            '• Cancellations allowed up to 2 hours before\n'
                            '• Bring valid ID for verification\n'
                            '• Follow club rules and regulations${isMultipleBooking ? '\n• All slots must be on the same date' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade800,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Payment Button
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade50,
                            Colors.purple.shade100,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purple.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pay $platformFee to book (Non Refundable)\nPay ${total - platformFee} at the club',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${platformFee.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade900,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.lock_rounded,
                            color: Colors.purple.shade700,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isProcessing ? null : _proceedToPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          disabledBackgroundColor: Colors.grey.shade400,
                          elevation: 4,
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
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.payment_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pay ₹${platformFee.toStringAsFixed(2)} & Book Now',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Secure payment powered by Razorpay',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isMultipleBooking
                    ? Colors.purple.shade700
                    : Colors.teal.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal
                  ? FontWeight.bold
                  : isHighlighted
                  ? FontWeight.w700
                  : FontWeight.normal,
              color: isTotal
                  ? Colors.black87
                  : isHighlighted
                  ? Colors.purple.shade700
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isTotal ? 18 : 14,
                fontWeight: isTotal
                    ? FontWeight.bold
                    : isHighlighted
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: isTotal
                    ? isMultipleBooking
                          ? Colors.purple.shade700
                          : Colors.teal.shade700
                    : isHighlighted
                    ? Colors.purple.shade700
                    : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }
}
