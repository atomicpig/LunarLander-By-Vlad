import Foundation

/// Small changes act on the next physics step. Large increases spool up over at
/// most 0.4 s; reductions and emergency cuts take effect immediately.
public struct EngineResponse {
    public private(set) var output = FlightInput()
    public init() {}
    public mutating func reset() { output = FlightInput() }
    public mutating func advance(toward command: FlightInput, dt: Double) -> FlightInput {
        let previous = output
        output = command
        func rise(_ old: Double, _ target: Double) -> Double {
            min(clamp(target, 0, 1), old + max(0, dt) * 2.5)
        }
        output.thrust = rise(previous.thrust, command.thrust)
        output.reverse = rise(previous.reverse, command.reverse)
        output.lateralLeft = rise(previous.lateralLeft, command.lateralLeft)
        output.lateralRight = rise(previous.lateralRight, command.lateralRight)
        output.rotationLeft = rise(previous.rotationLeft, command.rotationLeft)
        output.rotationRight = rise(previous.rotationRight, command.rotationRight)
        return output
    }
}
