import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_logo.dart';

class SignInScreen extends ConsumerStatefulWidget {
  final bool isReturningUser;
  const SignInScreen({super.key, this.isReturningUser = false});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'customer';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      UserCredential credential;
      if (widget.isReturningUser) {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) return;

      if (widget.isReturningUser) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).get();
        if (!mounted) return;
        
        final data = doc.data();
        if (doc.exists && data != null) {
          final role = data['role'] as String? ?? 'customer';
          if (role == 'vendor') {
            if (data['onboardingComplete'] == true) {
              context.go('/vendor/home');
            } else {
              context.go('/vendor/onboarding');
            }
          } else {
            context.go('/customer/home');
          }
        } else {
          context.go('/customer/home');
        }
      } else {
        // Create user document in Firestore with the selected role
        await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': credential.user!.email,
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Check role and navigate
        if (_selectedRole == 'vendor') {
          context.go('/vendor/onboarding');
        } else {
          context.go('/customer/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? tr('auth_error'))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = widget.isReturningUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EB),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  // Logo
                  const Center(
                    child: AppLogo(size: 80),
                  ),
                  const SizedBox(height: 24),
                  Text(tr('eventflow'), textAlign: TextAlign.center, style: GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text(isLogin ? tr('welcome_back') : tr('signup_subtitle'), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15, color: Colors.grey.shade600)),
                  const SizedBox(height: 40),

                  // Role selector (only on sign-up)
                  if (!isLogin) ...[
                    Row(
                      children: [
                        _buildRoleChip('customer', Icons.person, tr('customer_role')),
                        const SizedBox(width: 12),
                        _buildRoleChip('vendor', Icons.store, tr('vendor_role')),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(tr('email'), Icons.email_outlined),
                    validator: (v) => (v == null || v.isEmpty) ? tr('email_required') : null,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _inputDecoration(tr('password'), Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return tr('password_required');
                      if (!isLogin && v.length < 6) return tr('password_min');
                      return null;
                    },
                  ),
                  if (isLogin) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          if (_emailController.text.isNotEmpty) {
                            await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('reset_email_sent'))));
                          }
                        },
                        child: Text(tr('forgot_password'), style: GoogleFonts.inter(color: AppColors.goldenBrown)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mossGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(isLogin ? tr('log_in') : tr('sign_up'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Toggle link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isLogin ? tr('no_account') : tr('have_account'), style: GoogleFonts.inter(color: Colors.grey.shade600)),
                      TextButton(
                        onPressed: () {
                          if (isLogin) {
                            context.go('/signin');
                          } else {
                            context.go('/signin-returning');
                          }
                        },
                        child: Text(isLogin ? tr('sign_up') : tr('log_in'), style: GoogleFonts.inter(color: AppColors.goldenBrown, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role, IconData icon, String label) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mossGreen : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.mossGreen : Colors.grey.shade300, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade500),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.mossGreen, width: 2)),
    );
  }
}
