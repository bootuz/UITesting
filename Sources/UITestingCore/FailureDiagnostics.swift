/// Diagnostics level applied to `LocatorError` rendering.
///
/// `.verbose` triggers an extra `Driver.enumerate(kind:)` query on failure,
/// which is expensive but only runs when a test is already failing.
public enum FailureDiagnostics: Sendable, Equatable {
    case standard
    case verbose
}
