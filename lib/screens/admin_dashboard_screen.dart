import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AppUser currentUser;
  final VoidCallback onLogout;

  const AdminDashboardScreen({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();

  List<AppUser> _allUsers = [];
  bool _isLoading = true;
  bool _isTestingSupabase = false;
  String? _supabaseStatusMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadSupabaseCredentials();
  }

  Future<void> _loadSupabaseCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _urlController.text = prefs.getString('supabase_url') ?? SupabaseService.defaultUrl;
        _keyController.text = prefs.getString('supabase_anon_key') ?? SupabaseService.defaultAnonKey;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _authService.getAllUsers();
    setState(() {
      _allUsers = users;
      _isLoading = false;
    });
  }

  Future<void> _toggleUserStatus(AppUser user) async {
    final newStatus = user.status == 'disabled' ? 'active' : 'disabled';
    final updatedList = await _authService.updateUserStatus(user.id, newStatus);
    
    // Sync with Supabase
    final updatedUser = user.copyWith(status: newStatus);
    _supabaseService.syncUserProfile(updatedUser);

    setState(() {
      _allUsers = updatedList;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} is now ${newStatus.toUpperCase()}'),
          backgroundColor: newStatus == 'disabled' ? Colors.red.shade600 : const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _testAndSaveSupabaseCredentials() async {
    setState(() {
      _isTestingSupabase = true;
      _supabaseStatusMessage = null;
    });

    final success = await _supabaseService.initialize(
      url: _urlController.text.trim(),
      anonKey: _keyController.text.trim(),
    );

    setState(() {
      _isTestingSupabase = false;
      _supabaseStatusMessage = success
          ? 'Connected to Supabase Cloud Database successfully!'
          : 'Failed to connect. Please check your Supabase Project URL and Anon Key.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalUsers = _allUsers.length;
    final activeUsers = _allUsers.where((u) => u.status == 'active').length;
    final disabledUsers = _allUsers.where((u) => u.status == 'disabled').length;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF8B5CF6)),
            SizedBox(width: 8),
            Text('Super Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadUsers,
            tooltip: 'Refresh Users List',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: widget.onLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Super Admin Banner
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF4C1D95), const Color(0xFF6D28D9)]
                            : [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: const Icon(Icons.security_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.currentUser.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Application Owner • Master Admin Control',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Metrics Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          'Total Users',
                          totalUsers.toString(),
                          Icons.people_alt_rounded,
                          const Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          'Active',
                          activeUsers.toString(),
                          Icons.check_circle_rounded,
                          const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          'Disabled',
                          disabledUsers.toString(),
                          Icons.block_rounded,
                          Colors.red.shade500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Supabase Configuration Panel
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cloud_sync_rounded, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            const Text(
                              'Supabase Cloud Credentials',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure your Supabase project settings to enable cloud synchronization.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            labelText: 'Supabase Project URL',
                            hintText: 'https://xyzcompany.supabase.co',
                            prefixIcon: const Icon(Icons.link_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _keyController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Supabase Anon / Publishable Key',
                            prefixIcon: const Icon(Icons.key_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: _isTestingSupabase ? null : _testAndSaveSupabaseCredentials,
                              icon: _isTestingSupabase
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.electrical_services_rounded, size: 18),
                              label: const Text('Save & Test Connection'),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                        if (_supabaseStatusMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _supabaseStatusMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _supabaseStatusMessage!.contains('successfully')
                                  ? const Color(0xFF10B981)
                                  : Colors.red.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Registered Users List Header
                  const Text(
                    'User Accounts & Access Control',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 10),

                  // Users Table / Cards
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _allUsers.length,
                      separatorBuilder: (ctx, idx) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (ctx, idx) {
                        final user = _allUsers[idx];
                        final isSelf = user.id == widget.currentUser.id;
                        final isDisabled = user.isDisabled;

                        final lastLoginStr = user.lastLoginAt != null
                            ? DateFormat('d MMM yyyy, h:mm a').format(user.lastLoginAt!)
                            : 'Never logged in';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: user.color,
                            child: Text(
                              user.initials,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isDisabled
                                        ? Colors.red.shade400
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                              if (user.isAdmin) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Admin',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined, size: 13, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(user.email, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                if (user.phone.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 13, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(user.phone, style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 13, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('Last Login: $lastLoginStr', style: const TextStyle(fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: isSelf
                              ? const Chip(
                                  label: Text('Owner', style: TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                )
                              : Switch.adaptive(
                                  value: !isDisabled,
                                  activeThumbColor: const Color(0xFF10B981),
                                  onChanged: (val) => _toggleUserStatus(user),
                                ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
