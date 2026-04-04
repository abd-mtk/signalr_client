import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_netcore/signalr_client.dart';

void main() {
  group('toSignalRException', () {
    test('preserves Exception subclasses', () {
      final e = HttpError('bad', 500);
      expect(toSignalRException(e), same(e));
    });

    test('wraps arbitrary object as SignalRError', () {
      final wrapped = toSignalRException(Object());
      expect(wrapped, isA<SignalRError>());
      expect((wrapped as SignalRError).original, isNotNull);
    });

    test('maps String to GeneralError', () {
      final e = toSignalRException('oops');
      expect(e, isA<GeneralError>());
      expect(e.toString(), 'oops');
    });

    test('null becomes SignalRError', () {
      final e = toSignalRException(null);
      expect(e, isA<SignalRError>());
    });
  });
}
