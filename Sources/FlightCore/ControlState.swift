import Foundation

/// Sources are independent: releasing a key must not cancel an AKAI control still held.
public struct ControlState {
    private var held: [String: [ControlAction: Double]] = [:]
    public init() {}
    public var activeActions: Set<ControlAction> {
        Set(held.values.flatMap { $0.filter { $0.value > 0 }.map(\.key) })
    }
    public func value(_ action: ControlAction) -> Double { held.values.compactMap { $0[action] }.max() ?? 0 }
    public mutating func set(_ action: ControlAction, value: Double, source: String) {
        held[source, default: [:]][action] = value > 0 ? clamp(value, 0, 1) : nil
        if held[source]?.isEmpty == true { held[source] = nil }
    }
    public mutating func clear() { held.removeAll() }
}
