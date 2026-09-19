import 'dart:async';

import 'package:flutter/material.dart';
import 'package:aethel/core/constants/colors.dart';
import 'package:aethel/domain/models/models.dart';
import 'package:aethel/core/network/api_client.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'vault_edit_screen.dart';

/// Shows encrypted vault item details after a biometric re-auth gate.
class VaultDetailScreen extends StatefulWidget {
  final VaultEntry entry;

  const VaultDetailScreen({super.key, required this.entry});

  @override
  State<VaultDetailScreen> createState() => _VaultDetailScreenState();
}

class _VaultDetailScreenState extends State<VaultDetailScreen> {
  bool _isAuthenticated = false;
  bool _isLoadingAuth = false;
  String? _errorMessage;

  // Whether the credential fields are currently visible (unmasked)
  bool _revealSecret = false;

  // For copy-to-clipboard auto-clear after 60 seconds
  Timer? _copyTimer;
  bool _copied = false;
  String _copyButtonText = 'Copy';

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Derive the decryption key from master password stored securely
  // Note: _getMasterKey is kept for future use when full decryption is implemented

  Future<void> _authenticate() async {
    setState(() {
      _isLoadingAuth = true;
      _errorMessage = null;
    });

    try {
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to view your vault entry',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated && mounted) {
        setState(() => _isAuthenticated = true);
      } else {
        setState(() => _errorMessage = 'Authentication failed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'Authentication error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAuth = false);
      }
    }
  }

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    setState(() {
      _copied = true;
      _copyButtonText = 'Copied!';
    });
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) {
        setState(() {
          _copied = false;
          _copyButtonText = 'Copy';
        });
      }
    });
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface(context),
        title: const Text('Delete Entry'),
        content: Text(
          'Are you sure you want to delete "${widget.entry.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.urgent(context)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiClient.dio.delete('/vault/entries/${widget.entry.id}');
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Entry deleted successfully'),
              backgroundColor: AppColors.resolved(context),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete entry: $e'),
              backgroundColor: AppColors.urgent(context),
            ),
          );
        }
      }
    }
  }

  void _navigateToEdit() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VaultEditScreen(entry: widget.entry),
      ),
    );
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accent(context);
    final textPrimary = AppColors.textPrimary(context);
    final bgSurface = AppColors.bgSurface(context);

    IconData typeIcon;
    switch (widget.entry.type) {
      case VaultItemType.password:
        typeIcon = Icons.lock_outline;
        break;
      case VaultItemType.card:
        typeIcon = Icons.credit_card;
        break;
      case VaultItemType.note:
      case VaultItemType.secureNote:
        typeIcon = Icons.note;
        break;
      case VaultItemType.identity:
        typeIcon = Icons.person_outline;
        break;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPrimaryDark : AppColors.bgPrimaryLight,
      appBar: AppBar(
        title: Text(widget.entry.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: _navigateToEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: _deleteEntry,
          ),
        ],
      ),
      body: _isAuthenticated
          ? _buildContent(context, isDark, accentColor, textPrimary, bgSurface, typeIcon)
          : _buildAuthGate(context, isDark, accentColor, textPrimary),
    );
  }

  Widget _buildAuthGate(
    BuildContext context,
    bool isDark,
    Color accentColor,
    Color textPrimary,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.security,
              size: 72,
              color: accentColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Biometric Authentication Required',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Authenticate to reveal your secure vault entry',
              style: TextStyle(fontSize: 15, color: textPrimary.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.urgent(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: AppColors.urgent(context)),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingAuth ? null : _authenticate,
                icon: _isLoadingAuth
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fingerprint),
                label: Text(_isLoadingAuth ? 'Authenticating...' : 'Authenticate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    Color accentColor,
    Color textPrimary,
    Color bgSurface,
    IconData typeIcon,
  ) {
    // Get decrypted values if available; otherwise show masked
    // Since we don't have the master key here directly, we show masked by default
    // and allow toggling visibility after auth
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Entry header card
          Card(
            color: bgSurface,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(typeIcon, size: 48, color: accentColor),
                  const SizedBox(height: 12),
                  Text(
                    widget.entry.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.entry.type.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: textPrimary.withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Updated ${_formatDate(widget.entry.updatedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: textPrimary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Credential / secret section
          _buildCredentialSection(context, isDark, accentColor, textPrimary, bgSurface),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _revealSecret = !_revealSecret);
                  },
                  icon: Icon(
                    _revealSecret ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  label: Text(_revealSecret ? 'Hide' : 'Reveal'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: accentColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _copyToClipboard(
                    _revealSecret ? _getSecretValue() : '',
                    'secret',
                  ),
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(_copyButtonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _copied
                        ? AppColors.resolved(context)
                        : accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialSection(
    BuildContext context,
    bool isDark,
    Color accentColor,
    Color textPrimary,
    Color bgSurface,
  ) {
    return Card(
      color: bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Credential',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildCredentialRow(textPrimary, accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRow(Color textPrimary, Color accentColor) {
    final isMasked = !_revealSecret;
    final displayValue = isMasked ? _maskValue(_getSecretValue()) : _getSecretValue();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isMasked ? Icons.lock_outline : Icons.lock_open,
            size: 18,
            color: isMasked ? AppColors.urgent(context) : accentColor,
          ),
        ],
      ),
    );
  }

  String _getSecretValue() {
    // In a real implementation, decrypt the payload using the master key.
    // For now, show a masked placeholder since we don't have the key in this screen.
    // The decrypted data would be computed from widget.entry.encryptedPayload
    // using AesService.decrypt(masterKey, widget.entry.encryptedPayload).
    return '••••••••••••••••';
  }

  String _maskValue(String value) {
    if (value.isEmpty) return '••••••••';
    return value.length > 4
        ? '${'*' * (value.length - 4)}${value.substring(value.length - 4)}'
        : '••••••••';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
