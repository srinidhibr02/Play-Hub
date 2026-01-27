import 'package:flutter/material.dart';
import 'package:play_hub/screens/auth_screen.dart';
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
  final _authService = AuthService();
  late String? _userEmailId;
  int _selectedIndex = 0;
  late PageController _pageController;
  late AnimationController _indicatorController;
  late Animation<double> _indicatorAnimation;

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
    _userEmailId = _authService.currentUserEmailId;
    _pageController = PageController(initialPage: _selectedIndex);
    _indicatorController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _indicatorAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _indicatorController, curve: Curves.easeInOut),
    );
    _indicatorController.forward();

    // Listen for auth state changes
    _authService.authStateChanges.listen((user) {
      setState(() {
        _userEmailId = _authService.currentUserEmailId;
      });

      // If user logs out, navigate them out of this page
      if (user == null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const AuthPage()),
        );
      }
    });
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

  // Handle device back button
  Future<bool> _onWillPop() async {
    final NavigatorState? navigator =
        _navigatorKeys[_selectedIndex].currentState;

    if (navigator == null) return true;

    // Check if there are routes to pop in current navigator
    if (navigator.canPop()) {
      navigator.pop();
      return false; // Prevent app from closing
    }

    // If we're on home tab and no routes to pop, allow exit
    if (_selectedIndex == 0) {
      return true; // Close app
    }

    // Otherwise, go back to home tab
    _onTabTapped(0);
    return false; // Prevent app from closing
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is authenticated
    bool isUserAuthenticated = _userEmailId != null && _userEmailId!.isNotEmpty;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: _onPageChanged,
          children: [
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
        // Only show bottom nav if user is authenticated
        bottomNavigationBar: isUserAuthenticated
            ? _buildCustomBottomNav()
            : null,
      ),
    );
  }

  Widget _buildCustomBottomNav() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: 35,
            vertical: bottomPadding > 0 ? 12 : 35,
          ),
          margin: EdgeInsets.only(bottom: bottomPadding > 0 ? 0 : 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ANIMATED SLIDER INDICATOR
              AnimatedBuilder(
                animation: _indicatorAnimation,
                builder: (context, child) {
                  final double width =
                      (MediaQuery.of(context).size.width - 70) / 4;
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
                          width: width * 0.8,
                          height: 4,
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
              const SizedBox(height: 15),

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
                          isActive
                              ? _activeIcons[index]
                              : _inactiveIcons[index],
                          color: isActive
                              ? Colors.teal.shade700
                              : Colors.grey.shade600,
                          size: isActive ? 26 : 24,
                        ),
                        SizedBox(height: bottomPadding > 0 ? 2 : 4),
                        Text(
                          _tabLabels[index],
                          style: TextStyle(
                            fontSize: bottomPadding > 0 ? 11 : 12,
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
      ),
    );
  }
}
