import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';

class AuthScreen extends StatefulWidget {
  final Function(AppUser) onAuthenticated;

  const AuthScreen({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authService.getAllUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      AppUser user;
      if (_isLogin) {
        user = await _authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        user = await _authService.register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          phone: _phoneController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account registered & synced live to Supabase Cloud!'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      widget.onAuthenticated(user);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncAllLocalAccountsToCloud() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final users = await _authService.getAllUsers(includeCloudMerge: false);
    int syncedCount = 0;

    for (var u in users) {
      final success = await SupabaseService.instance.syncUserProfile(u);
      if (success) syncedCount++;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Device Sync Complete', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: Text(
            'Scanned and uploaded $syncedCount account(s) stored on this device directly to Supabase Cloud!',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController recoveryController = TextEditingController();
    bool isProcessing = false;
    String? statusMsg;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: Color(0xFF6366F1)),
                  SizedBox(width: 8),
                  Text('Forgot Password', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your registered Mobile Number or Email address to recover your password.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: recoveryController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number or Email',
                        prefixIcon: const Icon(Icons.contact_phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (statusMsg != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        statusMsg!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusMsg!.contains('sent') || statusMsg!.contains('Found')
                              ? const Color(0xFF10B981)
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          final input = recoveryController.text.trim();
                          if (input.isEmpty) return;

                          setDialogState(() {
                            isProcessing = true;
                            statusMsg = null;
                          });

                          try {
                            final users = await _authService.getAllUsers();
                            final cleanInputPhone = input.replaceAll(RegExp(r'\D'), '');

                            AppUser? matchedUser = users.cast<AppUser?>().firstWhere(
                              (u) {
                                if (u == null) return false;
                                if (u.email.toLowerCase() == input.toLowerCase()) return true;
                                if (u.phone.isNotEmpty) {
                                  final uPhone = u.phone.toLowerCase();
                                  if (uPhone == input.toLowerCase()) return true;
                                  final cleanUPhone = uPhone.replaceAll(RegExp(r'\D'), '');
                                  if (cleanInputPhone.isNotEmpty && cleanUPhone == cleanInputPhone) return true;
                                }
                                return false;
                              },
                              orElse: () => null,
                            );

                            if (matchedUser == null) {
                              setDialogState(() {
                                isProcessing = false;
                                statusMsg = 'No account found with this Mobile Number or Email.';
                              });
                              return;
                            }

                            final targetPhone = matchedUser.phone.isNotEmpty ? matchedUser.phone : input;
                            final password = matchedUser.password.isNotEmpty ? matchedUser.password : '123456';

                            final res = await WhatsAppService.instance.sendPasswordRecovery(
                              targetPhone: targetPhone,
                              userName: matchedUser.name,
                              userEmail: matchedUser.email,
                              password: password,
                            );

                            setDialogState(() {
                              isProcessing = false;
                              if (res.success) {
                                statusMsg = res.message;
                              } else {
                                statusMsg = '${res.message}\n${res.errorDetails ?? ''}';
                              }
                            });
                          } catch (e) {
                            setDialogState(() {
                              isProcessing = false;
                              statusMsg = 'Error: $e';
                            });
                          }
                        },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Recover Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo and Header
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'TYM Habit Tracker',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isLogin ? 'Welcome back! Sign in to track habits.' : 'Create an account to start your 15-day free trial.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 28),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Switch Tabs: Login / Sign Up
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isLogin = true;
                                      _errorMessage = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isLogin
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _isLogin
                                          ? [
                                              BoxShadow(
                                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      'Sign In',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _isLogin
                                            ? Colors.white
                                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isLogin = false;
                                      _errorMessage = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_isLogin
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: !_isLogin
                                          ? [
                                              BoxShadow(
                                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      'Sign Up',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: !_isLogin
                                            ? Colors.white
                                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Error Message Display
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Name field for Sign Up
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: const Icon(Icons.person_outline_rounded),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Mobile Number (Mandatory)',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your mobile number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email or Mobile field for Login, Email field for Sign Up
                        TextFormField(
                          controller: _emailController,
                          keyboardType: _isLogin ? TextInputType.text : TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: _isLogin ? 'Email or Mobile Number' : 'Email Address',
                            prefixIcon: Icon(_isLogin ? Icons.person_outline_rounded : Icons.email_outlined),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return _isLogin ? 'Please enter your email or mobile number' : 'Please enter your email';
                            }
                            if (!_isLogin && (!val.contains('@') || !val.contains('.'))) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (!_isLogin && val.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),

                        if (_isLogin) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 18),
                        ],

                        // Submit Button
                        FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isLogin ? 'Sign In' : 'Create Account',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),

                        // Explicit Device Local Storage Cloud Sync Button
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _syncAllLocalAccountsToCloud,
                          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                          label: const Text('Sync All Device Accounts to Cloud', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      ),
    );
  }
}
