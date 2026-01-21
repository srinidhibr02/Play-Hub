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
  Set<String> selectedMultipleSlots = {};
  List<TimeSlot> timeSlots = [];
  bool isLoading = false;
  bool isMultiSelectMode = false;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadTimeSlots();
  }

  DateTime _slotStartDateTime(String startTime, DateTime selectedDate) {
    String cleanTime = startTime.trim();
    bool isPM = cleanTime.toUpperCase().contains('PM');
    bool isAM = cleanTime.toUpperCase().contains('AM');
    cleanTime = cleanTime
        .replaceAll(RegExp(r'[AP]M', caseSensitive: false), '')
        .trim();

    final parts = cleanTime.split(':');
    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

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
      selectedMultipleSlots.clear();
    });
    _loadTimeSlots();
  }

  void _toggleMultiSelectMode() {
    setState(() {
      isMultiSelectMode = !isMultiSelectMode;
      if (!isMultiSelectMode) {
        selectedMultipleSlots.clear();
      } else {
        selectedTimeSlot = null;
      }
    });
  }

  void _proceedToBooking() {
    if (isMultiSelectMode) {
      if (selectedMultipleSlots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Please select at least one time slot'),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
            timeSlot: selectedMultipleSlots.toList().join(', '),
            multipleSlots: selectedMultipleSlots.toList(),
          ),
        ),
      );
    } else {
      if (selectedTimeSlot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Please select a time slot'),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Select Date & Time',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Stack(
        children: [
          // SCROLLABLE CONTENT
          SingleChildScrollView(
            child: Column(
              children: [
                // Club Info Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${widget.court.name} • ${widget.sport}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade700,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.currency_rupee_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                Text(
                                  '${widget.club.pricePerHour[widget.sport]?.toStringAsFixed(0)}/hr',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.teal.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: Colors.teal.shade700,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatDate(selectedDate),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.teal.shade700,
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
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Select Date',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: 14,
                          itemBuilder: (context, index) {
                            final date = DateTime.now().add(
                              Duration(days: index),
                            );
                            final isSelected =
                                date.day == selectedDate.day &&
                                date.month == selectedDate.month &&
                                date.year == selectedDate.year;
                            return GestureDetector(
                              onTap: () => _selectDate(date),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 80,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
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
                                  color: isSelected
                                      ? null
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.teal.shade700
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.teal.shade300,
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                            spreadRadius: 1,
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
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      date.day.toString(),
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('MMM').format(date),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected
                                            ? Colors.white70
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Availability Legend',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLegendItem(Colors.green.shade400, 'Available'),
                          _buildLegendItem(Colors.teal.shade700, 'Selected'),
                          _buildLegendItem(
                            Colors.blue.shade400,
                            'Your Booking',
                          ),
                          _buildLegendItem(Colors.red.shade400, 'Booked'),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(height: 1, color: Colors.grey.shade200),

                // Multi-Select Toggle Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.layers_rounded,
                                size: 20,
                                color: Colors.teal.shade700,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Book Multiple Slots',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select multiple time slots at once',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Transform.scale(
                        scale: 0.85,
                        child: Switch(
                          value: isMultiSelectMode,
                          onChanged: (_) => _toggleMultiSelectMode(),
                          activeColor: Colors.teal.shade700,
                          activeTrackColor: Colors.teal.shade200,
                          inactiveTrackColor: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(height: 1, color: Colors.grey.shade200),

                // Time Slots Section
                Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Available Time Slots',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (!isLoading && timeSlots.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isMultiSelectMode
                                      ? Colors.purple.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isMultiSelectMode
                                        ? Colors.purple.shade300
                                        : Colors.green.shade300,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  isMultiSelectMode
                                      ? '${selectedMultipleSlots.length} selected'
                                      : '${timeSlots.where((s) => !s.isBooked).length}/${timeSlots.length}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isMultiSelectMode
                                        ? Colors.purple.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isLoading)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.teal.shade700,
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading time slots...',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (timeSlots.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.event_busy_rounded,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No slots available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try selecting a different date',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.6,
                                ),
                            itemCount: timeSlots.length,
                            itemBuilder: (context, index) =>
                                _buildTimeSlotCard(timeSlots[index], now),
                          ),
                        ),
                    ],
                  ),
                ),

                // Spacing for fixed button
                SizedBox(height: MediaQuery.of(context).padding.bottom + 120),
              ],
            ),
          ),

          // FIXED BOTTOM BUTTON
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMultiSelectMode && selectedMultipleSlots.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade50,
                              Colors.purple.shade100,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.purple.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.purple.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Slots',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple.shade600,
                                  ),
                                ),
                                Text(
                                  selectedMultipleSlots.join(',\n'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.purple.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else if (!isMultiSelectMode && selectedTimeSlot != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.teal.shade50, Colors.teal.shade100],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.teal.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              color: Colors.teal.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal.shade600,
                                  ),
                                ),
                                Text(
                                  selectedTimeSlot!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
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
                        onPressed:
                            (isMultiSelectMode &&
                                    selectedMultipleSlots.isNotEmpty) ||
                                (!isMultiSelectMode && selectedTimeSlot != null)
                            ? _proceedToBooking
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMultiSelectMode
                              ? Colors.purple.shade700
                              : Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                          elevation:
                              ((isMultiSelectMode &&
                                      selectedMultipleSlots.isNotEmpty) ||
                                  (!isMultiSelectMode &&
                                      selectedTimeSlot != null))
                              ? 4
                              : 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if ((isMultiSelectMode &&
                                    selectedMultipleSlots.isNotEmpty) ||
                                (!isMultiSelectMode &&
                                    selectedTimeSlot != null))
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            SizedBox(
                              width:
                                  ((isMultiSelectMode &&
                                          selectedMultipleSlots.isNotEmpty) ||
                                      (!isMultiSelectMode &&
                                          selectedTimeSlot != null))
                                  ? 8
                                  : 0,
                            ),
                            Text(
                              ((isMultiSelectMode &&
                                          selectedMultipleSlots.isNotEmpty) ||
                                      (!isMultiSelectMode &&
                                          selectedTimeSlot != null))
                                  ? 'Proceed to Confirmation'
                                  : isMultiSelectMode
                                  ? 'Select at least one slot'
                                  : 'Select a time slot',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
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
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotCard(TimeSlot slot, DateTime now) {
    final slotKey = '${slot.startTime}-${slot.endTime}';
    final isSelectedInMultiMode = selectedMultipleSlots.contains(slotKey);
    final isSelectedInSingleMode = selectedTimeSlot == slotKey;
    final isSelected = isMultiSelectMode
        ? isSelectedInMultiMode
        : isSelectedInSingleMode;

    final slotDateTime = _slotStartDateTime(slot.startTime, selectedDate);
    final isToday =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final isPast = isToday && slotDateTime.isBefore(now);

    final currentUserId = _authService.currentUserEmailId;
    final currentUserEmail = _authService.currentUser?.email;

    final bookedByMe =
        slot.bookedBy != null &&
        (slot.bookedBy == currentUserId || slot.bookedBy == currentUserEmail);

    Color bgColor;
    Color textColor;
    Color borderColor;
    String statusText;
    IconData? statusIcon;
    bool isClickable;

    if (isPast) {
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade600;
      borderColor = Colors.grey.shade400;
      statusText = 'Past';
      statusIcon = Icons.block_rounded;
      isClickable = false;
    } else if (isSelected) {
      if (isMultiSelectMode) {
        bgColor = Colors.purple.shade700;
        textColor = Colors.white;
        borderColor = Colors.purple.shade900;
        statusText = 'Selected';
        statusIcon = Icons.check_circle_rounded;
      } else {
        bgColor = Colors.teal.shade700;
        textColor = Colors.white;
        borderColor = Colors.teal.shade900;
        statusText = 'Selected';
        statusIcon = Icons.check_circle_rounded;
      }
      isClickable = true;
    } else if (slot.isBooked) {
      if (bookedByMe) {
        bgColor = Colors.blue.shade400;
        textColor = Colors.white;
        borderColor = Colors.blue.shade700;
        statusText = 'Yours';
        statusIcon = Icons.person_rounded;
        isClickable = false;
      } else {
        bgColor = Colors.red.shade400;
        textColor = Colors.white;
        borderColor = Colors.red.shade700;
        statusText = 'Booked';
        statusIcon = Icons.cancel_rounded;
        isClickable = false;
      }
    } else {
      bgColor = Colors.white;
      textColor = Colors.grey.shade800;
      borderColor = Colors.green.shade400;
      statusText = 'Available';
      statusIcon = Icons.check_circle_outlined;
      isClickable = true;
    }

    return GestureDetector(
      onTap: isClickable
          ? () {
              setState(() {
                if (isMultiSelectMode) {
                  if (selectedMultipleSlots.contains(slotKey)) {
                    selectedMultipleSlots.remove(slotKey);
                  } else {
                    selectedMultipleSlots.add(slotKey);
                  }
                } else {
                  selectedTimeSlot = slotKey;
                }
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 3 : 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: isMultiSelectMode
                        ? Colors.purple.shade300
                        : Colors.teal.shade300,
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (statusIcon != null)
                        Icon(statusIcon, size: 13, color: textColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: 0.2,
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
