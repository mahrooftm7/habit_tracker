import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

class PaymentExpiredScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onLogout;
  final Function(AppUser) onUserUpdated;

  const PaymentExpiredScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onUserUpdated,
  });

  @override
  State<PaymentExpiredScreen> createState() => _PaymentExpiredScreenState();
}

class _PaymentExpiredScreenState extends State<PaymentExpiredScreen> {
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;
  final TextEditingController _proofController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String _feeAmount = '₹299 / Year';
  String _upiId = 'tymathabittracker@upi';
  String _phone = '+91 98765 43210';
  String _qrCodeUrl = '';

  @override
  void initState() {
    super.initState();
    _loadPaymentSettings();
  }

  Future<void> _loadPaymentSettings() async {
    setState(() => _isLoading = true);
    final fee = await _supabaseService.fetchAppSetting('subscription_fee');
    final upi = await _supabaseService.fetchAppSetting('upi_id');
    final phone = await _supabaseService.fetchAppSetting('support_phone');
    final qr = await _supabaseService.fetchAppSetting('qr_code_url');

    if (mounted) {
      setState(() {
        if (fee != null && fee.isNotEmpty) _feeAmount = fee;
        if (upi != null && upi.isNotEmpty) _upiId = upi;
        if (phone != null && phone.isNotEmpty) _phone = phone;
        if (qr != null && qr.isNotEmpty) _qrCodeUrl = qr;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitProof() async {
    final text = _proofController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your UTR / Transaction ID or payment reference.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final updatedUser = await _authService.submitPaymentProof(widget.user.id, text);
      widget.onUserUpdated(updatedUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment proof submitted successfully! Pending Admin Approval.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final users = await _authService.getAllUsers();
    try {
      final freshUser = users.firstWhere((u) => u.id == widget.user.id);
      widget.onUserUpdated(freshUser);
      if (mounted) {
        if (freshUser.isSubscriptionActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Congratulations! Your subscription is approved and active!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status checked. Still pending approval.')),
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _proofController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPending = widget.user.paymentStatus == 'pending';

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Expiration Header Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer_off_rounded, color: Colors.amber, size: 54),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      isPending ? 'Payment Verification Pending' : '15-Day Free Trial Ended',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      isPending
                          ? 'Your payment details have been submitted. Our Admin will verify and activate your account shortly.'
                          : 'Your 15-day free trial for ${widget.user.name} has completed. Please complete the subscription payment to unlock full access.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // QR Code & Payment Info Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Subscription Plan: $_feeAmount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // QR Code Image Placeholder or Custom Image
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _qrCodeUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      _qrCodeUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, _, __) => _buildDefaultQrCode(),
                                    ),
                                  )
                                : _buildDefaultQrCode(),
                          ),

                          const SizedBox(height: 16),

                          // UPI Details
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _upiId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('UPI ID copied to clipboard!')),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF10B981)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'UPI ID: $_upiId',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone_android_rounded, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('Support Contact: $_phone', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit Payment Proof Section
                    if (!isPending) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Submit Payment Proof',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      TextField(
                        controller: _proofController,
                        decoration: InputDecoration(
                          hintText: 'Enter Transaction UTR / Ref No. or Payment Link',
                          prefixIcon: const Icon(Icons.receipt_long_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        ),
                      ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _isSubmitting ? null : _submitProof,
                          icon: _isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded),
                          label: const Text('Submit Payment Proof for Approval', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.access_time_filled_rounded, color: Color(0xFF10B981), size: 20),
                                SizedBox(width: 8),
                                Text('Submitted Details:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.user.paymentProofUrl ?? 'Transaction Submitted',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _checkStatus,
                          icon: const Icon(Icons.sync_rounded, size: 18),
                          label: const Text('Check Approval Status'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: widget.onLogout,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Logout'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDefaultQrCode() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.qr_code_2_rounded, size: 90, color: Color(0xFF6366F1)),
        const SizedBox(height: 4),
        Text(
          'Scan to Pay via UPI',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
