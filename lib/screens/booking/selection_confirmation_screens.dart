import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/models.dart';
import 'package:play_hub/screens/booking/booking_confirmation_screen.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/service/booking_service.dart';

class SelectDateTimeScreen extends StatefulWidget {
  final Club club;
  final Court court;
  final String sport;

  const SelectDateTimeScreen({
    super.key,
    required this.club,
    required this.court,
    required this.sport,
  });

  @override
  State<SelectDateTimeScreen> createState() => _SelectDateTimeScreenState();
}

class _SelectDateTimeScreenState extends State<SelectDateTimeScreen> {
  final bookingService = BookingService();
  DateTime selectedDate = DateTime.now();
  String? selectedTimeSlot;
  List<TimeSlot> timeSlots = [];
  bool isLoading = false;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadTimeSlots();
  }

  DateTime _slotStartDateTime(String startTime, DateTime selectedDate) {
    // Handle both 12-hour and 24-hour formats
    String cleanTime = startTime.trim();

    // Remove AM/PM if present and convert to 24-hour format
    bool isPM = cleanTime.toUpperCase().contains('PM');
    bool isAM = cleanTime.toUpperCase().contains('AM');
    cleanTime = cleanTime
        .replaceAll(RegExp(r'[AP]M', caseSensitive: false), '')
        .trim();

    final parts = cleanTime.split(':');
    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    // Convert to 24-hour format
    if (isPM && hour != 12) {
      hour += 12;
    } else if (isAM && hour == 12) {
      hour = 0;
    }

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      hour,
      minute,
    );
  }

  Future<void> _loadTimeSlots() async {
    setState(() => isLoading = true);

    final price = widget.club.pricePerHour[widget.sport] ?? 0.0;

    final slots = await bookingService.getAvailableSlots(
      clubId: widget.club.id,
      courtId: widget.court.id,
      date: selectedDate,
      pricePerHour: price,
    );

    setState(() {
      timeSlots = slots;
      isLoading = false;
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      selectedDate = date;
      selectedTimeSlot = null;
    });
    _loadTimeSlots();
  }

  void _proceedToBooking() {
    if (selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a time slot'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(
          club: widget.club,
          court: widget.court,
          sport: widget.sport,
          date: selectedDate,
          timeSlot: selectedTimeSlot!,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(date.year, date.month, date.day);

    if (selectedDay == today) {
      return 'Today, ${DateFormat('MMM dd').format(date)}';
    } else if (selectedDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow, ${DateFormat('MMM dd').format(date)}';
    } else {
      return DateFormat('EEEE, MMM dd').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Select Date & Time'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Club Info Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.club.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.court.name} • ${widget.sport}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.teal.shade200,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.currency_rupee,
                            size: 18,
                            color: Colors.teal.shade700,
                          ),
                          Text(
                            '${widget.club.pricePerHour[widget.sport]?.toStringAsFixed(0)}/hr',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(selectedDate),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Date Selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Select Date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: 14, // Show 14 days ahead
                    itemBuilder: (context, index) {
                      final date = DateTime.now().add(Duration(days: index));
                      final isSelected =
                          date.day == selectedDate.day &&
                          date.month == selectedDate.month &&
                          date.year == selectedDate.year;

                      return GestureDetector(
                        onTap: () => _selectDate(date),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 75,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.teal.shade600,
                                      Colors.teal.shade800,
                                    ],
                                  )
                                : null,
                            color: isSelected ? null : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.teal.shade700
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.teal.shade200,
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('EEE').format(date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                date.day.toString(),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMM').format(date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Legend Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(
                  Colors.teal.shade700,
                  'Selected',
                  Icons.check_circle,
                ),
                _buildLegendItem(
                  Colors.green.shade400,
                  'Available',
                  Icons.circle,
                ),
                _buildLegendItem(
                  Colors.blue.shade400,
                  'My Booking',
                  Icons.person,
                ),
                _buildLegendItem(Colors.red.shade400, 'Booked', Icons.cancel),
              ],
            ),
          ),

          const Divider(height: 1),

          // Time Slots Grid
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Available Time Slots',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${timeSlots.where((s) => !s.isBooked).length} available',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: timeSlots.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.event_busy,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No slots available for this date',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.6,
                                    ),
                                itemCount: timeSlots.length,
                                itemBuilder: (context, index) {
                                  final slot = timeSlots[index];
                                  return _buildTimeSlotCard(slot, now);
                                },
                              ),
                      ),
                    ],
                  ),
          ),

          // Proceed Button
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectedTimeSlot != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal.shade50, Colors.teal.shade100],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.teal.shade300,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.teal.shade700,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Time Slot',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal.shade600,
                                ),
                              ),
                              Text(
                                selectedTimeSlot!,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: selectedTimeSlot != null
                          ? _proceedToBooking
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        elevation: selectedTimeSlot != null ? 2 : 0,
                      ),
                      child: Text(
                        selectedTimeSlot != null
                            ? 'Proceed to Confirmation'
                            : 'Select a time slot to continue',
                        style: const TextStyle(
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

  Widget _buildLegendItem(Color color, String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotCard(TimeSlot slot, DateTime now) {
    final slotKey = '${slot.startTime}-${slot.endTime}';
    final isSelected = selectedTimeSlot == slotKey;

    // Check if slot is in the past
    final slotDateTime = _slotStartDateTime(slot.startTime, selectedDate);
    final isToday =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final isPast = isToday && slotDateTime.isBefore(now);

    // Check if booked by current user
    final currentUserId = _authService.currentUserEmailId;
    final currentUserEmail = _authService.currentUser?.email;

    final bookedByMe =
        slot.bookedBy != null &&
        (slot.bookedBy == currentUserId || slot.bookedBy == currentUserEmail);
    print(bookedByMe);
    // Determine slot state and styling
    Color bgColor;
    Color textColor;
    Color borderColor;
    String statusText;
    IconData? statusIcon;
    bool isClickable;

    if (isPast) {
      bgColor = Colors.grey.shade300;
      textColor = Colors.grey.shade600;
      borderColor = Colors.grey.shade400;
      statusText = 'Past';
      statusIcon = Icons.block;
      isClickable = false;
    } else if (isSelected) {
      bgColor = Colors.teal.shade700;
      textColor = Colors.white;
      borderColor = Colors.teal.shade900;
      statusText = 'Selected';
      statusIcon = Icons.check_circle;
      isClickable = true;
    } else if (slot.isBooked) {
      if (bookedByMe) {
        bgColor = Colors.blue.shade400;
        textColor = Colors.white;
        borderColor = Colors.blue.shade700;
        statusText = 'Yours';
        statusIcon = Icons.person;
        isClickable = false;
      } else {
        bgColor = Colors.red.shade400;
        textColor = Colors.white;
        borderColor = Colors.red.shade700;
        statusText = 'Booked';
        statusIcon = Icons.cancel;
        isClickable = false;
      }
    } else {
      bgColor = Colors.white;
      textColor = Colors.grey.shade800;
      borderColor = Colors.green.shade400;
      statusText = 'Available';
      statusIcon = Icons.check_circle_outline;
      isClickable = true;
    }

    return GestureDetector(
      onTap: isClickable
          ? () {
              setState(() {
                selectedTimeSlot = slotKey;
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 3 : 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.teal.shade200,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    slot.startTime,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (statusIcon != null)
                        Icon(statusIcon, size: 11, color: textColor),
                      const SizedBox(width: 3),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isClickable && !isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
