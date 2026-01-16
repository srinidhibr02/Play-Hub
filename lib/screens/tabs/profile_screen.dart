import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:play_hub/screens/auth_screen.dart';
import 'package:play_hub/service/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  final AuthService _authService = AuthService();

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red.shade700),
            const SizedBox(width: 12),
            const Text(
              'Logout?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out? You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthPage()));
      }
    }
  }

  void _navigateToEditProfile(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Edit Profile - Coming Soon')));
  }

  void _navigateToAccountSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
    );
  }

  void _navigateToFAQ(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FAQScreen()),
    );
  }

  void _navigateToTerms(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsScreen()),
    );
  }

  void _navigateToPrivacy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  void _navigateToSupport(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Support - Coming Soon')));
  }

  void _navigateToAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Play Hub',
      applicationVersion: '1.0.0',
      applicationIcon: Image.asset(
        'images/whiteBGlogo.png',
        width: 64,
        height: 64,
      ),
      children: [
        const Text(
          'Manage your sports events efficiently with Play Hub. '
          'Create tournaments, join clubs, and connect with other sports enthusiasts.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('No user logged in'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthPage()),
                  );
                },
                child: const Text(
                  'Go to Login',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _authService.streamCurrentUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User data not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final fullName =
              data['fullName'] ?? currentUser.displayName ?? 'User';
          final email = data['email'] ?? currentUser.email ?? 'No Email';
          final phone = data['phoneNumber'] ?? 'Not provided';
          final role = data['role'] ?? 'User';
          final loginMethod = data['loginMethod'] ?? 'Unknown';
          final profileUrl =
              data['profileImageUrl'] ?? currentUser.photoURL ?? '';
          final createdAt = data['createdAt'] as Timestamp?;

          return CustomScrollView(
            slivers: [
              // Modern App Bar with Profile Header
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Colors.teal.shade700,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.teal.shade700, Colors.teal.shade900],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        // Profile Avatar with Edit Button
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 65,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: profileUrl.isNotEmpty
                                      ? NetworkImage(profileUrl)
                                      : null,
                                  child: profileUrl.isEmpty
                                      ? Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.grey.shade400,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _navigateToEditProfile(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 20,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // User Name
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Email
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Profile Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Account Information Card
                      _buildSectionCard(
                        title: 'Account Information',
                        icon: Icons.info_outline,
                        children: [
                          _buildInfoTile(
                            Icons.phone_outlined,
                            'Phone Number',
                            phone,
                          ),
                          _buildInfoTile(
                            Icons.login_outlined,
                            'Login Method',
                            loginMethod.toUpperCase(),
                          ),
                          _buildInfoTile(
                            Icons.calendar_today_outlined,
                            'Member Since',
                            createdAt != null
                                ? _formatDate(createdAt.toDate())
                                : 'Unknown',
                          ),
                          _buildInfoTile(
                            Icons.verified_user_outlined,
                            'Email Verified',
                            currentUser.emailVerified ? 'Yes' : 'No',
                            trailing: currentUser.emailVerified
                                ? Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade600,
                                    size: 20,
                                  )
                                : Icon(
                                    Icons.cancel,
                                    color: Colors.red.shade600,
                                    size: 20,
                                  ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Settings Section
                      _buildSectionCard(
                        title: 'Settings',
                        icon: Icons.settings_outlined,
                        children: [
                          _buildMenuTile(
                            Icons.edit_outlined,
                            'Edit Profile',
                            'Update your personal information',
                            () => _navigateToEditProfile(context),
                          ),
                          _buildDivider(),
                          _buildMenuTile(
                            Icons.lock_outline,
                            'Account Settings',
                            'Password, security & privacy',
                            () => _navigateToAccountSettings(context),
                          ),
                          _buildDivider(),
                          _buildMenuTile(
                            Icons.notifications_outlined,
                            'Notifications',
                            'Manage notification preferences',
                            () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming Soon')),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Help & Support Section
                      _buildSectionCard(
                        title: 'Help & Support',
                        icon: Icons.help_outline,
                        children: [
                          _buildMenuTile(
                            Icons.quiz_outlined,
                            'FAQ',
                            'Frequently asked questions',
                            () => _navigateToFAQ(context),
                          ),
                          _buildDivider(),
                          _buildMenuTile(
                            Icons.support_agent_outlined,
                            'Contact Support',
                            'Get help from our team',
                            () => _navigateToSupport(context),
                          ),
                          _buildDivider(),
                          _buildMenuTile(
                            Icons.rate_review_outlined,
                            'Rate App',
                            'Share your feedback',
                            () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming Soon')),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Legal Section
                      _buildSectionCard(
                        title: 'Legal',
                        icon: Icons.gavel_outlined,
                        children: [
                          _buildMenuTile(
                            Icons.description_outlined,
                            'Terms & Conditions',
                            'Read our terms of service',
                            () => _navigateToTerms(context),
                          ),
                          _buildDivider(),
                          _buildMenuTile(
                            Icons.privacy_tip_outlined,
                            'Privacy Policy',
                            'How we handle your data',
                            () => _navigateToPrivacy(context),
                          ),
                          _buildDivider(),
                          _buildMenuTile(
                            Icons.info_outlined,
                            'About',
                            'App version and information',
                            () => _navigateToAbout(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => _showLogoutDialog(context),
                          icon: const Icon(Icons.logout),
                          label: const Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Version Info
                      Center(
                        child: Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: Colors.teal.shade700, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.teal.shade700, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.teal.shade700, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Colors.grey.shade200),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// Account Settings Screen
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            subtitle: const Text('Update your password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to change password
            },
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Change Email'),
            subtitle: const Text('Update your email address'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to change email
            },
          ),
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Change Phone Number'),
            subtitle: const Text('Update your phone number'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to change phone
            },
          ),
          const Divider(height: 32),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red.shade600),
            title: Text(
              'Delete Account',
              style: TextStyle(color: Colors.red.shade600),
            ),
            subtitle: const Text('Permanently delete your account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Show delete confirmation
            },
          ),
        ],
      ),
    );
  }
}

// FAQ Screen
class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'question': 'How do I create a tournament?',
        'answer':
            'Go to the Tournaments tab, tap the + button, and fill in the tournament details including name, sport type, date, and location.',
      },
      {
        'question': 'How do I join a club?',
        'answer':
            'Browse clubs in the Clubs tab, select a club you\'re interested in, and tap the "Join Club" button.',
      },
      {
        'question': 'Can I edit my profile information?',
        'answer':
            'Yes! Go to Profile > Edit Profile to update your personal information, profile picture, and other details.',
      },
      {
        'question': 'How do I reset my password?',
        'answer':
            'On the login screen, tap "Forgot Password?", enter your email, and follow the instructions sent to your email.',
      },
      {
        'question': 'Is my data secure?',
        'answer':
            'Yes, we use industry-standard encryption and security measures to protect your data. Read our Privacy Policy for more details.',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Frequently Asked Questions'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              title: Text(
                faqs[index]['question']!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    faqs[index]['answer']!,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Terms & Conditions Screen
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms & Conditions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${DateTime.now().toString().split(' ')[0]}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Acceptance of Terms',
              'By accessing and using Play Hub, you accept and agree to be bound by the terms and conditions of this agreement.',
            ),
            _buildSection(
              '2. User Accounts',
              'You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account.',
            ),
            _buildSection(
              '3. User Content',
              'You retain all rights to the content you post on Play Hub. By posting content, you grant us a license to use, modify, and display that content.',
            ),
            _buildSection(
              '4. Prohibited Activities',
              'You may not use Play Hub for any illegal purposes or to violate any laws. Harassment, spam, and malicious activities are strictly prohibited.',
            ),
            _buildSection(
              '5. Termination',
              'We reserve the right to terminate or suspend your account at any time, without prior notice, for conduct that we believe violates these Terms.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Privacy Policy Screen
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${DateTime.now().toString().split(' ')[0]}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Information We Collect',
              'We collect information you provide directly to us, including name, email address, phone number, and profile information.',
            ),
            _buildSection(
              'How We Use Your Information',
              'We use your information to provide, maintain, and improve our services, communicate with you, and personalize your experience.',
            ),
            _buildSection(
              'Information Sharing',
              'We do not sell your personal information. We may share your information with service providers who assist us in operating our platform.',
            ),
            _buildSection(
              'Data Security',
              'We implement appropriate security measures to protect your personal information from unauthorized access, alteration, or destruction.',
            ),
            _buildSection(
              'Your Rights',
              'You have the right to access, update, or delete your personal information at any time through your account settings.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
