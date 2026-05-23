import SwiftUI

enum Motion {
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let gentle = Animation.easeInOut(duration: 0.4)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
}
