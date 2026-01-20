import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:play_hub/screens/auth_screen.dart';
import 'package:play_hub/service/auth_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  final User user;

  const AccountSettingsScreen({super.key, required this.user});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  Future<void> _showLogoutDialog(BuildContext context) async {
    showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.92),
                Colors.grey.shade50.withOpacity(0.9),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 48,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🎨 Premium Icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade400,
                      Colors.amber.shade500,
                      Colors.amber.shade600,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.shade300.withOpacity(0.6),
                      blurRadius: 10,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 32),

              // 🎯 Primary Title
              const Text(
                'What would you like to do?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.8,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // 📝 Contextual Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.grey.shade700,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      const TextSpan(text: 'Choose '),
                      TextSpan(
                        text: 'Logout',
                        style: TextStyle(
                          color: Colors.amber.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' to sign out temporarily, or '),
                      TextSpan(
                        text: 'Delete Account',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text: ' to permanently remove everything.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 🚪 LOGOUT BUTTON - SEPARATE ROW
              SizedBox(
                width: double.infinity,

                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await AuthService().logout();
                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const AuthPage(),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: Container(
                    padding: const EdgeInsets.all(10),

                    child: Icon(Icons.logout_rounded, size: 24),
                  ),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,

                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteAccountDialog(context);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.delete_forever_outlined,
                        size: 24,
                        color: Colors.red.shade700,
                      ),
                    ),
                    label: const Text(
                      'Delete Account',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                'You can always sign back in',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Add this for actual delete functionality:
  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    // Your actual delete account implementation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final result = await AuthService().deleteAccount();
              print(result);
              if (result.success && mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AuthPage()),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            snap: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            title: const Text(
              'Account',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 28,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.teal.shade500,
                      Colors.teal.shade600,
                      Colors.teal.shade700,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${widget.user.email}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.white, Colors.grey.shade50],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade400, Colors.teal.shade600],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.shade200.withOpacity(0.6),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_circle_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.user.displayName ?? 'User'}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.user.email}',
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    context,
                    icon: Icons.lock_outline_rounded,
                    title: 'Password',
                    subtitle: 'Change your account password',
                    color: Colors.orange.shade500,
                    onTap: () {},
                  ),
                  const SizedBox(height: 20),
                  _buildSettingsTile(
                    context,
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: 'Update your email address',
                    color: Colors.teal.shade500,
                    onTap: () {},
                  ),
                  const SizedBox(height: 20),
                  _buildSettingsTile(
                    context,
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    subtitle: 'Update your phone number',
                    color: Colors.blue.shade500,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // 🚨 DELETE ACCOUNT SECTION (triggers logout)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFF2F2), Color(0xFFFFE8E8)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade100, Colors.red.shade50],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.red.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.red.shade700,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          'Delete Account',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Permanently remove your account and all associated data',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.red.shade700,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showLogoutDialog(
                        context,
                      ), // ✅ DELETE BUTTON → LOGOUT
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: const Text(
                        'Delete Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
