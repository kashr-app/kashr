import 'package:flutter/material.dart';

/// Dialog for entering encryption password
/// Used when creating or restoring encrypted backups
class EncryptionPasswordDialog extends StatefulWidget {
  final bool isRestore;

  const EncryptionPasswordDialog({
    super.key,
    required this.isRestore,
  });

  /// Show the password dialog
  /// Returns the password or null if cancelled
  static Future<String?> show(
    BuildContext context, {
    bool isRestore = false,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => EncryptionPasswordDialog(isRestore: isRestore),
    );
  }

  @override
  State<EncryptionPasswordDialog> createState() =>
      _EncryptionPasswordDialogState();
}

class _EncryptionPasswordDialogState extends State<EncryptionPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _getPasswordStrength(String password) {
    if (password.isEmpty) return '';
    if (password.length < 6) return 'Weak';
    if (password.length < 10) return 'Medium';
    if (password.length >= 12 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'))) {
      return 'Strong';
    }
    return 'Medium';
  }

  Color _getPasswordStrengthColor(String strength) {
    switch (strength) {
      case 'Weak':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Strong':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.isRestore ? 'Enter Password' : 'Encrypt Backup'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isRestore) ...[
                const Text(
                  'Protect your backup with a password. Keep it safe - it '
                  'cannot be recovered if lost!',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (!widget.isRestore && value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (!widget.isRestore) {
                    setState(() {}); // Rebuild to update strength indicator
                  }
                },
              ),
              if (!widget.isRestore) ...[
                const SizedBox(height: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _passwordController,
                  builder: (context, value, child) {
                    final strength = _getPasswordStrength(value.text);
                    if (strength.isEmpty) return const SizedBox.shrink();

                    return Row(
                      children: [
                        Text(
                          'Strength: ',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          strength,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getPasswordStrengthColor(strength),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_passwordController.text);
            }
          },
          child: Text(widget.isRestore ? 'Decrypt' : 'Encrypt'),
        ),
      ],
    );
  }
}
