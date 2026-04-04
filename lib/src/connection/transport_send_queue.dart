import 'dart:async';
import 'dart:typed_data';

import '../core/errors.dart';
import '../core/itransport.dart';
import '../core/signalr_exception.dart';

class TransportSendQueue {
  List<Object?> _buffer = [];
  late Completer<void> _sendBufferedData;
  bool _executing = true;
  Completer<void>? _transportResult;
  Future<void>? _sendLoopPromise;
  final ITransport transport;

  TransportSendQueue(this.transport) {
    _sendBufferedData = Completer<void>();
    _transportResult = Completer<void>();
    _sendLoopPromise = _sendLoop();
  }

  Future<void> send(Object? data) {
    _bufferData(data);
    var result = _transportResult;
    if (result == null) {
      result = Completer<void>();
      _transportResult = result;
    }
    return result.future;
  }

  Future<void>? stop() {
    _executing = false;
    if (!_sendBufferedData.isCompleted) _sendBufferedData.complete();
    return _sendLoopPromise;
  }

  void _bufferData(Object? data) {
    if (data is Uint8List &&
        _buffer.isNotEmpty &&
        _buffer[0] is! Uint8List) {
      throw GeneralError(
        "Expected data to be of type ${_buffer[0].runtimeType} but got Uint8List",
      );
    } else if (data is String &&
        _buffer.isNotEmpty &&
        _buffer[0] is! String) {
      throw GeneralError(
        "Expected data to be of type ${_buffer[0].runtimeType} but got String",
      );
    }

    _buffer.add(data);
    if (!_sendBufferedData.isCompleted) _sendBufferedData.complete();
  }

  Future<void> _sendLoop() async {
    while (true) {
      await _sendBufferedData.future;

      if (!_executing) {
        final pending = _transportResult;
        if (pending != null && !pending.isCompleted) {
          pending.completeError(GeneralError('Connection stopped.'));
        }
        break;
      }

      _sendBufferedData = Completer<void>();

      final transportResult = _transportResult;
      if (transportResult == null) break;
      _transportResult = null;

      if (_buffer.isEmpty) {
        if (!transportResult.isCompleted) {
          transportResult.complete();
        }
        continue;
      }

      final data = _buffer[0] is String
          ? _buffer.join("")
          : TransportSendQueue.concatBuffers(
              List<Uint8List?>.from(_buffer),
            );

      _buffer.clear();

      try {
        await transport.send(data);
        if (!transportResult.isCompleted) transportResult.complete();
      } catch (error, st) {
        if (!transportResult.isCompleted) {
          transportResult.completeError(toSignalRException(error, st));
        }
      }
    }
  }

  static Uint8List concatBuffers(List<Uint8List?> arrayBuffers) {
    final segments = <Uint8List>[];
    for (final b in arrayBuffers) {
      if (b == null) {
        throw GeneralError('concatBuffers: null buffer segment');
      }
      segments.add(b);
    }
    var totalLength = 0;
    for (final b in segments) {
      totalLength += b.lengthInBytes;
    }
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final item in segments) {
      result.setAll(offset, item);
      offset += item.lengthInBytes;
    }
    return result;
  }
}
