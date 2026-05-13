import Testing
@testable import UITestingCore

/// These tests verify that the right capability protocol conformances are in
/// place. They use `is any P.Type` which the Swift compiler can often resolve
/// at compile time — that's intentional: when these checks resolve at compile
/// time, the conformance is provably present. Compile-fail tests for the
/// negative cases (e.g. `Button.typeText` should not compile) will live in
/// `Tests/CompileGuards/` in a future version.
@Suite("Capability protocol conformances")
struct CapabilityGatingTests {

    @Test func button_isTappable() {
        #expect((Button.self as Any) is any TappableKind.Type)
    }

    @Test func button_isNotTyping() {
        #expect(!((Button.self as Any) is any TypingKind.Type))
    }

    @Test func textField_isTappableAndTyping() {
        #expect((TextField.self as Any) is any TappableKind.Type)
        #expect((TextField.self as Any) is any TypingKind.Type)
    }

    @Test func staticText_isNotTappable() {
        #expect(!((StaticText.self as Any) is any TappableKind.Type))
        #expect(!((StaticText.self as Any) is any TypingKind.Type))
    }

    @Test func anyElement_isAllCapabilities() {
        let kindAny: Any = AnyElement.self
        #expect(kindAny is any TappableKind.Type)
        #expect(kindAny is any TypingKind.Type)
        #expect(kindAny is any ToggleableKind.Type)
        #expect(kindAny is any SwipeableKind.Type)
        #expect(kindAny is any ScrollableKind.Type)
        #expect(kindAny is any AdjustableKind.Type)
        #expect(kindAny is any KeyInputKind.Type)
    }
}
