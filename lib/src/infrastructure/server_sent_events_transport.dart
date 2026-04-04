import 'dart:async';

import 'package:logging/logging.dart';
import 'package:sse_channel/sse_channel.dart';

import '../core/errors.dart';
import '../core/itransport.dart';
import '../core/signalr_exception.dart';
import '../protocol/signalr_http_client.dart';
import '../shared/utils.dart';

class ServerSentEventsTransport implements ITransport {
  final SignalRHttpClient _httpClient;
  final AccessTokenFactory? _accessTokenFactory;
  final Logger _logger;
  final bool _logMessageContent;
  SseChannel? _sseClient;
  StreamSubscription<dynamic>? _subscription;
  String? _url;
  bool _onCloseRaised = false;

  @override
  OnClose? onClose;

  @override
  OnReceive? onReceive;

  ServerSentEventsTransport(
    SignalRHttpClient httpClient,
    AccessTokenFactory? accessTokenFactory,
      Logger logger,
    bool logMessageContent,
  )   : _httpClient = httpClient,
        _accessTokenFactory = accessTokenFactory,
        _logger = logger,
        _logMessageContent = logMessageContent;

  void _raiseOnClose([Object? error, StackTrace? st]) {
    if (_onCloseRaised) return;
    _onCloseRaised = true;

    final Exception? ex =
        error == null ? null : toSignalRException(error, st);
    onClose?.call(error: ex);
  }

  @override
  Future<void> connect(String? url, TransferFormat transferFormat) async {
    if (url == null || isStringEmpty(url)) {
      return Future.error(ArgumentError('A non-empty url is required'));
    }
    _logger.finest("(SSE transport) Connecting");

    _url = url;
    var connectUrl = url;

    final tokenFactory = _accessTokenFactory;
    if (tokenFactory != null) {
      final token = await tokenFactory();
      if (!isStringEmpty(token)) {
        final encodedToken = Uri.encodeComponent(token);
        connectUrl = connectUrl +
            (connectUrl.contains('?') ? '&' : '?') +
            "access_token=$encodedToken";
      }
    }

    if (transferFormat != TransferFormat.Text) {
      return Future.error(
        GeneralError(
          "The Server-Sent Events transport only supports the 'Text' transfer format",
        ),
      );
    }

    try {
      final client = SseChannel.connect(Uri.parse(connectUrl));
      _logger.finer('(SSE transport) connected to $connectUrl');
      _sseClient = client;

      _subscription = client.stream.listen(
        (dynamic data) {
          final recv = onReceive;
          if (recv != null) {
            try {
              _logger.finest(
                '(SSE transport) data received. ${getDataDetail(data, _logMessageContent)}.',
              );
              recv(data);
            } catch (error, st) {
              unawaited(_close(error: toSignalRException(error, st)));
            }
          }
        },
        onError: (Object e, StackTrace st) {
          _logger.severe('(SSE transport) error when listening to stream: $e');
          unawaited(_close(error: toSignalRException(e, st)));
        },
        onDone: () {
          unawaited(_close());
        },
        cancelOnError: false,
      );
    } catch (e, st) {
      return Future.error(toSignalRException(e, st));
    }
  }

  @override
  Future<void> send(Object data) async {
    if (_sseClient == null) {
      return Future.error(
        GeneralError("Cannot send until the transport is connected"),
      );
    }
    await sendMessage(
      _logger,
      "SSE",
      _httpClient,
      _url,
      _accessTokenFactory,
      data,
      _logMessageContent,
    );
  }

  @override
  Future<void> stop() async {
    await _close();
  }

  Future<void> _close({Exception? error}) async {
    await _subscription?.cancel();
    _subscription = null;

    if (_sseClient != null) {
      _sseClient = null;
      if (error != null) {
        _raiseOnClose(error);
      } else {
        _raiseOnClose();
      }
    }
  }
}
