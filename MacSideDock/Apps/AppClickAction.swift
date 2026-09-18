import Foundation

nonisolated enum AppClickAction: Equatable, Sendable {
    case launch
    case activate
    case hide

    static func resolve(isRunning: Bool, isActive: Bool) -> AppClickAction {
        if !isRunning {
            return .launch
        }
        if isActive {
            return .hide
        }
        return .activate
    }
}
