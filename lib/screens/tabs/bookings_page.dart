import 'package:flutter/material.dart';
import 'package:play_hub/constants/models.dart';
import 'package:play_hub/service/booking_service.dart';
import 'package:intl/intl.dart';

class BookingsScreen extends StatefulWidget {
  final String userId;

  const BookingsScreen({super.key, required this.userId});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BookingService _bookingService = BookingService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime _parseBookingEndDateTime(Booking booking) {
    final endTimeParts = booking.endTime
        .replaceAll(RegExp(r'[^\d:]'), '')
        .split(':');
    int endHour = int.parse(endTimeParts[0]);
    final int endMinute = endTimeParts.length > 1
        ? int.parse(endTimeParts[1])
        : 0;

    if (booking.endTime.toUpperCase().contains('PM') && endHour != 12) {
      endHour += 12;
    } else if (booking.endTime.toUpperCase().contains('AM') && endHour == 12) {
      endHour = 0;
    }

    return DateTime(
      booking.date.year,
      booking.date.month,
      booking.date.day,
      endHour,
      endMinute,
    );
  }

  DateTime _parseBookingStartDateTime(Booking booking) {
    final startTimeParts = booking.startTime
        .replaceAll(RegExp(r'[^\d:]'), '')
        .split(':');
    int startHour = int.parse(startTimeParts[0]);
    final int startMinute = startTimeParts.length > 1
        ? int.parse(startTimeParts[1])
        : 0;

    if (booking.startTime.toUpperCase().contains('PM') && startHour != 12) {
      startHour += 12;
    } else if (booking.startTime.toUpperCase().contains('AM') &&
        startHour == 12) {
      startHour = 0;
    }

    return DateTime(
      booking.date.year,
      booking.date.month,
      booking.date.day,
      startHour,
      startMinute,
    );
  }

  List<Booking> _filterActiveBookings(List<Booking> bookings) {
    final now = DateTime.now();
    final filtered = bookings.where((booking) {
      final bookingEndDateTime = _parseBookingEndDateTime(booking);
      return bookingEndDateTime.isAfter(now) &&
          (booking.status == 'confirmed' || booking.status == 'pending');
    }).toList();

    filtered.sort(
      (a, b) => _parseBookingStartDateTime(
        a,
      ).compareTo(_parseBookingStartDateTime(b)),
    );
    return filtered;
  }

  List<Booking> _filterPastBookings(List<Booking> bookings) {
    final now = DateTime.now();
    final filtered = bookings.where((booking) {
      final bookingEndDateTime = _parseBookingEndDateTime(booking);
      return bookingEndDateTime.isBefore(now) || booking.status == 'cancelled';
    }).toList();

    filtered.sort(
      (a, b) => _parseBookingStartDateTime(
        a,
      ).compareTo(_parseBookingStartDateTime(b)),
    );
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade700,
        title: const Text(
          'My Bookings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.tealAccent.shade400, Colors.teal.shade300],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'Past'),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Booking>>(
        stream: _bookingService.getUserBookings(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.teal.shade700),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final allBookings = snapshot.data ?? [];
          final activeBookings = _filterActiveBookings(allBookings);
          final pastBookings = _filterPastBookings(allBookings);

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBookingsList(activeBookings, isActive: true),
              _buildBookingsList(pastBookings, isActive: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookingsList(List<Booking> bookings, {required bool isActive}) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.event_busy : Icons.history,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'No active bookings' : 'No past bookings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isActive
                  ? 'Book your next game to get started!'
                  : 'Your booking history will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _buildBookingCard(booking, isActive: isActive);
      },
    );
  }

  Widget _buildBookingCard(Booking booking, {required bool isActive}) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (booking.status) {
      case 'confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Confirmed';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Pending';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Cancelled';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Completed';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusText = booking.status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade100.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isActive
                      ? [Colors.teal.shade700, Colors.teal.shade500]
                      : [Colors.grey.shade600, Colors.grey.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getSportIcon(booking.sport),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.clubName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${booking.sport} • ${booking.courtName}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
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
                      color: statusColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoTile(
                          icon: Icons.calendar_today,
                          label: 'Date',
                          value: booking.displayDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoTile(
                          icon: Icons.access_time,
                          label: 'Time',
                          value: booking.displayTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoTile(
                          icon: Icons.payments,
                          label: 'Amount',
                          value: '₹${booking.price.toStringAsFixed(0)}',
                          valueColor: Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  if (isActive && booking.status == 'confirmed') ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showBookingDetails(booking),
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: const Text('Details'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal.shade700,
                              side: BorderSide(color: Colors.teal.shade700),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmCancel(booking),
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Cancel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  void _showBookingDetails(Booking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Booking Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Booking ID', booking.id),
              _buildDetailRow('Club', booking.clubName),
              _buildDetailRow('Court', booking.courtName),
              _buildDetailRow('Sport', booking.sport),
              _buildDetailRow(
                'Date',
                DateFormat('EEEE, MMMM d, yyyy').format(booking.date),
              ),
              _buildDetailRow('Time', booking.displayTime),
              _buildDetailRow('Amount', '₹${booking.price.toStringAsFixed(0)}'),
              _buildDetailRow('Status', booking.status.toUpperCase()),
              if (booking.paymentId != null)
                _buildDetailRow('Payment ID', booking.paymentId!),
              _buildDetailRow(
                'Booked On',
                DateFormat('MMM d, yyyy at h:mm a').format(booking.createdAt),
              ),

              // User Details Section
              if (booking.userDetails != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                if (booking.userDetails!['name'] != null)
                  _buildDetailRow('Name', booking.userDetails!['name']),
                if (booking.userDetails!['email'] != null)
                  _buildDetailRow('Email', booking.userDetails!['email']),
                if (booking.userDetails!['phone'] != null)
                  _buildDetailRow('Phone', booking.userDetails!['phone']),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(Booking booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Text('Cancel Booking?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Keep Booking',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelBooking(booking);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel Booking',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(Booking booking) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(child: CircularProgressIndicator(color: Colors.teal.shade700)),
    );

    final result = await _bookingService.cancelBooking(booking.id);

    if (mounted) {
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success
              ? Colors.green.shade600
              : Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
