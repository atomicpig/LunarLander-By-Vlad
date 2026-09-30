import Foundation

/// Arcade response: a command takes effect on the next fixed physics step.
/// Granularity belongs to the dial mapping, never to a delayed motor spool-up.
public struct EngineResponse {
    public private(set) var output = FlightInput()
    public init() {}
    public mutating func reset() { output = FlightInput() }
    public mutating func advance(toward command: FlightInput, dt: Double) -> FlightInput {
        output = command
        output.thrust = clamp(command.thrust,0,1)
        output.reverse = clamp(command.reverse,0,1)
        output.lateralLeft = clamp(command.lateralLeft,0,1)
        output.lateralRight = clamp(command.lateralRight,0,1)
        output.rotationLeft = clamp(command.rotationLeft,0,1)
        output.rotationRight = clamp(command.rotationRight,0,1)
        return output
    }
}
