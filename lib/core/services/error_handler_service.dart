import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ErrorHandlerService {
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  factory ErrorHandlerService() => _instance;
  ErrorHandlerService._internal();

  static bool _initialized = false;

  /// Installs the global error handlers. Call once, from `main()`.
  ///
  /// Idempotent, and it deliberately does **not** replace [debugPrint]. An
  /// earlier version did, which routed every framework diagnostic — including
  /// `RenderFlex overflowed` warnings — into a custom sink where nobody saw
  /// them. Framework output goes to the console; this class adds to it.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Chained, not replaced: whatever was installed before us — the test
    // binding's collector, an embedder's reporter — still gets the error.
    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _instance._handleFlutterError(details);
      previousFlutterError?.call(details);
    };

    final previousPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _instance._handlePlatformError(error, stack);
      return previousPlatformError?.call(error, stack) ?? true;
    };
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    final error = details.exception;
    final stack = details.stack;

    _log('FLUTTER_ERROR', error.toString(), stack: stack, context: details.context);

    if (kReleaseMode) {
      _sendToCrashReporting(error, stack, details.context);
    }
    // In debug the chained handler above presents it; presenting here too
    // would print every error twice.
  }

  void _handlePlatformError(Object error, StackTrace stack) {
    _log('PLATFORM_ERROR', error.toString(), stack: stack);

    if (kReleaseMode) {
      _sendToCrashReporting(error, stack, null);
    }
  }

  void _log(String type, String message, {StackTrace? stack, DiagnosticsNode? context}) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '''
[$timestamp] [$type]
$message
${stack != null ? 'Stack: $stack' : ''}
${context != null ? 'Context: $context' : ''}
---''';

    if (kDebugMode) {
      debugPrint(logEntry);
    }

    _storeLocalLog(logEntry);
  }

  void _storeLocalLog(String logEntry) {
    // In a real app, you'd use a logging package like logger or sentry
    // For now, we just print to console
  }

  void _sendToCrashReporting(Object error, StackTrace? stack, DiagnosticsNode? context) {
    // TODO: Integrate with crash reporting service (Sentry, Firebase Crashlytics, etc.)
    // Example:
    // Sentry.captureException(error, stackTrace: stack);
    // FirebaseCrashlytics.instance.recordError(error, stack);
  }

  static void recordError(Object error, StackTrace? stack, {String? reason}) {
    _instance._log('MANUAL_ERROR', '${reason ?? ''} $error', stack: stack);
    if (kReleaseMode) {
      _instance._sendToCrashReporting(error, stack, null);
    }
  }

  static Future<T> runGuarded<T>(Future<T> Function() action, {T? fallback}) async {
    try {
      return await action();
    } catch (error, stack) {
      recordError(error, stack);
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  static T runGuardedSync<T>(T Function() action, {T? fallback}) {
    try {
      return action();
    } catch (error, stack) {
      recordError(error, stack);
      if (fallback != null) return fallback;
      rethrow;
    }
  }
}

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stack, VoidCallback onRetry)? fallbackBuilder;
  final void Function(Object error, StackTrace? stack)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallbackBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stack;

  // No `ErrorHandlerService.initialize()` here. Global error handling is
  // installed once in `main()`; a widget reaching out to mutate it on every
  // mount both stamps on whatever the host installed and makes this widget
  // impossible to pump in a test.

  void _retry() {
    setState(() {
      _error = null;
      _stack = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.fallbackBuilder != null) {
        return widget.fallbackBuilder!(_error!, _stack, _retry);
      }

      return _DefaultErrorFallback(
        error: _error!,
        stack: _stack,
        onRetry: _retry,
      );
    }

    return widget.child;
  }
}

class _DefaultErrorFallback extends StatelessWidget {
  final Object error;
  final StackTrace? stack;
  final VoidCallback onRetry;

  const _DefaultErrorFallback({
    required this.error,
    this.stack,
    required this.onRetry,
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
              Icons.error_outline,
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
              kDebugMode ? error.toString() : 'An unexpected error occurred',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (kDebugMode && stack != null) ...[
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: SelectableText(
                    stack.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();
  factory GlobalErrorHandler() => _instance;
  GlobalErrorHandler._internal();

  void setupGlobalHandlers() {
    ErrorHandlerService.initialize();
  }
}