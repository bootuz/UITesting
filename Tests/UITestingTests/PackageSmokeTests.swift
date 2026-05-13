#if canImport(XCTest) && (os(iOS) || os(macOS) || os(tvOS) || os(visionOS))

import Testing
import UITesting

/// Smoke test that the adapter package compiles and re-exports work. Real
/// adapter behavior is covered by simulator-only tests gated by the
/// Fixtures/SampleApp target (not in v0.1's host CI).
@Suite("Package smoke")
struct PackageSmokeTests {

    @Test func publicTypesAreReachable() {
        _ = TimeoutPolicy.default
        _ = FailureDiagnostics.standard
        _ = Button.tag
    }
}

#endif
