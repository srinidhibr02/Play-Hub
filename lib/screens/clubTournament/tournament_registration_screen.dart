import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class TournamentRegistrationScreen extends StatefulWidget {
  final String tournamentId;
  final String category; // e.g., "maleDoubles", "femaleSingles"
  final num entryFee;
  final String tournamentName;

  const TournamentRegistrationScreen({
    super.key,
    required this.tournamentId,
    required this.category,
    required this.entryFee,
    required this.tournamentName,
  });

  @override
  State<TournamentRegistrationScreen> createState() =>
      _TournamentRegistrationScreenState();
}

class _TournamentRegistrationScreenState
    extends State<TournamentRegistrationScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  late Razorpay _razorpay;

  // Form Controllers
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _participantController;

  bool isSubmitting = false;
  late num bookingFee;
  late List<String> participants;
  late int maxParticipants;
  String? registrationId;
  String? paymentId;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _participantController = TextEditingController();

    // Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // Calculate booking fee (5% of entry fee)
    bookingFee = widget.entryFee * 0.05;

    // Initialize participants list
    participants = [];

    // Set max participants based on category
    maxParticipants = widget.category.toLowerCase().contains('singles') ? 1 : 2;

    // Pre-fill user data if available
    _prefillUserData();
  }

  Future<void> _prefillUserData() async {
    try {
      final user = _authService.currentUser;
      final userData = await _authService.getCurrentUserData();

      setState(() {
        _fullNameController.text =
            userData?['fullName'] ?? user?.displayName ?? '';
        _phoneController.text = userData?['phoneNumber'] ?? '';
      });
    } catch (e) {
      debugPrint('Error prefilling user data: $e');
    }
  }

  void _addParticipant(String name) {
    if (name.trim().isEmpty) {
      _showErrorSnackBar('Participant name cannot be empty');
      return;
    }

    if (participants.contains(name.trim().toUpperCase())) {
      _showErrorSnackBar('This participant is already added');
      return;
    }

    if (participants.length >= maxParticipants) {
      _showErrorSnackBar(
        'Maximum $maxParticipants participant${maxParticipants > 1 ? 's' : ''} allowed for this category',
      );
      return;
    }

    setState(() {
      participants.add(name.trim().toUpperCase());
    });
    _participantController.clear();
    _showSuccessSnackBar('Participant added successfully!');
  }

  void _removeParticipant(String name) {
    setState(() {
      participants.remove(name);
    });
    _showSuccessSnackBar('Participant removed');
  }

  Future<void> _createRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (participants.isEmpty) {
      _showErrorSnackBar('Please add at least one participant');
      return;
    }

    if (participants.length < maxParticipants && maxParticipants == 2) {
      _showErrorSnackBar(
        'Please add $maxParticipants participants for doubles',
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final userId = _authService.currentUserEmailId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create registration document with pending status
      final registrationRef = _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('registrations')
          .doc();

      registrationId = registrationRef.id;

      await registrationRef.set({
        'booking': bookingFee,
        'category': widget.category,
        'fullName': _fullNameController.text.trim(),
        'participants': participants,
        'paymentId': '',
        'phoneNumber': _phoneController.text.trim(),
        'registeredAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'userId': userId,
      });

      setState(() => isSubmitting = false);

      // Proceed to payment
      _initiatePayment();
    } catch (e) {
      setState(() => isSubmitting = false);
      _showErrorSnackBar('Failed to create registration: $e');
    }
  }

  void _initiatePayment() {
    try {
      final options = {
        'key': 'rzp_live_S1intCExDSf19z', // Replace with your Razorpay Key ID
        'amount': (bookingFee * 100).toInt(), // Amount in paise
        'name': widget.tournamentName,
        'description':
            'Tournament Registration - ${_formatCategory(widget.category)}',
        'prefill': {
          'contact': _phoneController.text.trim(),
          'email': _authService.currentUser?.email ?? '',
          'name': _fullNameController.text.trim(),
        },
        'notes': {
          'tournamentId': widget.tournamentId,
          'registrationId': registrationId,
          'category': widget.category,
        },
      };

      _razorpay.open(options);
    } catch (e) {
      _showErrorSnackBar('Failed to initiate payment: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    paymentId = response.paymentId;
    debugPrint('Payment Success: ${response.paymentId}');

    // Update registration with payment ID and mark as confirmed
    try {
      await _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('registrations')
          .doc(registrationId)
          .update({
            'paymentId': paymentId,
            'status': 'confirmed',
            'paymentCompletedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      // Show booking confirmation screen
      _showBookingConfirmation();
    } catch (e) {
      _showErrorSnackBar('Failed to update payment details: $e');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment Error: ${response.code} - ${response.message}');
    _showErrorSnackBar('Payment failed: ${response.message}');

    // Delete the pending registration
    _firestore
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('registrations')
        .doc(registrationId)
        .delete();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External Wallet: ${response.walletName}');
  }

  void _showBookingConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BookingConfirmationDialog(
        tournamentName: widget.tournamentName,
        category: _formatCategory(widget.category),
        fullName: _fullNameController.text.trim(),
        participants: participants,
        bookingFee: bookingFee,
        entryFee: widget.entryFee,
        registrationId: registrationId ?? '',
        paymentId: paymentId ?? '',
        onConfirm: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tournament Info Card with Enhanced Design
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade600, Colors.teal.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tournamentName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Category',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCategory(widget.category),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Entry Fee',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${widget.entryFee.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Personal Information Section
              _buildSectionTitle('Personal Information'),
              const SizedBox(height: 12),

              // Full Name Field
              _buildTextFormField(
                controller: _fullNameController,
                label: 'Full Name',
                hint: 'Enter your full name',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Number Field
              _buildTextFormField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: 'Enter your phone number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length != 10) {
                    return 'Phone number must be 10 digits';
                  }
                  if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                    return 'Phone number must contain only digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Participants Section
              _buildSectionTitle('Participants'),
              const SizedBox(height: 12),

              // Participant Input with Add Button
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _participantController,
                      decoration: InputDecoration(
                        hintText: 'First & Last Name',
                        prefixIcon: const Icon(Icons.person_add),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.teal.shade700,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onFieldSubmitted: (value) {
                        _addParticipant(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.teal.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () {
                        _addParticipant(_participantController.text);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Added Participants List
              if (participants.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Added Participants',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${participants.length}/$maxParticipants',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...participants.asMap().entries.map((entry) {
                      final index = entry.key;
                      final participant = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade700,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    participant,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => _removeParticipant(participant),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.red.shade600,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 20),
                  ],
                ),

              // Booking Fee Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade100, Colors.amber.shade100],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade300, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pay ₹${bookingFee.toStringAsFixed(2)} to confirm your slot',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '(Non-refundable)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pay ₹${widget.entryFee.toStringAsFixed(0)} at venue',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${bookingFee.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _createRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    disabledBackgroundColor: Colors.grey.shade400,
                    elevation: 0,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Proceed to Payment',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade900,
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  String _formatCategory(String category) {
    return category
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _participantController.dispose();
    _razorpay.clear();
    super.dispose();
  }
}

// Booking Confirmation Dialog
class BookingConfirmationDialog extends StatelessWidget {
  final String tournamentName;
  final String category;
  final String fullName;
  final List<String> participants;
  final num bookingFee;
  final num entryFee;
  final String registrationId;
  final String paymentId;
  final VoidCallback onConfirm;

  const BookingConfirmationDialog({
    super.key,
    required this.tournamentName,
    required this.category,
    required this.fullName,
    required this.participants,
    required this.bookingFee,
    required this.entryFee,
    required this.registrationId,
    required this.paymentId,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.green.shade800],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 50,
                      color: Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Payment Successful!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your spot is confirmed',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tournament Details
                  _buildDetailCard(
                    title: 'Tournament Details',
                    children: [
                      _buildDetailRow('Tournament', tournamentName),
                      const SizedBox(height: 12),
                      _buildDetailRow('Category', category),
                      const SizedBox(height: 12),
                      _buildDetailRow('Organizer', fullName),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Participants
                  _buildDetailCard(
                    title: 'Participants',
                    children: [
                      ...participants.asMap().entries.map((entry) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key < participants.length - 1 ? 8 : 0,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                entry.value,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Payment Details
                  _buildDetailCard(
                    title: 'Payment Details',
                    children: [
                      _buildDetailRow(
                        'Booking Fee Paid',
                        '₹${bookingFee.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Pending at Venue',
                        '₹${entryFee.toStringAsFixed(0)}',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Payment ID',
                        paymentId,
                        isMonospace: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Registration ID
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registration ID',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          registrationId,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Divider(height: 1, color: Colors.grey.shade300),

            // Action Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isMonospace = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: isMonospace ? 'Courier' : null,
              letterSpacing: isMonospace ? 0.3 : 0,
            ),
          ),
        ),
      ],
    );
  }
}
