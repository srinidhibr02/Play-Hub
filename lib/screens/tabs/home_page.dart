import 'dart:ffi';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/models.dart';
import 'package:play_hub/screens/booking/club_screen.dart';
import 'package:play_hub/screens/booking_ui_screens.dart';
import 'package:play_hub/screens/tabs/clubs_page.dart';
import 'package:play_hub/screens/tabs/profile_screen.dart';
import 'package:play_hub/screens/tournament/tournament_setup_screen.dart';
import 'package:play_hub/screens/tournament_screen.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/widgets/my_bookings_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // ✅ SAFE BACK - Uses current context navigator
          Navigator.maybePop(context);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Colors.teal.shade50, Colors.white],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 24),
                    _buildWelcomeCard(),
                    const SizedBox(height: 24),
                    _buildQuickActions(context),
                    const SizedBox(height: 24),
                    _buildSportsCategories(context),
                    const SizedBox(height: 24),
                    _buildUpcomingEvents(context),
                    const SizedBox(height: 24),
                    MyBookingsWidget(
                      userId: _authService.currentUserEmailId as String,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ SIMPLIFIED SAFE NAVIGATION - Works with nested navigator
  void _navigateTo(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello 👋 \n${_authService.currentUser!.displayName}",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade900,
                  fontSize: 24,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Let\'s play some sports today',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => _navigateTo(ProfileScreen()), // ✅ FIXED
          borderRadius: BorderRadius.circular(50),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.teal.shade200, width: 2),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.teal.shade100,
              backgroundImage:
                  (_authService.currentUser?.photoURL != null &&
                      _authService.currentUser!.photoURL!.isNotEmpty)
                  ? NetworkImage(_authService.currentUser!.photoURL!)
                  : const AssetImage('images/default_avatar.png')
                        as ImageProvider,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.teal.shade800],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade300.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Play Hub Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Get unlimited access to all tournaments and exclusive benefits',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Currently Everything is Free'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.teal.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Upgrade Now',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.workspace_premium, size: 80, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade900,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.event_available,
                title: 'Book Slot',
                color: Colors.blue,
                onTap: () => _navigateTo(SelectSportScreen()), // ✅ FIXED
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildActionCard(
                icon: Icons.people_alt,
                title: 'Join Club',
                color: Colors.purple,
                onTap: () => _navigateTo(const ClubsScreen()), // ✅ FIXED
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_circle_outline,
                title: 'Create Event',
                color: Colors.orange,
                onTap: () =>
                    _navigateTo(const TournamentSetupScreen()), // ✅ FIXED
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportsCategories(BuildContext context) {
    final sports = [
      {
        'name': 'Badminton',
        'image': 'images/badminton_player.png',
        'color': Colors.red.shade300,
      },
      {
        'name': 'Cricket',
        'image': 'images/cricket_player.png',
        'color': Colors.green.shade300,
      },
      {
        'name': 'Gym',
        'image': 'images/gym_player.png',
        'color': Colors.pinkAccent.shade200,
      },
      {
        'name': 'Football',
        'image': 'images/soccer_player.png',
        'color': Colors.blue.shade300,
      },
      {
        'name': 'Swimming',
        'image': 'images/swimming_player.png',
        'color': Colors.lightBlueAccent.shade400,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sports',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade900,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 120,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: sports.length,
            itemBuilder: (context, index) {
              final sport = sports[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  image: DecorationImage(
                    image: AssetImage(sport['image'] as String),
                    fit: BoxFit.fill,
                    colorFilter: ColorFilter.mode(
                      (sport['color'] as Color).withOpacity(0.6),
                      BlendMode.darken,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (sport['color'] as Color).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _navigateTo(
                      // ✅ FIXED
                      SelectClubScreen(sport: sport['name'] as String),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          sport['name'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black54,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingEvents(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .where('status', isEqualTo: 'open')
          .limit(2)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: Colors.teal)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final tournaments = snapshot.data!.docs
            .map(
              (doc) => Tournament.fromMap(doc.data() as Map<String, dynamic>),
            )
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Tournaments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                    fontSize: 22,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TournamentScreen()),
                  ),
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  label: Text(
                    'View All',
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Real tournament cards from Firestore
            ...tournaments.map(
              (tournament) => _buildEventCard(
                title: tournament.name,
                date: tournament.date != null
                    ? DateFormat('MMM d, yyyy').format(tournament.date!)
                    : 'TBD',
                prizePool: tournament.prizePool as double,
                participants:
                    '${tournament.currentParticipants ?? 0}/${tournament.maxParticipants ?? 0}',
                sport: tournament.sport ?? 'Badminton',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEventCard({
    required String title,
    required String date,
    required double prizePool,
    required String participants,
    required String sport,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sport,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 15, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                date,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 18),
              Icon(Icons.currency_rupee, size: 15, color: Colors.grey.shade600),
              Expanded(
                child: Text(
                  '$prizePool',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      participants,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Register',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
