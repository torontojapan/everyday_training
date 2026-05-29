import SwiftUI

enum Motion {
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let gentle = Animation.easeInOut(duration: 0.4)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)

    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    static func offset(_ value: CGFloat, reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 0 : value
    }

    static func scale(_ value: CGFloat, reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 1 : value
    }

    static func rotation(_ value: Double, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : value
    }
}
