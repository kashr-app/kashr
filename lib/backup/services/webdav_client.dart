import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:xml/xml.dart';

/// Simple WebDAV client for Nextcloud operations
class WebDavClient {
  final String baseUrl;
  final String username;
  final String password;
  final  Logger log;

  late final String _authHeader;

  WebDavClient({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.log,
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
      final dio = Dio();
      await dio.fetch(
        RequestOptions(
          path: baseUrl,
          method: 'PROPFIND',
          headers: {..._headers, 'Depth': '0'},
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      log.i('WebDAV test connection successful');
      return true;
    } on DioException catch (e, stack) {
      throw _extractDioErrorMsg(
        e,
        baseUrl,
        stack,
        operation: 'Connection test',
      );
    } catch (e, stack) {
      log.e('WebDAV connection test failed', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Create directories recursively if they don't exist
  Future<void> _ensureDirectoryExists(String path) async {
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
          try {
            // Create directory
            final dio = Dio();
            await dio.fetch(
              RequestOptions(
                path: '$baseUrl$currentPath',
                method: 'MKCOL',
                headers: {'Authorization': _authHeader},
                validateStatus: (status) =>
                    // 201 = created, 405 = already exists
                    status == 201 || status == 405,
              ),
            );

            log.i('Directory created: $currentPath');
          } on DioException catch (e, stack) {
            throw _extractDioErrorMsg(
              e,
              currentPath,
              stack,
              operation: 'Create directory',
            );
          }
        }
      }
    } catch (e, stack) {
      log.e('Failed to ensure directory exists', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Upload a file to WebDAV server
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Local file does not exist: $localPath');
      }

      // Ensure parent directory exists
      final lastSlash = remotePath.lastIndexOf('/');
      if (lastSlash > 0) {
        final directory = remotePath.substring(0, lastSlash);
        try {
          await _ensureDirectoryExists(directory);
        } catch (e) {
          // we will try to upload anyway
        }
      }

      final url = '$baseUrl$remotePath';
      final dio = Dio();

      await dio.put(
        url,
        data: file.openRead(),
        options: Options(
          headers: {
            'Authorization': _authHeader,
            'Content-Type': 'application/zip',
            'Content-Length': await file.length(),
          },
          validateStatus: (status) {
            // Accept 200-299 status codes as success
            return status != null && status >= 200 && status < 300;
          },
        ),
        onSendProgress: (sent, total) {
          onProgress?.call(sent, total);
        },
      );

      log.i('File uploaded: $remotePath');
    } on DioException catch (e, stack) {
      throw _extractDioErrorMsg(e, remotePath, stack, operation: 'Upload');
    } catch (e, stack) {
      log.e('Failed to upload file', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Download a file from the WebDAV server
  Future<void> downloadFile(
    String remotePath,
    File file, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      // Create the file or fail if it already exists
      await file.create(
        recursive: true,
        exclusive: true, // requires file to not exist before
      );

      final dio = Dio();
      await dio.download(
        '$baseUrl$remotePath',
        file.path,
        options: Options(
          headers: {'Authorization': _authHeader},
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
        onReceiveProgress: (received, total) {
          onProgress?.call(received, total);
        },
      );

      log.i('File downloaded: $remotePath to ${file.path}');
    } on DioException catch (e, stack) {
      throw _extractDioErrorMsg(e, remotePath, stack, operation: 'Download');
    } catch (e, stack) {
      log.e('Failed to download file', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Check if a file exists on WebDAV server
  Future<bool> fileExists(String remotePath) async {
    try {
      final dio = Dio();
      await dio.fetch(
        RequestOptions(
          path: '$baseUrl$remotePath',
          method: 'PROPFIND',
          headers: {..._headers, 'Depth': '0'},
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      return true;
    } on DioException catch (e, stack) {
      throw _extractDioErrorMsg(
        e,
        remotePath,
        stack,
        operation: 'File exists check',
      );
    } catch (e) {
      log.w('File exists check failed: $remotePath', error: e);
      return false;
    }
  }

  /// List files in a directory
  Future<List<String>> listDirectory(String path) async {
    try {
      final dio = Dio();
      final response = await dio.fetch<String>(
        RequestOptions(
          path: '$baseUrl$path',
          method: 'PROPFIND',
          headers: {..._headers, 'Depth': '1'},
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
          responseType: ResponseType.plain,
        ),
      );

      // Parse XML response
      final document = XmlDocument.parse(response.data!);
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
    } on DioException catch (e, stack) {
      throw _extractDioErrorMsg(e, path, stack, operation: 'List directory');
    } catch (e, stack) {
      log.e('Failed to list directory', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Exception _extractDioErrorMsg(
    DioException e,
    String remotePath,
    StackTrace stack, {
    String operation = 'operation',
  }) {
    final errorMessage = switch (e.type) {
      DioExceptionType.connectionTimeout =>
        'Connection timeout during $operation: $remotePath',
      DioExceptionType.sendTimeout => '$operation timeout: $remotePath',
      DioExceptionType.receiveTimeout =>
        'Server response timeout during $operation: $remotePath',
      DioExceptionType.badResponse =>
        '$operation failed: ${e.response?.statusCode} - ${e.response?.statusMessage}',
      DioExceptionType.cancel => '$operation cancelled: $remotePath',
      DioExceptionType.connectionError =>
        'Connection error during $operation: $remotePath',
      _ => '$operation failed: ${e.message}',
    };

    log.e(errorMessage, error: e, stackTrace: stack);
    return Exception(errorMessage);
  }
}
