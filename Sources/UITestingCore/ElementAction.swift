import Foundation

/// The 10 actions a `Driver` can perform on a resolved element.
///
/// Adding a new case is an API-breaking change for `Driver` implementations,
/// so the set is intentionally minimal for v0.1.
public enum ElementAction: Sendable, Equatable {
    case tap
    case doubleTap
    case longPress(duration: Duration)
    case typeText(String)
    case clearText
    case swipe(SwipeDirection)
    case setSwitch(on: Bool)
    case setSliderValue(Double)
    case scrollToVisible
    case pressKey(Key, modifiers: KeyModifiers)
}

public enum SwipeDirection: Sendable, Hashable {
    case up, down, left, right
}

public struct KeyModifiers: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let shift = KeyModifiers(rawValue: 1 << 0)
    public static let control = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)
}

public enum Key: Sendable, Hashable {
    case `return`
    case escape
    case tab
    case space
    case delete
    case backspace
    case arrow(ArrowDirection)
    case character(Character)

    public enum ArrowDirection: Sendable, Hashable {
        case up, down, left, right
    }
}
