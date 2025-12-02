import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:xml/xml.dart';

/// Simple WebDAV client for Nextcloud operations
class WebDavClient {
  final String baseUrl;
  final String username;
  final String password;
  final log = Logger();

  late final String _authHeader;

  WebDavClient({
    required this.baseUrl,
    required this.username,
    required this.password,
  }) {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    _authHeader = 'Basic $credentials';
  }

  /// Get common headers for WebDAV requests
  Map<String, String> get _headers => {
    'Authorization': _authHeader,
    'Content-Type': 'application/xml',
    'Accept': 'application/xml',
  };

  /// Test connection to WebDAV server
  Future<bool> testConnection() async {
    try {
      final request = http.Request('PROPFIND', Uri.parse(baseUrl))
        ..headers.addAll(_headers)
        ..headers['Depth'] = '0';

      final streamedResponse = await request.send();
      final statusCode = streamedResponse.statusCode;

      log.i('WebDAV test connection status: $statusCode');
      return statusCode >= 200 && statusCode < 300;
    } catch (e, stack) {
      log.e('WebDAV connection test failed', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Create directories recursively if they don't exist
  Future<void> ensureDirectoryExists(String path) async {
    try {
      // Remove trailing slash for consistency
      final cleanPath = path.endsWith('/')
          ? path.substring(0, path.length - 1)
          : path;

      // Split path into segments
      final segments = cleanPath.split('/').where((s) => s.isNotEmpty).toList();

      // Create each directory level
      String currentPath = '';
      for (final segment in segments) {
        currentPath += '/$segment';

        // Check if directory exists
        final exists = await fileExists(currentPath);
        if (!exists) {
          // Create directory
          final url = Uri.parse('$baseUrl$currentPath');
          final request = http.Request('MKCOL', url)
            ..headers.addAll({'Authorization': _authHeader});

          final streamedResponse = await request.send();
          final statusCode = streamedResponse.statusCode;

          // 201 = created, 405 = already exists
          if (statusCode != 201 && statusCode != 405) {
            log.w('Failed to create directory $currentPath: $statusCode');
          } else {
            log.i('Directory created: $currentPath');
          }
        }
      }
    } catch (e, stack) {
      log.e('Failed to ensure directory exists', error: e, stackTrace: stack);
      // Don't rethrow - we'll try to upload anyway
    }
  }

  /// Upload a file to WebDAV server
  Future<void> uploadFile(String localPath, String remotePath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Local file does not exist: $localPath');
      }

      // Ensure parent directory exists
      final lastSlash = remotePath.lastIndexOf('/');
      if (lastSlash > 0) {
        final directory = remotePath.substring(0, lastSlash);
        await ensureDirectoryExists(directory);
      }

      final bytes = await file.readAsBytes();
      final url = Uri.parse('$baseUrl$remotePath');

      final response = await http.put(
        url,
        headers: {
          'Authorization': _authHeader,
          'Content-Type': 'application/zip',
        },
        body: bytes,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to upload file: ${response.statusCode} - ${response.body}',
        );
      }

      log.i('File uploaded: $remotePath');
    } catch (e, stack) {
      log.e('Failed to upload file', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Download a file from the WebDAV server
  Future<void> downloadFile(String remotePath, File file) async {
    try {
      final url = Uri.parse('$baseUrl$remotePath');

      // Send GET request to fetch the file
      final response = await http.get(
        url,
        headers: {'Authorization': _authHeader},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to download file: ${response.statusCode} - ${response.body}',
        );
      }

      // Create the file or fail if it already exists
      await file.create(
        recursive: true,
        exclusive: true, // requires file to not exist before
      );

      // Write the downloaded data to the local file
      await file.writeAsBytes(response.bodyBytes);

      log.i('File downloaded: $remotePath to ${file.path}');
    } catch (e, stack) {
      log.e('Failed to download file', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Check if a file exists on WebDAV server
  Future<bool> fileExists(String remotePath) async {
    try {
      final url = Uri.parse('$baseUrl$remotePath');
      final request = http.Request('PROPFIND', url)
        ..headers.addAll(_headers)
        ..headers['Depth'] = '0';

      final streamedResponse = await request.send();
      final statusCode = streamedResponse.statusCode;

      return statusCode >= 200 && statusCode < 300;
    } catch (e) {
      log.w('File exists check failed: $remotePath', error: e);
      return false;
    }
  }

  /// List files in a directory
  Future<List<String>> listDirectory(String path) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final request = http.Request('PROPFIND', url)
        ..headers.addAll(_headers)
        ..headers['Depth'] = '1';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to list directory: ${response.statusCode}');
      }

      // Parse XML response
      final document = XmlDocument.parse(response.body);
      final files = <String>[];

      for (final element in document.findAllElements('d:href')) {
        final href = element.innerText;
        if (href != path) {
          // Extract just the filename
          final filename = href.split('/').last;
          files.add(filename);
        }
      }

      log.i('Listed ${files.length} files in $path');
      return files;
    } catch (e, stack) {
      log.e('Failed to list directory', error: e, stackTrace: stack);
      return [];
    }
  }
}
