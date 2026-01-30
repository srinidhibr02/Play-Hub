import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class TournamentRegistrationScreen extends StatefulWidget {
  final String tournamentId;
  final String category;
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
    extends State<TournamentRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  late Razorpay _razorpay;
  late AnimationController _animationController;

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
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _participantController = TextEditingController();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    bookingFee = widget.entryFee * 0.05;
    participants = [];
    maxParticipants = widget.category.toLowerCase().contains('singles') ? 1 : 2;

    _prefillUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _participantController.dispose();
    _razorpay.clear();
    _animationController.dispose();
    super.dispose();
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
        'Maximum $maxParticipants participant${maxParticipants > 1 ? 's' : ''} allowed',
      );
      return;
    }

    setState(() {
      participants.add(name.trim().toUpperCase());
    });
    _participantController.clear();
    _showSuccessSnackBar('Participant added!');
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
      _initiatePayment();
    } catch (e) {
      setState(() => isSubmitting = false);
      _showErrorSnackBar('Failed to create registration: $e');
    }
  }

  void _initiatePayment() {
    try {
      final options = {
        'key': 'rzp_live_S1intCExDSf19z',
        'amount': (bookingFee * 100).toInt(),
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
      _showBookingConfirmation();
    } catch (e) {
      _showErrorSnackBar('Failed to update payment details: $e');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment Error: ${response.code} - ${response.message}');
    _showErrorSnackBar('Payment failed: ${response.message}');

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
        title: const Text('Tournament Registration'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey.shade900,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tournament Info Card
              FadeTransition(
                opacity: _animationController,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade600, Colors.teal.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
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
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.tournamentName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              'Category',
                              _formatCategory(widget.category),
                              Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoItem(
                              'Entry Fee',
                              '₹${widget.entryFee.toStringAsFixed(0)}',
                              Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Personal Information Section
              _buildSectionHeader(
                'Personal Information',
                Icons.person_rounded,
                Colors.blue,
              ),
              const SizedBox(height: 16),

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

              _buildTextFormField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: 'Enter your 10-digit phone number',
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

              const SizedBox(height: 32),

              // Participants Section
              _buildSectionHeader(
                'Add Participants',
                Icons.group_rounded,
                Colors.purple,
              ),
              const SizedBox(height: 8),
              Text(
                maxParticipants == 2
                    ? 'Add 2 participants for doubles'
                    : 'Add your name to confirm participation',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _participantController,
                      decoration: InputDecoration(
                        hintText: 'First & Last Name',
                        prefixIcon: Icon(
                          Icons.person_add_rounded,
                          color: Colors.grey.shade400,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.purple.shade700,
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
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade600,
                          Colors.purple.shade700,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      onPressed: () {
                        _addParticipant(_participantController.text);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (participants.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Participants Added',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${participants.length}/$maxParticipants',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.purple.shade700,
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
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade50,
                                Colors.green.shade100,
                              ],
                            ),
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
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.shade700,
                                          Colors.green.shade600,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    participant,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => _removeParticipant(participant),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
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
                    const SizedBox(height: 24),
                  ],
                ),

              // Payment Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade50, Colors.orange.shade50],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade300, width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.payment_rounded,
                                color: Colors.orange.shade600,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Booking Fee',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '(Pay now to confirm)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '₹${bookingFee.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    Divider(color: Colors.orange.shade300, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remaining at Venue',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '(Pay on tournament day)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₹${widget.entryFee.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    Divider(color: Colors.orange.shade300, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Entry Fee',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        Text(
                          '₹${(bookingFee + widget.entryFee).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  elevation: 8,
                  shadowColor: Colors.teal.withOpacity(0.4),
                  child: InkWell(
                    onTap: isSubmitting ? null : _createRegistration,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSubmitting
                              ? [Colors.grey.shade400, Colors.grey.shade500]
                              : [Colors.teal.shade600, Colors.teal.shade700],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isSubmitting)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white.withOpacity(0.8),
                                strokeWidth: 2.5,
                              ),
                            )
                          else
                            const Icon(
                              Icons.payment_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          const SizedBox(width: 12),
                          Text(
                            isSubmitting
                                ? 'Processing...'
                                : 'Proceed to Payment',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textColor.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.blue.shade600, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
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
}

// Modern Booking Confirmation Dialog
class BookingConfirmationDialog extends StatefulWidget {
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
  State<BookingConfirmationDialog> createState() =>
      _BookingConfirmationDialogState();
}

class _BookingConfirmationDialogState extends State<BookingConfirmationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.green.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0, end: 1).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Curves.elasticOut,
                      ),
                    ),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade600.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 50,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Payment Successful!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your registration is confirmed',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection(
                    'Tournament Details',
                    Icons.emoji_events_rounded,
                    Colors.teal,
                    [
                      _buildDetailRow('Tournament', widget.tournamentName),
                      const SizedBox(height: 12),
                      _buildDetailRow('Category', widget.category),
                      const SizedBox(height: 12),
                      _buildDetailRow('Organizer', widget.fullName),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildDetailSection(
                    'Participants',
                    Icons.group_rounded,
                    Colors.purple,
                    [
                      ...widget.participants.asMap().entries.map((entry) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key < widget.participants.length - 1
                                ? 10
                                : 0,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.purple.shade600,
                                      Colors.purple.shade500,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildDetailSection(
                    'Payment Details',
                    Icons.payment_rounded,
                    Colors.orange,
                    [
                      _buildDetailRow(
                        'Booking Fee Paid',
                        '₹${widget.bookingFee.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Pending at Venue',
                        '₹${widget.entryFee.toStringAsFixed(0)}',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Total',
                        '₹${(widget.bookingFee + widget.entryFee).toStringAsFixed(0)}',
                        isBold: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildIdBox(
                    'Registration ID',
                    widget.registrationId,
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildIdBox('Payment ID', widget.paymentId, Colors.teal),
                ],
              ),
            ),

            Divider(height: 1, color: Colors.grey.shade300),

            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: Material(
                  borderRadius: BorderRadius.circular(14),
                  elevation: 4,
                  shadowColor: Colors.teal.withOpacity(0.3),
                  child: InkWell(
                    onTap: widget.onConfirm,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal.shade600, Colors.teal.shade700],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
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

  Widget _buildDetailSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? Colors.teal.shade700 : Colors.grey.shade900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(0.8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
