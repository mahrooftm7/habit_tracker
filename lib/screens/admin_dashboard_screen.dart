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

  final TextEditingController _feeController = TextEditingController(text: '₹299 / Year');
  final TextEditingController _upiController = TextEditingController(text: 'tymathabittracker@upi');
  final TextEditingController _phoneController = TextEditingController(text: '+91 98765 43210');
  final TextEditingController _qrUrlController = TextEditingController();

  List<AppUser> _allUsers = [];
  String _selectedFilter = 'all'; // 'all', 'trial', 'active', 'expired', 'disabled'
  bool _isLoading = true;
  bool _isTestingSupabase = false;
  bool _isSavingPaymentSettings = false;
  String? _supabaseStatusMessage;
  String? _paymentSettingsMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadSupabaseCredentials();
    _loadPaymentSettings();
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

  Future<void> _loadPaymentSettings() async {
    final fee = await _supabaseService.fetchAppSetting('subscription_fee');
    final upi = await _supabaseService.fetchAppSetting('upi_id');
    final phone = await _supabaseService.fetchAppSetting('support_phone');
    final qr = await _supabaseService.fetchAppSetting('qr_code_url');

    if (mounted) {
      setState(() {
        if (fee != null && fee.isNotEmpty) _feeController.text = fee;
        if (upi != null && upi.isNotEmpty) _upiController.text = upi;
        if (phone != null && phone.isNotEmpty) _phoneController.text = phone;
        if (qr != null && qr.isNotEmpty) _qrUrlController.text = qr;
      });
    }
  }

  Future<void> _savePaymentSettings() async {
    setState(() {
      _isSavingPaymentSettings = true;
      _paymentSettingsMessage = null;
    });

    await _supabaseService.saveAppSetting('subscription_fee', _feeController.text.trim());
    await _supabaseService.saveAppSetting('upi_id', _upiController.text.trim());
    await _supabaseService.saveAppSetting('support_phone', _phoneController.text.trim());
    await _supabaseService.saveAppSetting('qr_code_url', _qrUrlController.text.trim());

    if (mounted) {
      setState(() {
        _isSavingPaymentSettings = false;
        _paymentSettingsMessage = 'Payment QR & Subscription settings saved successfully!';
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    _feeController.dispose();
    _upiController.dispose();
    _phoneController.dispose();
    _qrUrlController.dispose();
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

    final updatedUser = user.copyWith(status: newStatus);
    _supabaseService.syncUserProfile(updatedUser);

    setState(() {
      _allUsers = updatedList;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} status updated to ${newStatus.toUpperCase()}'),
          backgroundColor: newStatus == 'disabled' ? Colors.red.shade600 : const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _approveSubscription(AppUser user) async {
    final updatedList = await _authService.approveUserSubscription(user.id, validDays: 365);
    setState(() {
      _allUsers = updatedList;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscription approved for ${user.name}! Active for 1 Year.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _testAndSaveSupabaseCredentials() async {
    setState(() {
      _isTestingSupabase = true;
      _supabaseStatusMessage = null;
    });

    final message = await _supabaseService.testAndSaveCredentials(
      _urlController.text,
      _keyController.text,
    );

    setState(() {
      _isTestingSupabase = false;
      _supabaseStatusMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalUsers = _allUsers.length;
    final trialUsers = _allUsers.where((u) => u.isTrial).length;
    final activeUsers = _allUsers.where((u) => u.isSubscriptionActive).length;
    final expiredUsers = _allUsers.where((u) => u.isExpired).length;
    final disabledUsers = _allUsers.where((u) => u.isDisabled).length;

    final filteredUsers = _allUsers.where((u) {
      if (_selectedFilter == 'trial') return u.isTrial;
      if (_selectedFilter == 'active') return u.isSubscriptionActive;
      if (_selectedFilter == 'expired') return u.isExpired;
      if (_selectedFilter == 'disabled') return u.isDisabled;
      return true;
    }).toList();

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
            tooltip: 'Refresh Data',
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
                  // Banner Card
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
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Application Owner • Subscriptions & Payment Manager',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // User Metrics Cards
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterMetricCard('All Users', totalUsers.toString(), Icons.people_alt_rounded, const Color(0xFF6366F1), 'all'),
                        const SizedBox(width: 8),
                        _buildFilterMetricCard('15-Day Trial', trialUsers.toString(), Icons.timer_rounded, Colors.amber.shade700, 'trial'),
                        const SizedBox(width: 8),
                        _buildFilterMetricCard('Active Paid', activeUsers.toString(), Icons.check_circle_rounded, const Color(0xFF10B981), 'active'),
                        const SizedBox(width: 8),
                        _buildFilterMetricCard('Expired', expiredUsers.toString(), Icons.timer_off_rounded, Colors.orange.shade800, 'expired'),
                        const SizedBox(width: 8),
                        _buildFilterMetricCard('Disabled', disabledUsers.toString(), Icons.block_rounded, Colors.red.shade500, 'disabled'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment QR Code & Subscription Gateway Config
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            const Text('Payment QR Code & Subscription Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure the QR Code, Fee, and UPI ID displayed to users when their 15-day trial expires.',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _feeController,
                                decoration: InputDecoration(
                                  labelText: 'Subscription Fee',
                                  prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _upiController,
                                decoration: InputDecoration(
                                  labelText: 'UPI ID',
                                  prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                decoration: InputDecoration(
                                  labelText: 'Support Contact Phone',
                                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _qrUrlController,
                                decoration: InputDecoration(
                                  labelText: 'Payment QR Code Image URL',
                                  hintText: 'https://i.imgur.com/qrcode.png',
                                  prefixIcon: const Icon(Icons.image_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        FilledButton.icon(
                          onPressed: _isSavingPaymentSettings ? null : _savePaymentSettings,
                          icon: _isSavingPaymentSettings
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Save Payment & QR Settings'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),

                        if (_paymentSettingsMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _paymentSettingsMessage!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Supabase Panel
                  ExpansionTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    collapsedBackgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    title: const Text('Supabase Database Connection Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _urlController,
                              decoration: InputDecoration(
                                labelText: 'Supabase Project URL',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _keyController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Supabase Anon Key',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: _isTestingSupabase ? null : _testAndSaveSupabaseCredentials,
                              icon: const Icon(Icons.electrical_services_rounded, size: 18),
                              label: const Text('Test Connection'),
                            ),
                            if (_supabaseStatusMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(_supabaseStatusMessage!, style: const TextStyle(fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // User Accounts & Subscriptions List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'User Accounts (${filteredUsers.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredUsers.length,
                      separatorBuilder: (ctx, idx) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, idx) {
                        final user = filteredUsers[idx];
                        final isSelf = user.id == widget.currentUser.id;
                        final isDisabled = user.isDisabled;
                        final isPendingPayment = user.paymentStatus == 'pending';

                        final lastLoginStr = user.lastLoginAt != null
                            ? DateFormat('d MMM yyyy, h:mm a').format(user.lastLoginAt!)
                            : 'Never logged in';

                        final createdStr = DateFormat('d MMM yyyy').format(user.createdAt);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: user.color,
                                    child: Text(user.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              user.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: isDisabled ? Colors.red.shade400 : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            _buildUserStatusBadge(user),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text('${user.email} • Joined: $createdStr • Last: $lastLoginStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  if (!isSelf) ...[
                                    Switch.adaptive(
                                      value: !isDisabled,
                                      activeThumbColor: const Color(0xFF10B981),
                                      onChanged: (val) => _toggleUserStatus(user),
                                    ),
                                  ],
                                ],
                              ),

                              // Payment Proof & Action Details
                              if (isPendingPayment || user.paymentProofUrl != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isPendingPayment ? Colors.amber.withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isPendingPayment ? Icons.pending_actions_rounded : Icons.verified_rounded,
                                        size: 16,
                                        color: isPendingPayment ? Colors.amber.shade900 : const Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Payment Proof: ${user.paymentProofUrl ?? "Submitted"}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (!isSelf && !isDisabled && !user.isSubscriptionActive) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => _approveSubscription(user),
                                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                                    label: const Text('Approve & Activate Subscription (1 Year)'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
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

  Widget _buildFilterMetricCard(String label, String value, IconData icon, Color color, String filterKey) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedFilter == filterKey;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
      ),
    );
  }

  Widget _buildUserStatusBadge(AppUser user) {
    if (user.isAdmin) {
      return _badge('Admin', const Color(0xFF8B5CF6));
    }
    if (user.isDisabled) {
      return _badge('Disabled', Colors.red);
    }
    if (user.isSubscriptionActive) {
      return _badge('Active Paid', const Color(0xFF10B981));
    }
    if (user.isTrial) {
      return _badge('Trial: ${user.remainingTrialDays}d left', Colors.amber.shade900);
    }
    return _badge('Expired', Colors.orange.shade900);
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
