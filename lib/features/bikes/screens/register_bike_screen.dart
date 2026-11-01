import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/bike_provider.dart';

class RegisterBikeScreen extends StatefulWidget {
  const RegisterBikeScreen({super.key});

  @override
  State<RegisterBikeScreen> createState() => _RegisterBikeScreenState();
}

class _RegisterBikeScreenState extends State<RegisterBikeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _colorController = TextEditingController();
  final _modelController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final bikeProvider = context.read<BikeProvider>();
    final success = await bikeProvider.registerBike(
      name: _nameController.text,
      color: _colorController.text,
      model: _modelController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bicycle registered successfully!'),
          backgroundColor: AppColors.moss,
        ),
      );
      Navigator.pop(context);
    } else if (bikeProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bikeProvider.errorMessage!),
          backgroundColor: AppColors.clay,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bikeProvider = context.watch<BikeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Bicycle'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add your bicycle',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Assign a new decentralized BLE beacon ID and generated NFC tag plate.',
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
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Bicycle Name *',
                          hintText: 'e.g. Rockrider 520, Hero Sprint',
                          prefixIcon: Icon(Icons.pedal_bike_rounded, color: AppColors.leaf),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Please enter a name for the bike' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _colorController,
                        decoration: const InputDecoration(
                          labelText: 'Color (Optional)',
                          hintText: 'e.g. Matte Black, Navy Blue',
                          prefixIcon: Icon(Icons.palette_outlined, color: AppColors.leaf),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model / Brand (Optional)',
                          hintText: 'e.g. BTWIN, Atlas, Hercules',
                          prefixIcon: Icon(Icons.info_outline_rounded, color: AppColors.leaf),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: bikeProvider.isLoading ? null : _submit,
                        child: bikeProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.sand,
                                ),
                              )
                            : const Text('Register Bicycle'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
