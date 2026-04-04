abstract class IRetryPolicy {
  int? nextRetryDelayInMilliseconds(RetryContext retryContext);
}

class RetryContext {
  final int elapsedMilliseconds;
  final int previousRetryCount;
  final Exception retryReason;

  RetryContext(
    this.elapsedMilliseconds,
    this.previousRetryCount,
    this.retryReason,
  );
}

class DefaultRetryPolicy implements IRetryPolicy {
  late List<int?> _retryDelays;

  static const List<int?> DEFAULT_RETRY_DELAYS_IN_MILLISECONDS = [
    0,
    2000,
    10000,
    30000,
    null,
  ];

  DefaultRetryPolicy({List<int>? retryDelays}) {
    _retryDelays = retryDelays != null
        ? [...retryDelays, null]
        : DEFAULT_RETRY_DELAYS_IN_MILLISECONDS;
  }

  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) {
    final i = retryContext.previousRetryCount;
    if (i < 0 || i >= _retryDelays.length) {
      return null;
    }
    return _retryDelays[i];
  }
}
