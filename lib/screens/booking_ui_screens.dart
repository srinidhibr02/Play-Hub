import 'package:flutter/material.dart';
import 'package:play_hub/screens/booking/club_screen.dart';

class SelectSportScreen extends StatelessWidget {
  SelectSportScreen({super.key});

  final List<Map<String, dynamic>> sports = [
    {
      'name': 'Badminton',
      'icon': Icons.sports_tennis,
      'color': Colors.red,
      'image': 'images/badminton_player.png',
    },
    {
      'name': 'Cricket',
      'icon': Icons.sports_cricket,
      'color': Colors.green,
      'image': 'images/cricket_player.png',
    },
    {
      'name': 'Football',
      'icon': Icons.sports_soccer,
      'color': Colors.blue,
      'image': 'images/soccer_player.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Sport'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade700, Colors.white],
            stops: const [0, 0.5],
          ),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: sports.length,
          itemBuilder: (context, index) {
            final sport = sports[index];
            return _buildSportCard(
              context,
              sport['name'],
              sport['icon'],
              sport['color'],
              sport['image'],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSportCard(
    BuildContext context,
    String name,
    IconData icon,
    Color color,
    String image,
  ) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      shadowColor: color.withOpacity(0.4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SelectClubScreen(sport: name)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.8), color],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Optional: an overlay with sport image
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    image,
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.18),
                    colorBlendMode: BlendMode.darken,
                  ),
                ),
              ),
              // Content with background blur/shadow
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,

                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon with lighter background
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 32, color: Colors.white),
                      ),
                      const SizedBox(height: 80),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 3,
                              color: Colors.black54,
                              offset: Offset(1, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Book Now',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(
                              blurRadius: 2,
                              color: Colors.black45,
                              offset: Offset(1, 2),
                            ),
                          ],
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
    );
  }
}
