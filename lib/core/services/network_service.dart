import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final String? endpoint;
  final Object? originalError;

  NetworkException({
    required this.message,
    this.statusCode,
    this.endpoint,
    this.originalError,
  });

  @override
  String toString() => 'NetworkException: $message (status: $statusCode, endpoint: $endpoint)';
}

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  late final Dio _dio;
  bool _initialized = false;

  void init({
    required String baseUrl,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration receiveTimeout = const Duration(seconds: 30),
    Map<String, String>? defaultHeaders,
  }) {
    if (_initialized) return;

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?defaultHeaders,
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          // `handler.next` must receive a DioException. Carry our typed,
          // user-presentable exception as its payload so callers can read
          // `(e as DioException).error as NetworkException`.
          handler.next(error.copyWith(error: _handleError(error)));
        },
      ),
    );

    _initialized = true;
  }

  Dio get dio {
    if (!_initialized) {
      throw StateError('NetworkService not initialized. Call init() first.');
    }
    return _dio;
  }

  NetworkException _handleError(DioException error) {
    String message;
    int? statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timed out. Please check your internet connection.';
        break;
      case DioExceptionType.connectionError:
        message = 'No internet connection. Please check your network settings.';
        break;
      case DioExceptionType.badResponse:
        final data = error.response?.data;
        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        } else {
          message = 'Server error (${error.response?.statusCode}). Please try again later.';
        }
        break;
      case DioExceptionType.cancel:
        message = 'Request was cancelled.';
        break;
      case DioExceptionType.unknown:
        message = 'An unexpected error occurred. Please try again.';
        break;
      default:
        message = 'Network error: ${error.message}';
    }

    return NetworkException(
      message: message,
      statusCode: statusCode,
      endpoint: error.requestOptions.path,
      originalError: error,
    );
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    return response.data!;
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return response.data!;
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
    return response.data!;
  }

  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
    return response.data!;
  }

  void addAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void removeAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}

class ApiResponse<T> {
  final T? data;
  final NetworkException? error;
  final bool isLoading;

  const ApiResponse({
    this.data,
    this.error,
    this.isLoading = false,
  });

  factory ApiResponse.loading() => const ApiResponse(isLoading: true);
  factory ApiResponse.success(T data) => ApiResponse(data: data);
  factory ApiResponse.error(NetworkException error) => ApiResponse(error: error);

  bool get hasError => error != null;
  bool get hasData => data != null;
}

class NetworkStateWidget<T> extends StatelessWidget {
  final Future<ApiResponse<T>> Function() future;
  final Widget Function(T data) onSuccess;
  final Widget Function(NetworkException error, VoidCallback onRetry) onError;
  final Widget? onLoading;
  final Widget? onInitial;

  const NetworkStateWidget({
    super.key,
    required this.future,
    required this.onSuccess,
    required this.onError,
    this.onLoading,
    this.onInitial,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApiResponse<T>>(
      future: future(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return onLoading ??
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading...'),
                  ],
                ),
              );
        }

        if (snapshot.hasError) {
          return onError(
            NetworkException(
              message: snapshot.error.toString(),
              originalError: snapshot.error,
            ),
            () => (context as Element).rebuild(),
          );
        }

        final response = snapshot.data;
        if (response == null) {
          return onInitial ?? const SizedBox.shrink();
        }

        if (response.hasError) {
          return onError(response.error!, () => (context as Element).rebuild());
        }

        if (response.hasData) {
          return onSuccess(response.data as T);
        }

        return onInitial ?? const SizedBox.shrink();
      },
    );
  }
}

class RetryableErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String? retryLabel;
  final IconData? icon;

  const RetryableErrorWidget({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel ?? 'Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
