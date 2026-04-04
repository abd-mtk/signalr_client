/// Error thrown when an HTTP request fails.
class HttpError implements Exception {
  /// The HTTP status code represented by this error.
  final num statusCode;

  final String? message;

  HttpError(String? errorMessage, num statusCode)
      : message = errorMessage,
        statusCode = statusCode;

  @override
  String toString() {
    return "$statusCode: $message";
  }
}

/// Error thrown when a timeout elapses.
class TimeoutError implements Exception {
  final String message;

  TimeoutError([String errorMessage = "A timeout occurred."])
      : message = errorMessage;

  @override
  String toString() {
    return message;
  }
}

/// Error thrown when an action is aborted.
class AbortError implements Exception {
  final String message;

  AbortError([String message = "An abort occurred."]) : message = message;

  @override
  String toString() {
    return message;
  }
}

/// General error for SignalR client failures.
class GeneralError implements Exception {
  final String? message;

  GeneralError(String? errorMessage) : message = errorMessage;

  @override
  String toString() => message ?? 'Unknown error';
}

class NotImplementedException extends GeneralError {
  NotImplementedException() : super("Not implemented.");

  @override
  String toString() => message ?? 'Not implemented';
}

class InvalidPayloadException extends GeneralError {
  InvalidPayloadException(String errorMessage) : super(errorMessage);

  @override
  String toString() => message ?? 'Invalid payload';
}
