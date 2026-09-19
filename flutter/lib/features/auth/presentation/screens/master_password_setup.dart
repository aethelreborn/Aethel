import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aethel/core/constants/colors.dart';
import 'package:aethel/core/crypto/secure_key_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _storageProvider = Provider((ref) => const FlutterSecureStorage());

class MasterPasswordSetupScreen extends ConsumerStatefulWidget {
  const MasterPasswordSetupScreen({super.key});
  @override
  ConsumerState<MasterPasswordSetupScreen> createState() => _MasterPasswordSetupScreenState();
}

class _MasterPasswordSetupScreenState extends ConsumerState<MasterPasswordSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true, _confirmObscure = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pwCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final storage = ref.read(_storageProvider);
      await storage.storeDerivedKey(_pwCtrl.text);
      if (mounted) Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _pwCtrl.dispose(); _confirmCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPrimaryDark : AppColors.bgPrimaryLight,
      appBar: AppBar(title: const Text('Create Master Password'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('This is your only way to access your vault. We cannot recover it.',
                style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            TextFormField(controller: _pwCtrl, obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Master Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v?.length ?? 0) < 8 ? 'Min 8 characters' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _confirmCtrl, obscureText: _confirmObscure,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                suffixIcon: IconButton(
                  icon: Icon(_confirmObscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _confirmObscure = !_confirmObscure),
                ),
              ),
              validator: (v) => v != _pwCtrl.text ? 'Passwords do not match' : null,
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Continue'),
            ),
          ]),
        ),
      )),
    );
  }
}
