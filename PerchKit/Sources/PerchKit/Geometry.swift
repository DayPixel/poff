import CoreGraphics

// All coordinates are CG global coordinates: origin at the top-left of the main display, y grows downward.
// That's the same space CGWindowListCopyWindowInfo reports window bounds in, so no conversion is needed.

public enum GhostMetrics {
    public static let size = CGSize(width: 40, height: 42.5)
    /// How far the ghost's hem dips into the window when it sits on the top edge.
    public static let perchOverlap: CGFloat = 5
}

/// One window of another app.
public struct TrackedWindow: Equatable, Sendable {
    public let id: Int
    public let frame: CGRect

    public init(id: Int, frame: CGRect) {
        self.id = id
        self.frame = frame
    }
}

public enum Occlusion {
    /// `windows` must be ordered front to back (the order CGWindowList returns).
    public static func isVisible(_ point: CGPoint, ofWindowAt index: Int, in windows: [TrackedWindow]) -> Bool {
        guard windows.indices.contains(index), windows[index].frame.contains(point) else { return false }
        return !windows[..<index].contains { $0.frame.contains(point) }
    }
}

/// Where a ghost sits: a window, and a point along its top edge (0...1).
public struct PerchSpot: Equatable, Sendable {
    public let windowID: Int
    public let fraction: CGFloat

    public init(windowID: Int, fraction: CGFloat) {
        self.windowID = windowID
        self.fraction = fraction
    }
}

public enum PerchFinder {
    public static func ghostOrigin(on window: TrackedWindow, fraction: CGFloat, ghostSize: CGSize) -> CGPoint {
        CGPoint(
            x: window.frame.minX + fraction * window.frame.width - ghostSize.width / 2,
            y: window.frame.minY - ghostSize.height + GhostMetrics.perchOverlap
        )
    }

    /// The edge at that point isn't covered by a window in front, and the seated ghost fits inside one of the screens.
    public static func isUsable(_ spot: PerchSpot, windows: [TrackedWindow], ghostSize: CGSize, regions: [CGRect]) -> Bool {
        guard let index = windows.firstIndex(where: { $0.id == spot.windowID }) else { return false }
        let window = windows[index]
        let edge = CGPoint(x: window.frame.minX + spot.fraction * window.frame.width, y: window.frame.minY + 2)
        guard Occlusion.isVisible(edge, ofWindowAt: index, in: windows) else { return false }
        let ghost = CGRect(origin: ghostOrigin(on: window, fraction: spot.fraction, ghostSize: ghostSize), size: ghostSize)
        return regions.contains { $0.contains(ghost) }
    }

    /// Picks a random visible spot on some window's top edge, keeping a little distance from spots already taken.
    public static func find(
        windows: [TrackedWindow],
        ghostSize: CGSize,
        regions: [CGRect],
        taken: [PerchSpot],
        using rng: inout some RandomNumberGenerator,
        attempts: Int = 24
    ) -> PerchSpot? {
        guard !windows.isEmpty else { return nil }
        for _ in 0..<attempts {
            guard let window = windows.randomElement(using: &rng) else { return nil }
            let spot = PerchSpot(windowID: window.id, fraction: .random(in: 0.12...0.88, using: &rng))
            let crowded = taken.contains {
                $0.windowID == spot.windowID && abs($0.fraction - spot.fraction) * window.frame.width < ghostSize.width * 1.2
            }
            if !crowded && isUsable(spot, windows: windows, ghostSize: ghostSize, regions: regions) {
                return spot
            }
        }
        return nil
    }
}
