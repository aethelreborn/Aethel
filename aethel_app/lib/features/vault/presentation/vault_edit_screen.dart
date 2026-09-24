import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aethel/core/constants/colors.dart';
import 'package:aethel/core/crypto/aes_service.dart';
import 'dart:convert';
import 'package:aethel/core/crypto/secure_key_store.dart';
import 'package:aethel/domain/models/models.dart';
import 'package:aethel/core/network/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';

class VaultEditScreen extends StatefulWidget {
  final VaultEntry? entry;

  const VaultEditScreen({super.key, this.entry});

  @override
  State<VaultEditScreen> createState() => _VaultEditScreenState();
}

class _VaultEditScreenState extends State<VaultEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final SecureKeyStore _keyStore = SecureKeyStore(storage: const FlutterSecureStorage());
  final Uuid _uuid = const Uuid();

  late TextEditingController _titleController;
  late VaultItemType _selectedType;

  // Password type fields
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _urlController;
  late TextEditingController _notesController;

  // Card type fields
  late TextEditingController _cardNumberController;
  late TextEditingController _expiryController;
  late TextEditingController _cvvController;
  late TextEditingController _holderNameController;

  // Note type fields
  late TextEditingController _noteTitleController;
  late TextEditingController _noteContentController;

  bool _passwordVisible = false;
  bool _cvvVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _selectedType = widget.entry?.type ?? VaultItemType.password;

    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _urlController = TextEditingController();
    _notesController = TextEditingController();

    _cardNumberController = TextEditingController();
    _expiryController = TextEditingController();
    _cvvController = TextEditingController();
    _holderNameController = TextEditingController();

    _noteTitleController = TextEditingController();
    _noteContentController = TextEditingController();

    if (widget.entry != null) {
      _prefillFromEntry(widget.entry!);
    }
  }

  /// Decrypts the existing entry's payload and populates form controllers.
  void _prefillFromEntry(VaultEntry entry) async {
    final key = await _keyStore.getDerivedKey();
    if (key == null) return;
    try {
      final plaintext = AesService.decrypt(key, entry.encryptedPayload);
      final lines = plaintext.split('\n');
      final Map<String, String> fields = {};
      for (final line in lines) {
        final eqIdx = line.indexOf('=');
        if (eqIdx > 0) {
          fields[line.substring(0, eqIdx)] = line.substring(eqIdx + 1);
        }
      }
      if (!mounted) return;
      setState(() {
        switch (entry.type) {
          case VaultItemType.password:
            _usernameController.text = fields['username'] ?? '';
            _passwordController.text = fields['password'] ?? '';
            _urlController.text = fields['url'] ?? '';
            _notesController.text = fields['notes'] ?? '';
          case VaultItemType.card:
            _holderNameController.text = fields['holder_name'] ?? '';
            _cardNumberController.text = fields['card_number'] ?? '';
            _expiryController.text = fields['expiry'] ?? '';
            _cvvController.text = fields['cvv'] ?? '';
          case VaultItemType.note:
          case VaultItemType.secureNote:
            _noteTitleController.text = fields['title'] ?? '';
            _noteContentController.text = fields['content'] ?? '';
          case VaultItemType.identity:
            _usernameController.text = fields['full_name'] ?? '';
            _notesController.text = fields['notes'] ?? '';
        }
      });
    } catch (e) {
      debugPrint('[VaultEdit] Prefill decrypt failed: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _holderNameController.dispose();
    _noteTitleController.dispose();
    _noteContentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final key = await _keyStore.getDerivedKey();
      if (key == null) {
        throw Exception('Please authenticate first to access your vault.');
      }

      final payloadMap = _buildPayloadMap();
      final plaintext = payloadMap.entries.map((e) => '${e.key}=${e.value}').join('\n');
      final encryptedPayload = AesService.encrypt(key, plaintext);

      final endpoint = widget.entry == null ? '/vault' : '/vault/${widget.entry!.id}';
      final method = widget.entry == null ? 'POST' : 'PUT';

      // IV is appended to ciphertext by AesService.encrypt(); extract it for separate storage
      final ivBytes = base64Decode(encryptedPayload).sublist(base64Decode(encryptedPayload).length - 12);
      final iv = base64Encode(ivBytes);

      final response = await ApiClient.dio.request(
        endpoint,
        data: {
          'id': widget.entry?.id ?? _uuid.v4(),
          'title': _titleController.text.trim(),
          'item_type': _selectedType.name,
          'encrypted_payload': encryptedPayload,
          'iv': iv,
        },
        options: Options(method: method),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.entry == null ? 'Entry created successfully' : 'Entry updated successfully'),
              backgroundColor: AppColors.resolved(context),
            ),
          );
        }
      } else {
        throw Exception('Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, String> _buildPayloadMap() {
    final Map<String, String> map = {};
    switch (_selectedType) {
      case VaultItemType.password:
        map['username'] = _usernameController.text;
        map['password'] = _passwordController.text;
        map['url'] = _urlController.text;
        map['notes'] = _notesController.text;
        break;
      case VaultItemType.card:
        map['card_number'] = _cardNumberController.text;
        map['expiry'] = _expiryController.text;
        map['cvv'] = _cvvController.text;
        map['holder_name'] = _holderNameController.text;
        break;
      case VaultItemType.note:
      case VaultItemType.secureNote:
        map['title'] = _noteTitleController.text;
        map['content'] = _noteContentController.text;
        break;
      case VaultItemType.identity:
        map['full_name'] = _titleController.text;
        map['notes'] = _notesController.text;
        break;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final accentColor = AppColors.accent(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPrimaryDark : AppColors.bgPrimaryLight,
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Add Entry' : 'Edit Entry'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<VaultItemType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(labelText: 'Type', prefixIcon: Icon(Icons.category)),
              items: VaultItemType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.name.capitalize()))).toList(),
              onChanged: (value) { if (value != null) setState(() => _selectedType = value); },
            ),
            const SizedBox(height: 24),
            if (_selectedType == VaultItemType.password) ...[
              _buildSectionHeader('Password Details', accentColor),
              const SizedBox(height: 8),
              TextFormField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _passwordVisible = !_passwordVisible))),
                obscureText: !_passwordVisible,
                validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _urlController, decoration: const InputDecoration(labelText: 'URL', prefixIcon: Icon(Icons.link)), keyboardType: TextInputType.url),
              const SizedBox(height: 12),
              TextFormField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.note_outlined)), maxLines: 3),
            ] else if (_selectedType == VaultItemType.card) ...[
              _buildSectionHeader('Card Details', accentColor),
              const SizedBox(height: 8),
              TextFormField(controller: _holderNameController, decoration: const InputDecoration(labelText: 'Holder Name', prefixIcon: Icon(Icons.badge))),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cardNumberController,
                decoration: const InputDecoration(labelText: 'Card Number', prefixIcon: Icon(Icons.credit_card)),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, _CardNumberFormatter()],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Card number is required';
                  if (v.replaceAll(RegExp(r'\s'), '').length < 13) return 'Invalid card number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextFormField(
                    controller: _expiryController,
                    decoration: const InputDecoration(labelText: 'Expiry (MM/YY)', prefixIcon: Icon(Icons.calendar_today)),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ExpiryFormatter()],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(v)) return 'Use MM/YY';
                      return null;
                    },
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _cvvController,
                    decoration: InputDecoration(labelText: 'CVV', prefixIcon: const Icon(Icons.security),
                      suffixIcon: IconButton(icon: Icon(_cvvVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _cvvVisible = !_cvvVisible))),
                    keyboardType: TextInputType.number,
                    obscureText: !_cvvVisible,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 3 || v.length > 4) return 'Invalid CVV';
                      return null;
                    },
                  )),
                ],
              ),
            ] else if (_selectedType == VaultItemType.note || _selectedType == VaultItemType.secureNote) ...[
              _buildSectionHeader('Note Details', accentColor),
              const SizedBox(height: 8),
              TextFormField(controller: _noteTitleController, decoration: const InputDecoration(labelText: 'Note Title', prefixIcon: Icon(Icons.note))),
              const SizedBox(height: 12),
              TextFormField(controller: _noteContentController, decoration: const InputDecoration(labelText: 'Content', prefixIcon: Icon(Icons.article_outlined)), maxLines: 8),
            ] else if (_selectedType == VaultItemType.identity) ...[
              _buildSectionHeader('Identity Details', accentColor),
              const SizedBox(height: 8),
              TextFormField(controller: _usernameController, decoration: const InputDecoration(labelText: 'ID Number / Username', prefixIcon: Icon(Icons.badge))),
              const SizedBox(height: 12),
              TextFormField(controller: _notesController, decoration: const InputDecoration(labelText: 'Additional Notes', prefixIcon: Icon(Icons.note_outlined)), maxLines: 3),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.urgent(context).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(_errorMessage!, style: TextStyle(color: AppColors.urgent(context))),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accentColor, letterSpacing: 0.8)),
    );
  }
}

// ── Input formatters ─────────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\s'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[\/\s]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    String formatted;
    if (digits.length <= 2) {
      formatted = digits;
    } else {
      formatted = '${digits.substring(0, 2)}/${digits.substring(1, 4)}';
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

extension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
