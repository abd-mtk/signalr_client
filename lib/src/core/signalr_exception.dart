import 'package:flutter/foundation.dart';

import 'errors.dart';

/// Wraps values thrown on the web or from interop that are not Dart [Exception]
/// instances, so callers can rely on [Exception] in `catch` and callbacks.
///
/// Use [original] for debugging or advanced handling; [message] is safe to show.
class SignalRError implements Exception {
  final String message;
  final Object? original;
  final StackTrace? stackTrace;

  SignalRError(
    this.message, {
    this.original,
    this.stackTrace,
  });

  @override
  String toString() => message;
}

/// On web (DDC), JS values can satisfy `is Exception` while still failing
/// `as Exception?` at async boundaries ([LegacyJavaScriptObject], etc.).
bool _isWebJsValueMisTypedAsException(Exception error) {
  if (!kIsWeb) return false;
  final name = error.runtimeType.toString();
  return name.contains('LegacyJavaScript') ||
      name.contains('JavaScriptObject') ||
      name == 'JSObject' ||
      name.contains('Interop');
}

/// Converts any thrown value to an [Exception] for consistent handling.
///
/// Preserves [HttpError], [AbortError], [TimeoutError], [GeneralError], etc.
Exception toSignalRException(Object? error, [StackTrace? stackTrace]) {
  if (error == null) {
    return SignalRError('Unknown error', stackTrace: stackTrace);
  }
  if (error is Exception) {
    if (_isWebJsValueMisTypedAsException(error)) {
      return SignalRError(
        error.toString(),
        original: error,
        stackTrace: stackTrace,
      );
    }
    return error;
  }
  if (error is String) {
    return GeneralError(error);
  }
  try {
    return SignalRError(
      error.toString(),
      original: error,
      stackTrace: stackTrace,
    );
  } catch (_) {
    return SignalRError(
      'Unknown platform error',
      original: error,
      stackTrace: stackTrace,
    );
  }
}
