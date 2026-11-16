import Testing

/// Groups the tests that post the process-wide screen parameters notification.
///
/// Each post invalidates the cache of every started processor, so these tests must not run in parallel,
/// not even across suites. `.serialized` also applies to the suites nested in here.
@Suite(.serialized)
enum ScreenParametersNotificationTests {}
