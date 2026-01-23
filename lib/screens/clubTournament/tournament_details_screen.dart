import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/service/auth_service.dart';

class TournamentDetailsScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentDetailsScreen({super.key, required this.tournamentId});

  @override
  State<TournamentDetailsScreen> createState() =>
      _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends State<TournamentDetailsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();
  bool isRegistering = false;
  bool isUserRegistered = false;
  late String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _checkUserRegistration();
  }

  Future<void> _checkUserRegistration() async {
    try {
      final userId = _authService.currentUserEmailId;
      if (userId == null) return;

      final doc = await _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get();

      if (doc.exists) {
        final participants = List<String>.from(doc['participants'] ?? []);
        setState(() {
          isUserRegistered = participants.contains(userId);
        });
      }
    } catch (e) {
      debugPrint('Error checking registration: $e');
    }
  }

  Future<void> _registerForTournament() async {
    final userId = _authService.currentUserEmailId;
    if (userId == null) {
      _showSnackBar('Please login to register', isError: true);
      return;
    }

    setState(() => isRegistering = true);

    try {
      await _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({
            'participants': FieldValue.arrayUnion([userId]),
            'currentParticipants': FieldValue.increment(1),
          });

      setState(() {
        isUserRegistered = true;
        isRegistering = false;
      });

      _showSnackBar('Successfully registered for tournament!');
    } catch (e) {
      setState(() => isRegistering = false);
      _showSnackBar('Registration failed: $e', isError: true);
    }
  }

  Future<void> _unregisterFromTournament() async {
    final userId = _authService.currentUserEmailId;
    if (userId == null) return;

    setState(() => isRegistering = true);

    try {
      await _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({
            'participants': FieldValue.arrayRemove([userId]),
            'currentParticipants': FieldValue.increment(-1),
          });

      setState(() {
        isUserRegistered = false;
        isRegistering = false;
      });

      _showSnackBar('Unregistered from tournament');
    } catch (e) {
      setState(() => isRegistering = false);
      _showSnackBar('Unregistration failed: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .snapshots(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.teal.shade700),
            ),
          );
        }

        // Not found
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament Details')),
            body: const Center(child: Text('Tournament not found')),
          );
        }

        // ✅ Parse tournament data with new schema
        final tournament = snapshot.data!.data() as Map<String, dynamic>;
        final status = tournament['status'] as String;
        final sport = tournament['sport'] as String;
        final name = tournament['name'] as String;
        final organizer = tournament['organizer'] as String;
        final description = tournament['description'] as String;

        // New: entryFee has mixed structure - some are maps (Female, male), some are direct values (Mixed-Doubles)
        final entryFeeMap =
            tournament['entryFee'] as Map<String, dynamic>? ?? {};

        // Separate nested categories (Female, male) from direct event types (Mixed-Doubles)
        final Map<String, Map<String, num>> categoryFees = {}; // Female, male
        final Map<String, num> directEventFees = {}; // Mixed-Doubles, etc

        entryFeeMap.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            // This is a category (Female, male) with nested events
            categoryFees[key] = value.cast<String, num>();
          } else if (value is num) {
            // This is a direct event type (Mixed-Doubles)
            directEventFees[key] = value;
          }
        });

        // Get all unique event types from both categories and direct events
        final Set<String> allEventTypes = {};
        categoryFees.values.forEach((catFees) {
          allEventTypes.addAll(catFees.keys);
        });
        allEventTypes.addAll(directEventFees.keys);

        // State variable for selected category
        late String selectedCategory;
        if (categoryFees.isNotEmpty) {
          selectedCategory = _selectedCategory.isEmpty
              ? categoryFees.keys.first
              : _selectedCategory;
        }

        final prizePool = tournament['prizePool'] as num;
        final currentParticipants = tournament['currentParticipants'] as num;
        final maxParticipants = tournament['maxParticipants'] as num;
        final imageUrl = tournament['imageUrl'] as String;
        final rules = List<String>.from(tournament['rules'] ?? []);
        final contactNumber = tournament['contactNumber'] as String;
        final registrationDeadline =
            (tournament['registrationDeadline'] as Timestamp).toDate();

        // ✅ Calculate states
        final isRegistrationOpen =
            status == 'open' && DateTime.now().isBefore(registrationDeadline);
        final isFull = currentParticipants >= maxParticipants;

        // ✅ RETURN Scaffold INSIDE StreamBuilder
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // App Bar with Image
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                backgroundColor: Colors.teal.shade700,
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tournament Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade100,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            sport,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.teal.shade700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'open'
                                                ? Colors.green.shade100
                                                : Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: status == 'open'
                                                  ? Colors.green.shade700
                                                  : Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Organized by $organizer',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Stats Cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildStatCard(
                            '₹${categoryFees.isNotEmpty && categoryFees[selectedCategory]?.isNotEmpty == true
                                ? categoryFees[selectedCategory]!.values.reduce(math.min).toStringAsFixed(0)
                                : [...categoryFees.values.where((fees) => fees.isNotEmpty).map((fees) => fees.values.reduce(math.min)), ...directEventFees.values].isNotEmpty
                                ? [...categoryFees.values.where((fees) => fees.isNotEmpty).map((fees) => fees.values.reduce(math.min)), ...directEventFees.values].reduce(math.min).toStringAsFixed(0)
                                : '0'}',

                            'Starting From',
                            Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            '₹${prizePool.toStringAsFixed(0)}',
                            'Prize Pool',
                            Colors.purple,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            '${currentParticipants.toInt()}/${maxParticipants.toInt()}',
                            'Participants',
                            Colors.orange,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Available Event Types with Category Selector
                    if (allEventTypes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Selector (if multiple categories available)
                            if (categoryFees.isNotEmpty &&
                                categoryFees.length > 1)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Category',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: categoryFees.keys.map((category) {
                                      final isSelected =
                                          selectedCategory == category;
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedCategory = category;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.teal.shade700
                                                : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.teal.shade700
                                                  : Colors.grey.shade300,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            category[0].toUpperCase() +
                                                category.substring(1),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),

                            Text(
                              'Available Event Types',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: allEventTypes.map((eventType) {
                                // Get fee from selected category or direct event fees
                                num? fee;
                                if (categoryFees.containsKey(
                                  selectedCategory,
                                )) {
                                  fee =
                                      categoryFees[selectedCategory]![eventType];
                                }
                                fee ??= directEventFees[eventType];

                                // Skip if fee is not found
                                if (fee == null) return SizedBox.shrink();

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.purple.shade50,
                                        Colors.purple.shade100,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.purple.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        eventType,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.purple.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${fee.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Registration Deadline
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildInfoCard(
                        title: 'Registration Deadline',
                        content: DateFormat(
                          'MMM dd, yyyy • hh:mm a',
                        ).format(registrationDeadline),
                        icon: Icons.calendar_today_rounded,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Rules
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tournament Rules',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...rules
                              .asMap()
                              .entries
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${entry.key + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          entry.value,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Contact Info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildInfoCard(
                        title: 'Contact',
                        content: contactNumber,
                        icon: Icons.phone_rounded,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
          // ✅ FAB NOW WORKS - Variables in scope!
          floatingActionButton: _buildRegistrationButton(
            isRegistrationOpen,
            isFull,
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
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
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationButton(bool isRegistrationOpen, bool isFull) {
    bool canRegister = isRegistrationOpen && !isFull && !isUserRegistered;
    bool canUnregister = isUserRegistered && isRegistrationOpen;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (canUnregister)
            Expanded(
              child: ElevatedButton(
                onPressed: isRegistering ? null : _unregisterFromTournament,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: isRegistering
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Unregister',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            )
          else
            Expanded(
              child: ElevatedButton(
                onPressed: canRegister && !isRegistering
                    ? _registerForTournament
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade400,
                  elevation: canRegister ? 4 : 0,
                ),
                child: isRegistering
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
                          const Icon(Icons.check_circle, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isFull
                                ? 'Tournament Full'
                                : !isRegistrationOpen
                                ? 'Registration Closed'
                                : 'Register Now',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
}
