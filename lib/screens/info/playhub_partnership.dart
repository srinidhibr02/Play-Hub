import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/service/auth_service.dart';

class PlayhubPartnership extends StatefulWidget {
  const PlayhubPartnership({super.key});

  @override
  State<PlayhubPartnership> createState() => _PlayhubPartnershipState();
}

class _PlayhubPartnershipState extends State<PlayhubPartnership> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _userClubs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }

      final userId = _authService.currentUserEmailId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('📥 Fetching club data for user: $userId');

      final userClubsQuery = await _firestore
          .collection('clubs')
          .where('ownerId', isEqualTo: userId)
          .get();

      final userClubs = <Map<String, dynamic>>[];
      for (var doc in userClubsQuery.docs) {
        userClubs.add({'id': doc.id, ...doc.data()});
      }

      if (mounted) {
        setState(() {
          _userClubs = userClubs;
          _isLoading = false;
        });
      }

      debugPrint('✅ Fetched ${userClubs.length} user clubs');
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showRegistrationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _RegistrationModal(onSubmit: _submitClubRegistration),
    );
  }

  Future<void> _submitClubRegistration(Map<String, dynamic> clubData) async {
    try {
      final userId = _authService.currentUserEmailId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      clubData['ownerId'] = userId;
      clubData['verified'] = false;
      clubData['createdAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('clubs').add(clubData);

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('Club submitted for verification!');
        _fetchData();
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade100, Colors.cyan.shade100],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.business_rounded,
              size: 56,
              color: Colors.teal.shade600,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Loading...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.teal.shade200, width: 2),
                ),
                child: Icon(
                  Icons.business_outlined,
                  size: 64,
                  color: Colors.teal.shade300,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Clubs Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Click the + button to register your club for verification',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserClubCard(Map<String, dynamic> club) {
    final clubName = club['name'] as String? ?? 'Unknown Club';
    final city = club['city'] as String? ?? 'Unknown';
    final imageUrl = club['imageUrl'] as String? ?? '';
    final verified = club['verified'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: verified ? Colors.green.shade200 : Colors.orange.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (verified ? Colors.green : Colors.orange).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: verified
                          ? Colors.green.shade500
                          : Colors.orange.shade500,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          verified ? Icons.verified : Icons.pending,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          verified ? 'Verified' : 'Pending',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      city,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!verified) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_rounded,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Under verification by PlayHub team',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  onPressed: () => _showClubDetails(club),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verified
                        ? Colors.green.shade600
                        : Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClubDetails(Map<String, dynamic> club) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildClubDetailsSheet(club),
    );
  }

  Widget _buildClubDetailsSheet(Map<String, dynamic> club) {
    final clubName = club['name'] as String? ?? 'Unknown';
    final address = club['address'] as String? ?? 'N/A';
    final phoneNumber = club['phoneNumber'] as String? ?? 'N/A';
    final openingHours = club['openingHours'] as Map<String, dynamic>? ?? {};
    final pricePerHour = club['pricePerHour'] as Map<String, dynamic>? ?? {};
    final amenities = club['amenities'] as Map<String, dynamic>? ?? {};
    final sports = List<String>.from(club['sports'] ?? []);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
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
                  clubName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow(
                  Icons.location_on_rounded,
                  'Address',
                  address,
                  Colors.teal,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.phone_rounded,
                  'Phone',
                  phoneNumber,
                  Colors.teal,
                ),
                const SizedBox(height: 20),
                if (sports.isNotEmpty) ...[
                  Text(
                    'Sports',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: sports.map((sport) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.teal.shade300,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          sport,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                if (openingHours.isNotEmpty) ...[
                  Text(
                    'Opening Hours',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...openingHours.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            entry.value as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
                if (pricePerHour.isNotEmpty) ...[
                  Text(
                    'Pricing (Per Hour)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...pricePerHour.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${entry.value}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
                if (amenities.isNotEmpty) ...[
                  Text(
                    'Amenities',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (amenities['parking'] == true)
                        _buildAmenityChip('🅿️', 'Parking'),
                      if (amenities['wifi'] == true)
                        _buildAmenityChip('📶', 'WiFi'),
                      if (amenities['cafeteria'] == true)
                        _buildAmenityChip('☕', 'Cafeteria'),
                      if (amenities['changingRoom'] == true)
                        _buildAmenityChip('🛀', 'Changing Room'),
                      if (amenities['firstAid'] == true)
                        _buildAmenityChip('🏥', 'First Aid'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmenityChip(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade200, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.teal.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PlayHub Partnership',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Register & get your club verified',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _userClubs.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: Colors.teal.shade700,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _userClubs.length,
                itemBuilder: (context, index) =>
                    _buildUserClubCard(_userClubs[index]),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRegistrationModal,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text(
          'Register Club',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _RegistrationModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const _RegistrationModal({required this.onSubmit});

  @override
  State<_RegistrationModal> createState() => _RegistrationModalState();
}

class _RegistrationModalState extends State<_RegistrationModal> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isGettingLocation = false;
  int _currentStep = 0;

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _phoneController;
  late TextEditingController _imageUrlController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  final List<String> _selectedSports = [];
  final Map<String, bool> _amenities = {
    'parking': false,
    'wifi': false,
    'cafeteria': false,
    'changingRoom': false,
    'firstAid': false,
  };

  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, String> _openingHours = {
    'Monday': '',
    'Tuesday': '',
    'Wednesday': '',
    'Thursday': '',
    'Friday': '',
    'Saturday': '',
    'Sunday': '',
  };

  // Time picker variables
  TimeOfDay? _weekdayOpeningTime;
  TimeOfDay? _weekdayClosingTime;
  TimeOfDay? _weekendOpeningTime;
  TimeOfDay? _weekendClosingTime;
  bool _applySameTimeToAllDays = true;

  final List<String> _availableSports = [
    'Badminton',
    'Football',
    'Tennis',
    'Gym',
    'Cricket',
    'Basketball',
    'Volleyball',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _phoneController = TextEditingController();
    _imageUrlController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();

    // Set default times
    _weekdayOpeningTime = const TimeOfDay(hour: 6, minute: 0);
    _weekdayClosingTime = const TimeOfDay(hour: 22, minute: 0);
    _weekendOpeningTime = const TimeOfDay(hour: 8, minute: 0);
    _weekendClosingTime = const TimeOfDay(hour: 20, minute: 0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _imageUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isGettingLocation = true);

      // Check location permission
      final status = await Permission.locationWhenInUse.status;
      if (!status.isGranted) {
        final result = await Permission.locationWhenInUse.request();
        if (!result.isGranted) {
          _showErrorSnackBar(
            'Location permission is required to get your current location',
          );
          return;
        }
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });

      _showSuccessSnackBar('Location detected successfully!');
    } catch (e) {
      debugPrint('Error getting location: $e');
      _showErrorSnackBar(
        'Could not get location. Please enter manually or check permissions.',
      );
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectTime(
    BuildContext context,
    bool isOpening,
    bool isWeekday,
  ) async {
    final currentTime = isWeekday
        ? (isOpening ? _weekdayOpeningTime : _weekdayClosingTime)
        : (isOpening ? _weekendOpeningTime : _weekendClosingTime);

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      setState(() {
        if (isWeekday) {
          if (isOpening) {
            _weekdayOpeningTime = selectedTime;
          } else {
            _weekdayClosingTime = selectedTime;
          }
        } else {
          if (isOpening) {
            _weekendOpeningTime = selectedTime;
          } else {
            _weekendClosingTime = selectedTime;
          }
        }
      });
    }
  }

  void _applyTimesToAllDays() {
    if (_applySameTimeToAllDays) {
      // Apply weekday times to all days
      if (_weekdayOpeningTime != null && _weekdayClosingTime != null) {
        _openingHours.updateAll((day, value) {
          return '${_formatTime(_weekdayOpeningTime!)} - ${_formatTime(_weekdayClosingTime!)}';
        });
      }
    } else {
      // Apply weekday times to weekdays
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      if (_weekdayOpeningTime != null && _weekdayClosingTime != null) {
        for (var day in weekdays) {
          _openingHours[day] =
              '${_formatTime(_weekdayOpeningTime!)} - ${_formatTime(_weekdayClosingTime!)}';
        }
      }

      // Apply weekend times to weekends
      final weekends = ['Saturday', 'Sunday'];
      if (_weekendOpeningTime != null && _weekendClosingTime != null) {
        for (var day in weekends) {
          _openingHours[day] =
              '${_formatTime(_weekendOpeningTime!)} - ${_formatTime(_weekendClosingTime!)}';
        }
      }
    }
    _showSuccessSnackBar('Times applied successfully!');
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one sport'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate and apply times if not already applied
    if (_applySameTimeToAllDays) {
      if (_weekdayOpeningTime == null || _weekdayClosingTime == null) {
        _showErrorSnackBar('Please set weekday opening hours');
        return;
      }
      _applyTimesToAllDays();
    } else {
      if ((_weekdayOpeningTime == null || _weekdayClosingTime == null) ||
          (_weekendOpeningTime == null || _weekendClosingTime == null)) {
        _showErrorSnackBar('Please set both weekday and weekend hours');
        return;
      }
      _applyTimesToAllDays();
    }

    // Validate latitude and longitude
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid latitude and longitude'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      Map<String, dynamic> pricePerHour = {};
      for (var sport in _selectedSports) {
        if (_priceControllers[sport] != null &&
            _priceControllers[sport]!.text.isNotEmpty) {
          pricePerHour[sport] =
              int.tryParse(_priceControllers[sport]!.text) ?? 0;
        }
      }

      final clubData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'imageUrl': _imageUrlController.text.trim(),
        'location': GeoPoint(latitude, longitude),
        'sports': _selectedSports,
        'amenities': _amenities,
        'pricePerHour': pricePerHour,
        'openingHours': _openingHours,
        'allowBookings': false,
        'rating': 0.0,
        'totalRatings': 0,
        'verified': false,
      };

      await widget.onSubmit(clubData);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ignore: unused_element
  Widget _buildStepIndicator(int step) {
    final isActive = step <= _currentStep;
    final isCurrent = step == _currentStep;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.teal.shade600 : Colors.grey.shade300,
        border: isCurrent
            ? Border.all(color: Colors.teal.shade400, width: 3)
            : null,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildSportsStep();
      case 2:
        return _buildHoursAndLocationStep();
      case 3:
        return _buildAmenitiesStep();
      default:
        return _buildBasicInfoStep();
    }
  }

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Basic Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell us about your club',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        _buildModernTextField(
          controller: _nameController,
          label: 'Club Name',
          icon: Icons.business_rounded,
          hint: 'e.g., Premium Sports Club',
          isRequired: true,
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _addressController,
          label: 'Address',
          icon: Icons.location_on_rounded,
          hint: 'e.g., 123 Sports Street, City Center',
          isRequired: true,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _cityController,
                label: 'City',
                icon: Icons.public_rounded,
                hint: 'e.g., Mumbai',
                isRequired: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernTextField(
                controller: _phoneController,
                label: 'Phone',
                icon: Icons.phone_rounded,
                hint: '+91 9876543210',
                keyboardType: TextInputType.phone,
                isRequired: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _imageUrlController,
          label: 'Club Image URL',
          icon: Icons.image_rounded,
          hint: 'https://example.com/club-image.jpg',
          isRequired: true,
        ),
      ],
    );
  }

  Widget _buildSportsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Sports & Pricing',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select sports offered and set pricing',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        Text(
          'Select Sports *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _availableSports.map((sport) {
            final isSelected = _selectedSports.contains(sport);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedSports.remove(sport);
                    _priceControllers[sport]?.dispose();
                    _priceControllers.remove(sport);
                  } else {
                    _selectedSports.add(sport);
                    _priceControllers[sport] = TextEditingController();
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.teal.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.teal.shade400
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.teal.shade100,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  sport,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.teal.shade700
                        : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedSports.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Set Hourly Pricing (₹)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          ..._selectedSports.map((sport) {
            if (!_priceControllers.containsKey(sport)) {
              _priceControllers[sport] = TextEditingController();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPriceField(
                controller: _priceControllers[sport]!,
                label: sport,
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildHoursAndLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Hours & Location',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set opening hours and club location',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),

        // Opening Hours Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Opening Hours',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Switch(
                    value: _applySameTimeToAllDays,
                    onChanged: (value) {
                      setState(() {
                        _applySameTimeToAllDays = value;
                      });
                    },
                    activeThumbColor: Colors.teal,
                  ),
                ],
              ),
              Text(
                _applySameTimeToAllDays
                    ? 'Same for all days'
                    : 'Different for weekends',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              // Weekdays Timing
              _buildTimeSelectorCard(
                title: _applySameTimeToAllDays
                    ? 'Daily Timing'
                    : 'Weekdays (Mon-Fri)',
                openingTime: _weekdayOpeningTime,
                closingTime: _weekdayClosingTime,
                isWeekday: true,
                color: Colors.teal,
              ),

              if (!_applySameTimeToAllDays) ...[
                const SizedBox(height: 16),
                _buildTimeSelectorCard(
                  title: 'Weekends (Sat-Sun)',
                  openingTime: _weekendOpeningTime,
                  closingTime: _weekendClosingTime,
                  isWeekday: false,
                  color: Colors.orange,
                ),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _applyTimesToAllDays,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Apply Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Location Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Club Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter coordinates or use your current location',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildModernTextField(
                      controller: _latitudeController,
                      label: 'Latitude',
                      icon: Icons.location_on_rounded,
                      hint: '28.5672',
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      isRequired: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernTextField(
                      controller: _longitudeController,
                      label: 'Longitude',
                      icon: Icons.location_on_rounded,
                      hint: '77.321',
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      isRequired: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGettingLocation ? null : _getCurrentLocation,
                  icon: _isGettingLocation
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(
                    _isGettingLocation
                        ? 'Detecting...'
                        : 'Use Current Location',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmenitiesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Amenities',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select facilities available at your club',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: _amenities.keys.map((amenity) {
            final isSelected = _amenities[amenity] ?? false;
            final amenityData = {
              'parking': {
                'label': 'Parking',
                'emoji': '🅿️',
                'color': Colors.blue,
              },
              'wifi': {'label': 'WiFi', 'emoji': '📶', 'color': Colors.purple},
              'cafeteria': {
                'label': 'Cafeteria',
                'emoji': '☕',
                'color': Colors.brown,
              },
              'changingRoom': {
                'label': 'Changing Room',
                'emoji': '🛀',
                'color': Colors.cyan,
              },
              'firstAid': {
                'label': 'First Aid',
                'emoji': '🏥',
                'color': Colors.red,
              },
            };

            final data = amenityData[amenity]!;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _amenities[amenity] = !isSelected;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (data['color'] as Color).withValues(alpha: 0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? data['color'] as Color
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (data['color'] as Color).withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.grey.shade100,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    Text(
                      data['emoji']! as String,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data['label']! as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? data['color'] as Color
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected
                          ? data['color'] as Color
                          : Colors.grey.shade400,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
            children: isRequired
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade50,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade600),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: isRequired
                ? (value) =>
                      value?.isEmpty ?? true ? 'This field is required' : null
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceField({
    required TextEditingController controller,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.teal.shade700,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Price per hour',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(
                  Icons.currency_rupee,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Enter price' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelectorCard({
    required String title,
    required TimeOfDay? openingTime,
    required TimeOfDay? closingTime,
    required bool isWeekday,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeButton(
                  time: openingTime,
                  label: 'Open',
                  onPressed: () => _selectTime(context, true, isWeekday),
                  color: color,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  color: color.withValues(alpha: 0.5),
                  size: 16,
                ),
              ),
              Expanded(
                child: _buildTimeButton(
                  time: closingTime,
                  label: 'Close',
                  onPressed: () => _selectTime(context, false, isWeekday),
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton({
    required TimeOfDay? time,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time != null ? _formatTime(time) : 'Set Time',
                style: TextStyle(
                  fontSize: 13,
                  color: time != null ? Colors.black87 : Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepTitles = [
      'Basic Info',
      'Sports',
      'Hours & Location',
      'Amenities',
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Header with steps
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 24),
                      color: Colors.grey.shade600,
                    ),
                    const Text(
                      'Register Club',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.help_outline_rounded, size: 24),
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Step indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (index) {
                    final isActive = index <= _currentStep;
                    final isCurrent = index == _currentStep;

                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? Colors.teal.shade600
                                  : Colors.grey.shade300,
                              border: isCurrent
                                  ? Border.all(
                                      color: Colors.teal.shade400,
                                      width: 3,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            stepTitles[index],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Colors.teal.shade700
                                  : Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / 4,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(Colors.teal.shade600),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),

          // Form content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(key: _formKey, child: _buildStepContent()),
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _currentStep--;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_back_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_currentStep < 3) {
                              setState(() {
                                _currentStep++;
                              });
                            } else {
                              _submitForm();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentStep == 3
                          ? Colors.green.shade600
                          : Colors.teal.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSubmitting)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          Text(
                            _currentStep == 3
                                ? (_isSubmitting
                                      ? 'Submitting...'
                                      : 'Submit Registration')
                                : 'Continue',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (_currentStep < 3 && !_isSubmitting)
                          const Row(
                            children: [
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
