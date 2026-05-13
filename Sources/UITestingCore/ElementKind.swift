import Foundation

/// Phantom-type marker for a kind of UI element a `Locator` can address.
///
/// Conform a custom type to `ElementKind` plus relevant capability protocols
/// (e.g. `TappableKind`, `TypingKind`) to integrate custom element types into
/// the typed locator API.
public protocol ElementKind: Sendable {
    /// Identifies the kind to the `Driver` so it can map back to the
    /// platform-native query API (e.g. `XCUIElement.ElementType`).
    static var tag: ElementKindTag { get }
}

/// Identifies an element kind to `Driver` implementations.
///
/// Driver implementations translate these tags into their native element-type
/// representation. `anyElement` is the escape hatch and matches every element
/// regardless of its underlying type.
public enum ElementKindTag: Sendable, Hashable {
    case button
    case textField
    case staticText
    case cell
    case image
    case switchControl
    case slider
    case anyElement
}

// MARK: - Standard kinds

public enum Button: ElementKind {
    public static let tag: ElementKindTag = .button
}

public enum TextField: ElementKind {
    public static let tag: ElementKindTag = .textField
}

public enum StaticText: ElementKind {
    public static let tag: ElementKindTag = .staticText
}

public enum Cell: ElementKind {
    public static let tag: ElementKindTag = .cell
}

public enum Image: ElementKind {
    public static let tag: ElementKindTag = .image
}

public enum Switch: ElementKind {
    public static let tag: ElementKindTag = .switchControl
}

public enum Slider: ElementKind {
    public static let tag: ElementKindTag = .slider
}

/// Type-erased escape hatch. `AnyElement` conforms to every capability
/// protocol so it can perform any action; use it when the typed kinds don't
/// cover your case (custom controls, dynamic queries via `NSPredicate`, etc).
public enum AnyElement: ElementKind {
    public static let tag: ElementKindTag = .anyElement
}

// MARK: - Capability protocols
//
// Stdlib idiom: a small hierarchy describing *what an element can do*, used
// to gate action availability at compile time. A `Locator<Kind>` exposes an
// action only when `Kind` conforms to the corresponding capability protocol.

public protocol TappableKind: ElementKind {}
public protocol TypingKind: ElementKind {}
public protocol ToggleableKind: ElementKind {}
public protocol SwipeableKind: ElementKind {}
public protocol ScrollableKind: ElementKind {}
public protocol AdjustableKind: ElementKind {}
public protocol KeyInputKind: ElementKind {}

// MARK: - Capability assignments

extension Button: TappableKind, SwipeableKind, ScrollableKind {}
extension TextField: TappableKind, TypingKind, KeyInputKind, ScrollableKind {}
extension StaticText: SwipeableKind, ScrollableKind {}
extension Cell: TappableKind, SwipeableKind, ScrollableKind {}
extension Image: TappableKind, SwipeableKind, ScrollableKind {}
extension Switch: TappableKind, ToggleableKind, ScrollableKind {}
extension Slider: AdjustableKind, ScrollableKind {}

extension AnyElement: TappableKind, TypingKind, ToggleableKind,
                      SwipeableKind, ScrollableKind, AdjustableKind, KeyInputKind {}
