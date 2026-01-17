import 'package:flutter/material.dart';
import 'package:play_hub/screens/tabs/clubs_page.dart';
import 'package:play_hub/screens/tabs/home_page.dart';
import 'package:play_hub/screens/tabs/profile_screen.dart';
import 'package:play_hub/screens/tabs/bookings_page.dart';
import 'package:play_hub/service/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final _userEmailId = AuthService().currentUserEmailId;
  int _selectedIndex = 0;
  late PageController _pageController;
  late AnimationController _indicatorController;
  late Animation<double> _indicatorAnimation;

  // ✅ NESTED NAVIGATOR KEYS - NEW
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  final List<String> _tabLabels = ['Home', 'Bookings', 'Clubs', 'Profile'];
  final List<IconData> _inactiveIcons = [
    Icons.home_outlined,
    Icons.book_outlined,
    Icons.groups_outlined,
    Icons.person_outline,
  ];
  final List<IconData> _activeIcons = [
    Icons.home,
    Icons.book,
    Icons.groups,
    Icons.person,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _indicatorController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _indicatorAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _indicatorController, curve: Curves.easeInOut),
    );
    _indicatorController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _indicatorController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _indicatorController.forward();
  }

  // ✅ UPDATED - Pop to root + switch tabs
  void _onTabTapped(int index) {
    if (_selectedIndex == index) {
      // Pop to root screen if already on this tab
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: _onPageChanged,
        children: [
          // ✅ NESTED NAVIGATORS FOR EACH TAB
          Navigator(
            key: _navigatorKeys[0],
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) => const HomeScreen(),
              settings: settings,
            ),
          ),
          Navigator(
            key: _navigatorKeys[1],
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) =>
                  BookingsScreen(userId: _userEmailId as String),
              settings: settings,
            ),
          ),
          Navigator(
            key: _navigatorKeys[2],
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) => const ClubsScreen(),
              settings: settings,
            ),
          ),
          Navigator(
            key: _navigatorKeys[3],
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) => ProfileScreen(),
              settings: settings,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  Widget _buildCustomBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ANIMATED SLIDER INDICATOR
            AnimatedBuilder(
              animation: _indicatorAnimation,
              builder: (context, child) {
                final double width = MediaQuery.of(context).size.width / 4;
                final double offset =
                    (_selectedIndex * width) +
                    (width * _indicatorAnimation.value * 0.1);

                return Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Positioned(
                      left: offset,
                      top: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: width * 0.6,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade700,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.shade700.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Bottom Nav Items
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(4, (index) {
                final isActive = _selectedIndex == index;
                return GestureDetector(
                  onTap: () => _onTabTapped(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? _activeIcons[index] : _inactiveIcons[index],
                        color: isActive
                            ? Colors.teal.shade700
                            : Colors.grey.shade600,
                        size: isActive ? 26 : 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tabLabels[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isActive
                              ? Colors.teal.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
