import 'package:flutter/material.dart';
import 'package:play_hub/screens/tournament/badminton/tournament_list_screen.dart';

class TournamentSetupScreen extends StatefulWidget {
  const TournamentSetupScreen({super.key});

  @override
  State<TournamentSetupScreen> createState() => _TournamentSetupScreenState();
}

class _TournamentSetupScreenState extends State<TournamentSetupScreen> {
  String? selectedSport;

  final List<Map<String, dynamic>> sports = [
    {
      'name': 'Badminton',
      'icon': Icons.sports_tennis,
      'color': Colors.orange,
      'gradient': [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
      'description': 'Singles, Doubles & Custom Events',
    },
    {
      'name': 'Cricket',
      'icon': Icons.sports_cricket,
      'color': Colors.green,
      'gradient': [Color(0xFF56AB2F), Color(0xFFA8E063)],
      'description': 'T20, ODI & Test Formats',
    },
    {
      'name': 'Football',
      'icon': Icons.sports_soccer,
      'color': Colors.blue,
      'gradient': [Color(0xFF2196F3), Color(0xFF00BCD4)],
      'description': 'League & Knockout Tournaments',
    },
  ];

  void _proceed() {
    if (selectedSport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a sport to continue'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (selectedSport == 'Badminton') {
      Navigator.push(
        context,
        // MaterialPageRoute(builder: (_) => BadmintonTournamentSetupScreen()),
        MaterialPageRoute(builder: (_) => TournamentListScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$selectedSport setup coming soon!'),
          backgroundColor: Colors.teal.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade700, Colors.teal.shade500, Colors.white],
            stops: [0.0, 0.3, 0.3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        const Spacer(),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Text(
                      'Create Tournament',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose your sport & play with your friends',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withAlpha((255 * 0.9).toInt()),
                      ),
                    ),
                  ],
                ),
              ),

              // Sports Cards Section
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Sport',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: sports.length,
                          itemBuilder: (context, index) {
                            final sport = sports[index];
                            final isSelected = sport['name'] == selectedSport;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedSport = sport['name'];
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: sport['gradient'],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: isSelected
                                      ? null
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color: sport['color'].withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      )
                                    else
                                      BoxShadow(
                                        color: Colors.black.withAlpha(
                                          (255 * 0.05).toInt(),
                                        ),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withAlpha(
                                                  (255 * 0.3).toInt(),
                                                )
                                              : sport['color'].withAlpha(
                                                  (255 * 0.1).toInt(),
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: Icon(
                                          sport['icon'],
                                          size: 32,
                                          color: isSelected
                                              ? Colors.white
                                              : sport['color'],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              sport['name'],
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.grey.shade800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              sport['description'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isSelected
                                                    ? Colors.white.withAlpha(
                                                        (255 * 0.9).toInt(),
                                                      )
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.check,
                                            color: sport['color'],
                                            size: 20,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Continue Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.05).toInt()),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: selectedSport == null ? null : _proceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedSport == null
                            ? Colors.grey.shade300
                            : Colors.teal.shade700,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: selectedSport == null ? 0 : 4,
                        shadowColor: Colors.teal.shade300,
                      ),
                      child: Text(
                        'Continue to Setup',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: selectedSport == null
                              ? Colors.grey.shade500
                              : Colors.white,
                        ),
                      ),
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
}
