import Foundation

/// Bridge between the framework-agnostic core and a concrete UI testing
/// backend (e.g. XCUITest).
///
/// Implementations are constructed once per test and held by the
/// `UITestingTestCase`. The `reporter` carries `LocatorError` instances
/// produced by matchers and action auto-wait back to the test runner.
public protocol Driver: AnyObject, Sendable {

    /// Resolve a query and read all attributes in one shot.
    ///
    /// Implementations should always re-resolve (no caching) — the locator's
    /// laziness depends on every call returning a fresh snapshot of the
    /// element tree. Reading multiple attributes per call is encouraged
    /// when the backend can do so cheaply.
    func resolve(_ query: ElementQuery) -> ElementSnapshot

    /// Perform an action, re-resolving the query inside the call. Throws if
    /// the element is not present or the action fails. Implementations should
    /// not retry — the auto-wait loop is the caller's responsibility.
    func perform(_ action: ElementAction, on query: ElementQuery) throws

    /// Per-test reporter used by matchers to record failures.
    var reporter: any FailureReporter { get }

    /// Active diagnostic mode. When `.verbose`, matchers should populate
    /// `LocatorError.diagnostics` via `enumerate(kind:)`.
    var diagnostics: FailureDiagnostics { get }

    /// Enumerate currently-present elements of a given kind. Used by
    /// `.verbose` mode to build "did you mean X?" hints on failure.
    /// Expensive — only invoked when a failure is already imminent.
    func enumerate(kind: ElementKindTag) -> [ElementAttributes]
}
