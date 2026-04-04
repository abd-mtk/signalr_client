import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_netcore/signalr_client.dart';

void main() {
  group('TextMessageFormat.parse', () {
    test('empty input throws (no RangeError)', () {
      expect(
        () => TextMessageFormat.parse(''),
        throwsA(isA<Exception>()),
      );
    });

    test('incomplete message without record separator throws', () {
      expect(
        () => TextMessageFormat.parse('{"type":1}'),
        throwsA(isA<Exception>()),
      );
    });

    test('single complete frame parses', () {
      final written = TextMessageFormat.write('{"type":6}');
      final messages = TextMessageFormat.parse(written);
      expect(messages, ['{"type":6}']);
    });
  });

  group('DefaultRetryPolicy.nextRetryDelayInMilliseconds', () {
    test('returns null when previousRetryCount is out of range (high)', () {
      final policy = DefaultRetryPolicy();
      final ctx = RetryContext(0, 99, GeneralError('x'));
      expect(policy.nextRetryDelayInMilliseconds(ctx), isNull);
    });

    test('returns null when previousRetryCount is negative', () {
      final policy = DefaultRetryPolicy();
      final ctx = RetryContext(0, -1, GeneralError('x'));
      expect(policy.nextRetryDelayInMilliseconds(ctx), isNull);
    });

    test('custom delays: stops at appended null sentinel', () {
      final policy = DefaultRetryPolicy(retryDelays: [100, 200]);
      expect(policy.nextRetryDelayInMilliseconds(
            RetryContext(0, 0, GeneralError('a')),
          ),
          100);
      expect(policy.nextRetryDelayInMilliseconds(
            RetryContext(0, 1, GeneralError('a')),
          ),
          200);
      expect(policy.nextRetryDelayInMilliseconds(
            RetryContext(0, 2, GeneralError('a')),
          ),
          isNull);
      expect(policy.nextRetryDelayInMilliseconds(
            RetryContext(0, 3, GeneralError('a')),
          ),
          isNull);
    });
  });

  group('parseMessageTypeFromString', () {
    test('unknown numeric type includes value in error', () {
      expect(
        () => parseMessageTypeFromString(99),
        throwsA(
          predicate<GeneralError>(
            (e) => e.toString().contains('99'),
          ),
        ),
      );
    });
  });

  group('urlWithCacheBuster', () {
    test('uses ? when url has no query string', () {
      const base = 'https://example.com/hub';
      final u = urlWithCacheBuster(base);
      expect(u.startsWith('$base?'), isTrue);
      expect(u.contains('_='), isTrue);
    });

    test('uses & when url already has query', () {
      const base = 'https://example.com/hub?id=abc';
      final u = urlWithCacheBuster(base);
      expect(u.startsWith('$base&'), isTrue);
      expect(u.contains('_='), isTrue);
    });

    test('empty url returns empty', () {
      expect(urlWithCacheBuster(''), '');
    });
  });

  group('JsonHubProtocol.createMessageHeadersFromJson', () {
    test('non-map headers become null (no throw)', () {
      expect(JsonHubProtocol.createMessageHeadersFromJson('not-a-map'), isNull);
      expect(JsonHubProtocol.createMessageHeadersFromJson(42), isNull);
    });

    test('map with non-string values stringifies keys and values', () {
      final h = JsonHubProtocol.createMessageHeadersFromJson(<String, dynamic>{
        'a': 1,
        'b': true,
      });
      expect(h, isNotNull);
      expect(h!.getHeaderValue('a'), '1');
      expect(h.getHeaderValue('b'), 'true');
    });
  });
}
