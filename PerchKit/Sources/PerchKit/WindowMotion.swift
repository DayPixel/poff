import CoreGraphics
import Foundation

/// Follows window positions over time to get each window's velocity and to notice when a window is being shaken.
public struct WindowMotionTracker {
    public struct Result {
        public var velocities: [Int: CGVector] = [:]
        public var shaken: Set<Int> = []
    }

    /// A direction change faster than this counts as one reversal (pt/s).
    public static let reversalSpeed: CGFloat = 250
    public static let shakeWindow: TimeInterval = 1.0
    /// Three fast reversals within `shakeWindow` is a shake.
    public static let shakeReversals = 3

    private struct Track {
        var origin: CGPoint
        var time: TimeInterval
        var velocity: CGVector = .zero
        var direction: (x: Int, y: Int) = (0, 0)
        var reversals: [TimeInterval] = []
    }

    private var tracks: [Int: Track] = [:]

    public init() {}

    public mutating func update(_ windows: [TrackedWindow], at time: TimeInterval) -> Result {
        var result = Result()
        var next: [Int: Track] = [:]
        for window in windows {
            let origin = window.frame.origin
            guard var track = tracks[window.id], time > track.time else {
                next[window.id] = tracks[window.id] ?? Track(origin: origin, time: time)
                continue
            }
            let dt = CGFloat(time - track.time)
            track.velocity = CGVector(dx: (origin.x - track.origin.x) / dt, dy: (origin.y - track.origin.y) / dt)
            track.direction.x = countReversal(track.velocity.dx, last: track.direction.x, at: time, into: &track.reversals)
            track.direction.y = countReversal(track.velocity.dy, last: track.direction.y, at: time, into: &track.reversals)
            track.reversals.removeAll { time - $0 > Self.shakeWindow }
            if track.reversals.count >= Self.shakeReversals {
                result.shaken.insert(window.id)
                track.reversals.removeAll()
            }
            track.origin = origin
            track.time = time
            result.velocities[window.id] = track.velocity
            next[window.id] = track
        }
        tracks = next
        return result
    }

    private func countReversal(_ speed: CGFloat, last: Int, at time: TimeInterval, into reversals: inout [TimeInterval]) -> Int {
        let direction = speed > Self.reversalSpeed ? 1 : (speed < -Self.reversalSpeed ? -1 : 0)
        guard direction != 0 else { return last }
        if last != 0 && direction != last { reversals.append(time) }
        return direction
    }
}

/// Is a dragged object being shaken? Uses the same rule as window shaking (3 fast reversals within 1 second).
public struct DragShakeDetector {
    private var tracker = WindowMotionTracker()

    public init() {}

    /// Feed the position every frame. Returns true when it looks like a shake (and again every 3 reversals while it continues).
    public mutating func record(_ position: CGPoint, at time: TimeInterval) -> Bool {
        let probe = TrackedWindow(id: 0, frame: CGRect(origin: position, size: CGSize(width: 1, height: 1)))
        return tracker.update([probe], at: time).shaken.contains(0)
    }
}
