import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../scanner/providers/mesh_provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await auth.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (!success && auth.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppColors.clay,
        ),
      );
    }
  }

  void _showServerSettings() {
    final meshProvider = context.read<MeshProvider>();
    final controller = TextEditingController(text: meshProvider.serverUrl);
    String? testResult;
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Backend Server URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Specify the Next.js server address. For Web/Desktop use http://localhost:3000. For Android emulator use http://10.0.2.2:3000.',
                style: TextStyle(fontSize: 13, color: AppColors.inkLight),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  prefixIcon: Icon(Icons.dns_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: isTesting ? null : () async {
                      setDialogState(() {
                        isTesting = true;
                        testResult = null;
                      });
                      try {
                        final testUrl = controller.text.trim();
                        final cleanUrl = testUrl.endsWith('/') ? testUrl.substring(0, testUrl.length - 1) : testUrl;
                        ApiClient().updateBaseUrl(cleanUrl);
                        final res = await ApiClient().checkHealth();
                        setDialogState(() {
                          isTesting = false;
                          testResult = res['ok'] == true ? 'Connected! Database: ${res['database']}' : 'Response: $res';
                        });
                      } catch (e) {
                        setDialogState(() {
                          isTesting = false;
                          testResult = 'Connection failed: $e';
                        });
                      }
                    },
                    icon: isTesting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.network_check_rounded, size: 16),
                    label: const Text('Test Connection'),
                  ),
                ],
              ),
              if (testResult != null) ...[
                const SizedBox(height: 8),
                Text(
                  testResult!,
                  style: TextStyle(
                    fontSize: 12,
                    color: testResult!.startsWith('Connected') ? AppColors.moss : AppColors.clay,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                ApiClient().updateBaseUrl(meshProvider.serverUrl);
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await meshProvider.setServerUrl(controller.text);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.moss),
            tooltip: 'Server Settings',
            onPressed: _showServerSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Brand Section
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.moss,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.moss.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_bike_rounded,
                      color: AppColors.sand,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'BOAT',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Bicycle Ownership and Address Tag\nCampus Mesh Tracking',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkLight,
                      ),
                ),
                const SizedBox(height: 36),

                // Form Container
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
                        Text(
                          'Sign in to your account',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Campus Email',
                            hintText: 'student@iitr.ac.in',
                            prefixIcon: Icon(Icons.email_outlined, color: AppColors.leaf),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!val.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
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
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
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
                              : const Text('Sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(color: AppColors.inkLight),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: const Text('Register here'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
