import 'package:finanalyzer/backup/model/backup_config.dart';
import 'package:finanalyzer/backup/services/nextcloud_service.dart';
import 'package:finanalyzer/core/secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Page for configuring Nextcloud WebDAV credentials
class NextcloudSettingsPage extends StatefulWidget {
  const NextcloudSettingsPage({super.key});

  @override
  State<NextcloudSettingsPage> createState() => _NextcloudSettingsPageState();
}

class _NextcloudSettingsPageState extends State<NextcloudSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _backupPathController = TextEditingController(
    text: '/Backups/Finanalyzer/',
  );

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _backupPathController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingConfig() async {
    final s = secureStorage();

    // Try to load existing config
    final url = await s.read(key: 'nextcloud_url');
    final username = await s.read(key: 'nextcloud_username');
    final backupPath = await s.read(key: 'nextcloud_path');

    if (url != null) _urlController.text = url;
    if (username != null) _usernameController.text = username;
    if (backupPath != null) _backupPathController.text = backupPath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nextcloud Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Configure Nextcloud WebDAV',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your Nextcloud server details to sync backups.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'WebDAV URL',
                hintText:
                    'https://cloud.example.com/remote.php/dav/files/username',
                border: OutlineInputBorder(),
                helperText: 'Full WebDAV URL including username',
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the WebDAV URL';
                }
                if (!value.startsWith('http://') &&
                    !value.startsWith('https://')) {
                  return 'URL must start with http:// or https://';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your username';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password / App Password',
                border: const OutlineInputBorder(),
                helperText: 'Use an app-specific password for security',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _backupPathController,
              decoration: const InputDecoration(
                labelText: 'Backup Path',
                border: OutlineInputBorder(),
                helperText: 'Path on Nextcloud where backups will be stored',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the backup path';
                }
                if (!value.startsWith('/')) {
                  return 'Path must start with /';
                }
                if (!value.endsWith('/')) {
                  return 'Path must end with /';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            if (_testResult != null)
              Card(
                color: _testResult!.contains('Success')
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _testResult!.contains('Success')
                            ? Icons.check_circle
                            : Icons.error,
                        color: _testResult!.contains('Success')
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testResult!.contains('Success')
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _testConnection,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Test Connection'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveConfiguration,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    final s = secureStorage();
    var prevPassword = await s.read(key: 'nextcloud_password');
    try {
      final config = NextcloudConfig(
        url: _urlController.text,
        username: _usernameController.text,
        passwordKey: 'nextcloud_password',
        backupPath: _backupPathController.text,
      );

      await s.write(key: 'nextcloud_password', value: _passwordController.text);

      final nextcloudService = NextcloudService(s);
      final success = await nextcloudService.testConnection(config);

      setState(() {
        _testResult = success
            ? 'Success! Connected to Nextcloud server.'
            : 'Failed to connect. Please check your credentials.';
      });
    } catch (e) {
      setState(() {
        _testResult = 'Error: ${e.toString()}';
      });
    } finally {
      await s.write(key: 'nextcloud_password', value: prevPassword);
      prevPassword = null;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final s = secureStorage();

      // Save credentials to secure storage
      await s.write(key: 'nextcloud_url', value: _urlController.text);
      await s.write(key: 'nextcloud_username', value: _usernameController.text);
      await s.write(key: 'nextcloud_password', value: _passwordController.text);
      await s.write(key: 'nextcloud_path', value: _backupPathController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nextcloud settings saved')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
