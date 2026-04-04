import 'dart:typed_data';
import 'package:logging/logging.dart';
import "package:message_pack_dart/message_pack_dart.dart" as msgpack;

import '../core/errors.dart';
import '../core/itransport.dart';
import 'binary_message_format.dart';
import 'ihub_protocol.dart';

const String MSGPACK_HUB_PROTOCOL_NAME = "messagepack";
const int PROTOCOL_VERSION = 1;
const TransferFormat TRANSFER_FORMAT = TransferFormat.Binary;

class MessagePackHubProtocol implements IHubProtocol {
  @override
  String get name => MSGPACK_HUB_PROTOCOL_NAME;
  @override
  TransferFormat get transferFormat => TRANSFER_FORMAT;

  @override
  int get version => PROTOCOL_VERSION;

  static const _errorResult = 1;
  static const _voidResult = 2;
  static const _nonVoidResult = 3;

  @override
  List<HubMessageBase> parseMessages(Object input, Logger logger) {
    if (!(input is Uint8List)) {
      throw new GeneralError(
          "Invalid input for MessagePack hub protocol. Expected an Uint8List.");
    }

    final binaryInput = input;
    final List<HubMessageBase> hubMessages = [];

    final messages = BinaryMessageFormat.parse(binaryInput);
    if (messages.isEmpty) {
      throw GeneralError('No MessagePack frames in payload.');
    }

    for (var message in messages) {
      if (message.isEmpty) {
        throw GeneralError('Empty MessagePack frame in payload.');
      }

      final unpackedData = msgpack.deserialize(message);
      List<dynamic> unpackedList;
      if (unpackedData == null) {
        throw GeneralError('MessagePack deserialized to null.');
      }
      try {
        unpackedList = List<dynamic>.from(unpackedData as List<dynamic>);
      } catch (_) {
        throw GeneralError("Invalid payload.");
      }
      if (unpackedList.isEmpty) {
        throw GeneralError('MessagePack message array is empty.');
      }
      final messageObj = _parseMessage(unpackedList, logger);
      if (messageObj != null) {
        hubMessages.add(messageObj);
      }
    }
    return hubMessages;
  }

  static HubMessageBase? _parseMessage(List<dynamic> data, Logger logger) {
    if (data.length == 0) {
      throw new GeneralError("Invalid payload.");
    }
    HubMessageBase? messageObj;

    final messageType = data[0] as int;

    if (messageType == MessageType.Invocation.index) {
      messageObj = _createInvocationMessage(data);
      return messageObj;
    }

    if (messageType == MessageType.StreamInvocation.index) {
      messageObj = _createStreamInvocationMessage(data);
      return messageObj;
    }

    if (messageType == MessageType.StreamItem.index) {
      messageObj = _createStreamItemMessage(data);
      return messageObj;
    }

    if (messageType == MessageType.Completion.index) {
      messageObj = _createCompletionMessage(data);
      return messageObj;
    }

    if (messageType == MessageType.Ping.index) {
      messageObj = _createPingMessage(data);
      return messageObj;
    }

    if (messageType == MessageType.Close.index) {
      messageObj = _createCloseMessage(data);
      return messageObj;
    } else {
      // Future protocol changes can add message types, old clients can ignore them
      logger.info("Unknown message type '$messageType' ignored.");
      return messageObj;
    }
  }

  static MessageHeaders createMessageHeaders(List<dynamic> data) {
    if (data.length < 2) {
      throw GeneralError("Invalid headers");
    }
    final raw = data[1];
    if (raw == null) return MessageHeaders();
    if (raw is! Map) {
      throw GeneralError("Invalid headers");
    }
    final headers = MessageHeaders();
    for (final entry in raw.entries) {
      headers.setHeaderValue(
        entry.key.toString(),
        entry.value?.toString() ?? '',
      );
    }
    return headers;
  }

  static InvocationMessage _createInvocationMessage(List<dynamic> data) {
    if (data.length < 5) {
      throw GeneralError("Invalid payload for Invocation message.");
    }

    final MessageHeaders? headers = createMessageHeaders(data);

    final message = InvocationMessage(
        target: data[3] as String?,
        headers: headers,
        invocationId: data[2] as String?,
        streamIds: [],
        arguments: List<Object?>.from(data[4] as List));

    return message;
  }

  static StreamInvocationMessage _createStreamInvocationMessage(
      List<dynamic> data) {
    if (data.length < 5) {
      throw GeneralError("Invalid payload for StreamInvocation message.");
    }

    final MessageHeaders? headers = createMessageHeaders(data);

    return StreamInvocationMessage(
      target: data[3] as String?,
      headers: headers,
      invocationId: data[2] as String?,
      arguments: List<Object?>.from(data[4] as List),
      streamIds: data.length > 5
          ? List<String>.from(data[5] as List)
          : null,
    );
  }

  static StreamItemMessage _createStreamItemMessage(List<dynamic> data) {
    if (data.length < 4) {
      throw GeneralError("Invalid payload for StreamItem message.");
    }
    final MessageHeaders? headers = createMessageHeaders(data);
    final message = StreamItemMessage(
      item: data[3] as Object?,
      headers: headers,
      invocationId: data[2] as String?,
    );

    return message;
  }

  static CompletionMessage _createCompletionMessage(List<dynamic> data) {
    if (data.length < 4) {
      throw GeneralError("Invalid payload for Completion message.");
    }
    final MessageHeaders? headers = createMessageHeaders(data);
    final resultKind = data[3];
    if (resultKind != _voidResult && data.length < 5) {
      throw GeneralError("Invalid payload for Completion message.");
    }

    if (resultKind == _errorResult) {
      return CompletionMessage(
        error: data[4] as String?,
        result: null,
        headers: headers,
        invocationId: data[2] as String?,
      );
    } else if (resultKind == _nonVoidResult) {
      return CompletionMessage(
        result: data[4] as Object?,
        error: null,
        headers: headers,
        invocationId: data[2] as String?,
      );
    } else {
      return CompletionMessage(
        headers: headers,
        result: null,
        error: null,
        invocationId: data[2] as String?,
      );
    }
  }

  static PingMessage _createPingMessage(List<dynamic> data) {
    if (data.length < 1) {
      throw GeneralError("Invalid payload for Ping message.");
    }
    return PingMessage();
  }

  static CloseMessage _createCloseMessage(List<dynamic> data) {
    if (data.length < 2) {
      throw GeneralError("Invalid payload for Close message.");
    }
    if (data.length >= 3) {
      return CloseMessage(allowReconnect: data[2], error: data[1]);
    } else {
      return CloseMessage(error: data[1]);
    }
  }

  @override
  Object writeMessage(HubMessageBase message) {
    final messageType = message.type;
    switch (messageType) {
      case MessageType.Invocation:
        return _writeInvocation(message as InvocationMessage);
      case MessageType.StreamInvocation:
        return _writeStreamInvocation(message as StreamInvocationMessage);
      case MessageType.StreamItem:
        return _writeStreamItem(message as StreamItemMessage);
      case MessageType.Completion:
        return _writeCompletion(message as CompletionMessage);
      case MessageType.Ping:
        return _writePing();
      case MessageType.CancelInvocation:
        return _writeCancelInvocation(message as CancelInvocationMessage);
      default:
        throw GeneralError("Invalid message type.");
    }

    //throw GeneralError("Converting '${message.type}' is not implemented.");
  }

  static Uint8List _writeInvocation(InvocationMessage message) {
    List<dynamic> payload;

    if ((message.streamIds?.length ?? 0) > 0) {
      payload = [
        MessageType.Invocation.index,
        message.headers.asMap,
        message.invocationId,
        message.target,
        message.arguments,
        message.streamIds
      ];
    } else {
      payload = [
        MessageType.Invocation.index,
        message.headers.asMap,
        message.invocationId,
        message.target,
        message.arguments,
      ];
    }

    final packedData = msgpack.serialize(payload);
    return BinaryMessageFormat.write(packedData);
  }

  static Uint8List _writeStreamInvocation(StreamInvocationMessage message) {
    List<dynamic> payload;

    if ((message.streamIds?.length ?? 0) > 0) {
      payload = [
        MessageType.StreamInvocation.index,
        message.headers.asMap,
        message.invocationId,
        message.target,
        message.arguments,
        message.streamIds
      ];
    } else {
      payload = [
        MessageType.StreamInvocation.index,
        message.headers.asMap,
        message.invocationId,
        message.target,
        message.arguments,
      ];
    }

    final packedData = msgpack.serialize(payload);
    return BinaryMessageFormat.write(packedData);
  }

  static Uint8List _writeStreamItem(StreamItemMessage message) {
    List<dynamic> payload;

    payload = [
      MessageType.StreamItem.index,
      message.headers.asMap,
      message.invocationId,
      message.item
    ];

    final packedData = msgpack.serialize(payload);
    return BinaryMessageFormat.write(packedData);
  }

  static Uint8List _writeCompletion(CompletionMessage message) {
    List<dynamic> payload;
    final resultKind = (message.error != null)
        ? _errorResult
        : (message.result != null)
            ? _nonVoidResult
            : _voidResult;
    if (resultKind == _errorResult) {
      payload = [
        MessageType.Completion.index,
        message.headers.asMap,
        message.invocationId,
        resultKind,
        message.error
      ];
    } else if (resultKind == _nonVoidResult) {
      payload = [
        MessageType.Completion.index,
        message.headers.asMap,
        message.invocationId,
        resultKind,
        message.result
      ];
    } else {
      payload = [
        MessageType.Completion.index,
        message.headers.asMap,
        message.invocationId,
        resultKind
      ];
    }

    final packedData = msgpack.serialize(payload);
    return BinaryMessageFormat.write(packedData);
  }

  static Uint8List _writeCancelInvocation(CancelInvocationMessage message) {
    List<dynamic> payload;

    payload = [
      MessageType.CancelInvocation.index,
      message.headers.asMap,
      message.invocationId,
    ];

    final packedData = msgpack.serialize(payload);
    return BinaryMessageFormat.write(packedData);
  }

  static Uint8List _writePing() {
    List<dynamic> payload;

    payload = [
      MessageType.Ping.index,
    ];

    final packedData = msgpack.serialize(payload);
    return BinaryMessageFormat.write(packedData);
  }
}
