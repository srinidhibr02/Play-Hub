import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/screens/clubTournament/tournament_creation_form.dart';

class HostTournamentScreen extends StatefulWidget {
  final String userEmail;

  const HostTournamentScreen({super.key, required this.userEmail});

  @override
  State<HostTournamentScreen> createState() => _HostTournamentScreenState();
}

class _HostTournamentScreenState extends State<HostTournamentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: _buildHostedTournamentsList(),
      floatingActionButton: _buildCreateTournamentFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Host Tournament',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade900,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Manage your tournaments',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostedTournamentsList() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(widget.userEmail).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildEmptyState();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final hostedTournaments = List<String>.from(
          userData?['hostedTournaments'] ?? [],
        );

        if (hostedTournaments.isEmpty) {
          return _buildEmptyState();
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchTournamentDetails(hostedTournaments),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final tournaments = snapshot.data ?? [];

            if (tournaments.isEmpty) {
              return _buildEmptyState();
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Text(
                        'Your Tournaments',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tournaments.length.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...tournaments.map(
                  (tournament) => _buildTournamentCard(tournament),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTournamentDetails(
    List<String> tournamentIds,
  ) async {
    List<Map<String, dynamic>> tournaments = [];

    for (String tournamentId in tournamentIds) {
      try {
        final doc = await _firestore
            .collection('tournaments')
            .doc(tournamentId)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          data['tournamentId'] = tournamentId;
          tournaments.add(data);
        }
      } catch (e) {
        debugPrint('Error fetching tournament $tournamentId: $e');
      }
    }

    return tournaments;
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              size: 48,
              color: Colors.teal.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading tournaments...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.teal.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Error loading tournaments',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_circle_outline_rounded,
              size: 56,
              color: Colors.teal.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Tournaments Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first tournament to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> tournament) {
    final name = tournament['name'] ?? 'Unnamed Tournament';
    final description = tournament['description'] ?? '';
    final organizer = tournament['organizer'] ?? 'Unknown';
    final sport = tournament['sport'] ?? 'Unknown';
    final clubId = tournament['clubId'] ?? '';
    final clubName = tournament['clubName'] ?? 'Unknown Club';
    final currentParticipants = tournament['currentParticipants'] ?? 0;
    final maxParticipants = tournament['maxParticipants'] ?? 0;
    final imageUrl = tournament['imageUrl'] ?? '';
    final date = tournament['date'];
    final tournamentId = tournament['tournamentId'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.08).toInt()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {
              debugPrint('Tapped tournament: $tournamentId');
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Section
                if (imageUrl.isNotEmpty)
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      image: DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                        onError: (error, stackTrace) {
                          debugPrint('Image load error: $error');
                        },
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Club Badge
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade600,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.withAlpha(
                                    (255 * 0.4).toInt(),
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  clubName.length > 15
                                      ? '${clubName.substring(0, 15)}...'
                                      : clubName,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Content Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tournament Name
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Description
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 12),

                      // Details Row
                      Row(
                        children: [
                          // Sport Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              sport,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Club ID Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.vpn_key_rounded,
                                  size: 10,
                                  color: Colors.purple.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  clubId.length > 8
                                      ? clubId.substring(0, 8)
                                      : clubId,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // Organizer
                          Expanded(
                            child: Text(
                              'By $organizer',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Date & Participants
                      Row(
                        children: [
                          // Date
                          if (date != null)
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      DateFormat(
                                        'MMM d, yyyy',
                                      ).format(date.toDate()),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Participants Progress
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.people_rounded,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$currentParticipants/$maxParticipants',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: maxParticipants > 0
                              ? currentParticipants / maxParticipants
                              : 0,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            Colors.teal.shade600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // Edit tournament
                              },
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.teal.shade600,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                foregroundColor: Colors.teal.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // View details
                              },
                              icon: const Icon(Icons.info_rounded, size: 18),
                              label: const Text('Details'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.grey.shade400,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                foregroundColor: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateTournamentFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        _showTournamentCreationForm();
      },
      backgroundColor: Colors.teal.shade700,
      foregroundColor: Colors.white,
      elevation: 8,
      highlightElevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.add_rounded, size: 24),
      label: const Text(
        'Create Tournament',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  void _showTournamentCreationForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _buildTournamentFormSheet(),
    );
  }

  Widget _buildTournamentFormSheet() {
    return TournamentCreationForm(
      userEmail: widget.userEmail,
      onTournamentCreated: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Tournament created successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      },
    );
  }
}
