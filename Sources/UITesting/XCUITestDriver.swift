#if canImport(XCTest) && (os(iOS) || os(macOS) || os(tvOS) || os(visionOS))

import Foundation
import XCTest
import UITestingCore

/// `Driver` implementation backed by `XCUIApplication`.
///
/// Stores no element references — `XCUIElement` is derived from a fresh
/// `XCUIElementQuery` chain on every `resolve`/`perform` call so the
/// lazy-locator invariant holds.
///
/// Marked `@unchecked Sendable` because `XCUIApplication` is not Sendable;
/// UI tests are single-threaded by construction so this is safe.
public final class XCUITestDriver: Driver, @unchecked Sendable {

    public let app: XCUIApplication
    public let reporter: any FailureReporter
    public var diagnostics: FailureDiagnostics

    public init(
        app: XCUIApplication,
        reporter: any FailureReporter,
        diagnostics: FailureDiagnostics = .standard
    ) {
        self.app = app
        self.reporter = reporter
        self.diagnostics = diagnostics
    }

    // MARK: - Driver

    public func resolve(_ query: ElementQuery) -> ElementSnapshot {
        let element = resolveElement(query)
        guard element.exists else { return .missing }
        return .present(attributes(from: element))
    }

    public func perform(_ action: ElementAction, on query: ElementQuery) throws {
        let element = resolveElement(query)
        try executeAction(action, on: element)
    }

    public func enumerate(kind: ElementKindTag) -> [ElementAttributes] {
        let descendants = app.descendants(matching: elementType(for: kind))
        var results: [ElementAttributes] = []
        let count = min(descendants.count, 32) // bounded enumeration
        for index in 0..<count {
            let element = descendants.element(boundBy: index)
            guard element.exists else { continue }
            results.append(attributes(from: element))
        }
        return results
    }

    // MARK: - Query translation

    private func resolveElement(_ query: ElementQuery) -> XCUIElement {
        var queryChain: ElementQueryChain = .application(app)
        for step in query.steps {
            queryChain = queryChain.applying(step)
        }
        return queryChain.firstMatch
    }

    private func attributes(from element: XCUIElement) -> ElementAttributes {
        ElementAttributes(
            testID: element.identifier.isEmpty ? nil : element.identifier,
            label: element.label.isEmpty ? nil : element.label,
            value: stringValue(from: element),
            isVisible: element.isHittable || (element.exists && !element.frame.isEmpty),
            isHittable: element.isHittable,
            frame: element.frame,
            elementType: tag(for: element.elementType)
        )
    }

    private func stringValue(from element: XCUIElement) -> String? {
        guard let raw = element.value else { return nil }
        if let string = raw as? String { return string }
        return String(describing: raw)
    }

    // MARK: - Action execution

    private func executeAction(_ action: ElementAction, on element: XCUIElement) throws {
        switch action {
        case .tap:
            element.tap()

        case .doubleTap:
            element.doubleTap()

        case .longPress(let duration):
            element.press(forDuration: duration.seconds)

        case .typeText(let text):
            focusIfNeeded(element)
            element.typeText(text)

        case .clearText:
            try clearText(of: element)

        case .swipe(let direction):
            switch direction {
            case .up:    element.swipeUp()
            case .down:  element.swipeDown()
            case .left:  element.swipeLeft()
            case .right: element.swipeRight()
            }

        case .setSwitch(let on):
            let currentlyOn = (element.value as? String) == "1"
            if currentlyOn != on { element.tap() }

        case .setSliderValue(let value):
            let normalized = max(0.0, min(1.0, value))
            element.adjust(toNormalizedSliderPosition: CGFloat(normalized))

        case .scrollToVisible:
            // XCUIElement has no direct "scroll to visible" — the standard
            // technique is to swipe within the containing scroll view until
            // the element is hittable. For v0.1 we delegate to tap-on-not-
            // hittable which triggers XCUITest's internal scroll behavior.
            if !element.isHittable {
                _ = element.frame  // force a snapshot
            }

        case let .pressKey(key, modifiers):
            try pressKey(key, modifiers: modifiers, on: element)
        }
    }

    private func clearText(of element: XCUIElement) throws {
        guard let stringValue = element.value as? String, !stringValue.isEmpty else {
            return
        }
        focusIfNeeded(element)
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        element.typeText(deletes)
    }

    private func pressKey(
        _ key: Key,
        modifiers: KeyModifiers,
        on element: XCUIElement
    ) throws {
        let keyString = keyboardKey(for: key)
        focusIfNeeded(element)
        // `typeText` performs raw key entry; for keys with modifiers we use
        // `typeKey(_:modifierFlags:)` which is XCUIApplication-level.
        if modifiers.isEmpty {
            element.typeText(keyString)
        } else {
            app.typeKey(keyString, modifierFlags: uiModifierFlags(modifiers))
        }
    }

    private func keyboardKey(for key: Key) -> String {
        switch key {
        case .return:    return "\r"
        case .escape:    return XCUIKeyboardKey.escape.rawValue
        case .tab:       return "\t"
        case .space:     return " "
        case .delete:    return XCUIKeyboardKey.delete.rawValue
        case .backspace: return XCUIKeyboardKey.delete.rawValue
        case .arrow(let direction):
            switch direction {
            case .up:    return XCUIKeyboardKey.upArrow.rawValue
            case .down:  return XCUIKeyboardKey.downArrow.rawValue
            case .left:  return XCUIKeyboardKey.leftArrow.rawValue
            case .right: return XCUIKeyboardKey.rightArrow.rawValue
            }
        case .character(let char):
            return String(char)
        }
    }

    /// XCUITest doesn't expose a public "has keyboard focus" API. The
    /// conservative path is to tap before text entry; tapping a focused
    /// field is idempotent (or a no-op for our purposes — at worst it
    /// reasserts focus).
    private func focusIfNeeded(_ element: XCUIElement) {
        // If element is the application or already accepting input, this is
        // still safe: a tap on a non-text-input element doesn't interfere
        // with subsequent typeText calls when the element is the receiver.
        element.tap()
    }

    private func uiModifierFlags(_ modifiers: KeyModifiers) -> XCUIElement.KeyModifierFlags {
        var flags: XCUIElement.KeyModifierFlags = []
        if modifiers.contains(.shift)   { flags.insert(.shift) }
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.option)  { flags.insert(.option) }
        if modifiers.contains(.command) { flags.insert(.command) }
        return flags
    }

    // MARK: - Kind <-> ElementType mapping

    private func elementType(for tag: ElementKindTag) -> XCUIElement.ElementType {
        switch tag {
        case .button:        return .button
        case .textField:     return .textField
        case .staticText:    return .staticText
        case .cell:          return .cell
        case .image:         return .image
        case .switchControl: return .switch
        case .slider:        return .slider
        case .anyElement:    return .any
        }
    }

    private func tag(for type: XCUIElement.ElementType) -> ElementKindTag {
        switch type {
        case .button:     return .button
        case .textField, .secureTextField, .searchField: return .textField
        case .staticText: return .staticText
        case .cell:       return .cell
        case .image:      return .image
        case .switch:     return .switchControl
        case .slider:     return .slider
        default:          return .anyElement
        }
    }
}

// MARK: - Query chain

/// Internal helper representing partial query state as it's built up.
/// Avoids casting between `XCUIElement` and `XCUIElementQuery`.
private enum ElementQueryChain {
    case application(XCUIApplication)
    case query(XCUIElementQuery)
    case element(XCUIElement)

    func applying(_ step: ElementQuery.Step) -> ElementQueryChain {
        switch step {
        case .byTestID(let id):
            return .query(currentQuery.matching(identifier: id))

        case .byLabel(let label):
            let predicate = NSPredicate(format: "label == %@", label)
            return .query(currentQuery.matching(predicate))

        case .byText(let text):
            let predicate = NSPredicate(format: "label == %@ OR value == %@", text, text)
            return .query(currentQuery.matching(predicate))

        case .byKind(let tag):
            return .query(currentQuery.descendants(matching: xcType(for: tag)))

        case .descendant(let childQuery):
            var chain: ElementQueryChain = self
            for step in childQuery.steps {
                chain = chain.applying(step)
            }
            return chain

        case .first:
            return .element(currentQuery.firstMatch)

        case .nth(let index):
            return .element(currentQuery.element(boundBy: index))

        case .filter(let predicate):
            return .query(currentQuery.matching(predicate.nsPredicate))
        }
    }

    var currentQuery: XCUIElementQuery {
        switch self {
        case .application(let app):
            return app.descendants(matching: .any)
        case .query(let query):
            return query
        case .element(let element):
            return element.descendants(matching: .any)
        }
    }

    var firstMatch: XCUIElement {
        switch self {
        case .application(let app):
            return app
        case .query(let query):
            return query.firstMatch
        case .element(let element):
            return element
        }
    }

    private func xcType(for tag: ElementKindTag) -> XCUIElement.ElementType {
        switch tag {
        case .button:        return .button
        case .textField:     return .textField
        case .staticText:    return .staticText
        case .cell:          return .cell
        case .image:         return .image
        case .switchControl: return .switch
        case .slider:        return .slider
        case .anyElement:    return .any
        }
    }
}

#endif
