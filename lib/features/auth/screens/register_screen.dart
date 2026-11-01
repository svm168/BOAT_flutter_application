import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hostelController = TextEditingController();
  final _roomController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _hostelController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      email: _emailController.text,
      password: _passwordController.text,
      displayName: _displayNameController.text,
      phone: _phoneController.text,
      hostel: _hostelController.text,
      room: _roomController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context); // Pops back to root, which will show MainNavigationScreen
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppColors.clay,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join the Campus Mesh',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Register to protect your bicycle, trace lost tags, and link your NFC ownership plate.',
                style: TextStyle(color: AppColors.inkLight, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'Aarav Sharma',
                          prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.leaf),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Please enter your name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Campus Email *',
                          hintText: 'student@iitr.ac.in',
                          prefixIcon: Icon(Icons.email_outlined, color: AppColors.leaf),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter your email';
                          if (!val.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.leaf),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.inkMuted,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (val) => (val == null || val.length < 6)
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number (Optional)',
                          hintText: '+91 9876543210',
                          prefixIcon: Icon(Icons.phone_outlined, color: AppColors.leaf),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _hostelController,
                              decoration: const InputDecoration(
                                labelText: 'Hostel/Bhawan',
                                hintText: 'Rajendra Bhawan',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _roomController,
                              decoration: const InputDecoration(
                                labelText: 'Room',
                                hintText: 'B-214',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: auth.isLoading ? null : _submit,
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.sand,
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
