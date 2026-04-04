import 'dart:async';

import 'errors.dart';

/// Specifies a specific HTTP transport type.
enum HttpTransportType {
  /// Specified no transport preference.
  None,

  /// Specifies the WebSockets transport.
  WebSockets,

  /// Specifies the Server-Sent Events transport.
  ServerSentEvents,

  /// Specifies the Long Polling transport.
  LongPolling,
}

HttpTransportType httpTransportTypeFromString(String? value) {
  if (value == null || value == "") {
    return HttpTransportType.None;
  }

  value = value.toUpperCase();
  switch (value) {
    case "WEBSOCKETS":
      return HttpTransportType.WebSockets;
    case "SERVERSENTEVENTS":
      return HttpTransportType.ServerSentEvents;
    case "LONGPOLLING":
      return HttpTransportType.LongPolling;
    default:
      throw GeneralError("$value is not a supported HttpTransportType");
  }
}

/// Specifies the transfer format for a connection.
enum TransferFormat {
  /// TransferFormat is not defined.
  Undefined,

  /// Specifies that only text data will be transmitted over the connection.
  Text,

  /// Specifies that binary data will be transmitted over the connection.
  Binary,
}

TransferFormat getTransferFormatFromString(String? value) {
  if (value == null || value == "") {
    return TransferFormat.Undefined;
  }

  value = value.toUpperCase();
  switch (value) {
    case "TEXT":
      return TransferFormat.Text;
    case "BINARY":
      return TransferFormat.Binary;
    default:
      throw GeneralError("$value is not a supported TransferFormat");
  }
}

/// Data received call back.
/// data: the content. Either a string (json) or Uint8List (binary)
typedef OnReceive = void Function(Object? data);

typedef OnClose = void Function({Exception? error});

typedef AccessTokenFactory = Future<String> Function();

/// An abstraction over the behavior of transports.
abstract class ITransport {
  Future<void> connect(String? url, TransferFormat transferFormat);

  /// data: the content. Either a string (json) or Uint8List (binary)
  Future<void> send(Object data);
  Future<void> stop();
  OnReceive? onReceive;
  OnClose? onClose;
}
