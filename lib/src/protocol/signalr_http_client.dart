import 'dart:async';

import '../core/abort_controller.dart';
import 'ihub_protocol.dart';

/// Represents an HTTP request.
class SignalRHttpRequest {
  String? method;
  String? url;
  Object? content;
  MessageHeaders? headers;
  IAbortSignal? abortSignal;
  int? timeout;

  SignalRHttpRequest({
    String? method,
    String? url,
    Object? content,
    MessageHeaders? headers,
    IAbortSignal? abortSignal,
    int? timeout,
  })  : method = method,
        url = url,
        content = content,
        headers = headers,
        abortSignal = abortSignal,
        timeout = timeout;
}

/// Represents an HTTP response.
class SignalRHttpResponse {
  final int statusCode;
  final String? statusText;
  final Object? content;

  SignalRHttpResponse(
    int statusCode, {
    String? statusText = '',
    Object? content,
  })  : statusCode = statusCode,
        statusText = statusText,
        content = content;
}

/// Abstraction over an HTTP client.
abstract class SignalRHttpClient {
  Future<SignalRHttpResponse> get(String url,
      {required SignalRHttpRequest options}) {
    options.method = 'GET';
    options.url = url;
    return send(options);
  }

  Future<SignalRHttpResponse> post(String? url,
      {required SignalRHttpRequest options}) {
    options.method = 'POST';
    options.url = url;
    return send(options);
  }

  Future<SignalRHttpResponse> delete(String? url,
      {required SignalRHttpRequest options}) {
    options.method = 'DELETE';
    options.url = url;
    return send(options);
  }

  Future<SignalRHttpResponse> send(SignalRHttpRequest request);
}
