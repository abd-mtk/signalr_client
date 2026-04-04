import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../core/itransport.dart';
import '../protocol/ihub_protocol.dart';
import '../protocol/signalr_http_client.dart';

bool isIntEmpty(int? value) {
  return value == null;
}

bool isStringEmpty(String? value) {
  return value == null || value.isEmpty;
}

bool isListEmpty(List? value) {
  return value == null || value.isEmpty;
}

/// Appends a cache-buster using `?` or `&` depending on whether [url] already has a query string.
///
/// Returns [url] unchanged if it is empty (caller should reject invalid URLs earlier).
String urlWithCacheBuster(String url) {
  if (url.isEmpty) return url;
  final sep = url.contains('?') ? '&' : '?';
  return '$url${sep}_=${DateTime.now()}';
}

String getDataDetail(Object? data, bool includeContent) {
  var detail = "";
  if (data is Uint8List) {
    detail = "Binary data of length ${data.lengthInBytes}";
    if (includeContent) {
      detail += ". Content: '${formatArrayBuffer(data)}'";
    }
  } else if (data is String) {
    detail = "String data of length ${data.length}";
    if (includeContent) {
      detail += ". Content: '$data'";
    }
  } else if (data != null) {
    detail = "Data of type ${data.runtimeType}";
  }
  return detail;
}

/// Safe summary for HTTP logging (handles String and Uint8List).
String httpContentSummary(Object? content) {
  return getDataDetail(content, false);
}

String formatArrayBuffer(Uint8List data) {
  var str = "";
  for (final val in data) {
    var pad = val < 16 ? "0" : "";
    str += "0x$pad${val.toString()} ";
  }
  if (str.isEmpty) return "";
  return str.substring(0, str.length - 1);
}

Future<void> sendMessage(
  Logger logger,
  String transportName,
  SignalRHttpClient httpClient,
  String? url,
  AccessTokenFactory? accessTokenFactory,
  Object content,
  bool logMessageContent,
) async {
  final headers = MessageHeaders();
  final tokenFactory = accessTokenFactory;
  if (tokenFactory != null) {
    final token = await tokenFactory();
    if (!isStringEmpty(token)) {
      headers.setHeaderValue("Authorization", "Bearer $token");
    }
  }

  logger.finest("($transportName transport) sending data.");

  final req = SignalRHttpRequest(content: content, headers: headers);
  final response = await httpClient.post(url, options: req);

  logger.finest(
    "($transportName transport) request complete. Response status: ${response.statusCode}.",
  );
}
