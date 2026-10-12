import CoreGraphics
import XCTest
@testable import PerchKit

final class OcclusionTests: XCTestCase {
    // Front window A covers the top-left of back window B.
    let front = TrackedWindow(id: 1, frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    let back = TrackedWindow(id: 2, frame: CGRect(x: 100, y: 100, width: 300, height: 300))

    func testPointCoveredByFrontWindowIsHidden() {
        XCTAssertFalse(Occlusion.isVisible(CGPoint(x: 150, y: 150), ofWindowAt: 1, in: [front, back]))
    }

    func testUncoveredPointIsVisible() {
        XCTAssertTrue(Occlusion.isVisible(CGPoint(x: 350, y: 350), ofWindowAt: 1, in: [front, back]))
    }

    func testPointOutsideWindowIsNotVisible() {
        XCTAssertFalse(Occlusion.isVisible(CGPoint(x: 500, y: 500), ofWindowAt: 1, in: [front, back]))
    }
}

final class PerchFinderTests: XCTestCase {
    let screen = CGRect(x: 0, y: 25, width: 1440, height: 800)
    let size = GhostMetrics.size

    func testEdgeHiddenBehindFrontWindowIsNotUsable() {
        let front = TrackedWindow(id: 1, frame: CGRect(x: 0, y: 100, width: 1000, height: 300))
        let back = TrackedWindow(id: 2, frame: CGRect(x: 100, y: 200, width: 400, height: 400))
        let spot = PerchSpot(windowID: 2, fraction: 0.5)
        XCTAssertFalse(PerchFinder.isUsable(spot, windows: [front, back], ghostSize: size, regions: [screen]))
    }

    func testWindowTouchingMenuBarHasNoRoomToSit() {
        let maximized = TrackedWindow(id: 1, frame: CGRect(x: 0, y: 25, width: 1440, height: 800))
        let spot = PerchSpot(windowID: 1, fraction: 0.5)
        XCTAssertFalse(PerchFinder.isUsable(spot, windows: [maximized], ghostSize: size, regions: [screen]))
    }

    func testWindowOnSecondMonitorIsUsable() {
        let second = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let window = TrackedWindow(id: 1, frame: CGRect(x: 1600, y: 300, width: 500, height: 400))
        let spot = PerchSpot(windowID: 1, fraction: 0.5)
        XCTAssertFalse(PerchFinder.isUsable(spot, windows: [window], ghostSize: size, regions: [screen]))
        XCTAssertTrue(PerchFinder.isUsable(spot, windows: [window], ghostSize: size, regions: [screen, second]))
    }

    func testFindOnlyPicksVisibleEdges() {
        let front = TrackedWindow(id: 1, frame: CGRect(x: 0, y: 25, width: 1000, height: 300))
        let hidden = TrackedWindow(id: 2, frame: CGRect(x: 100, y: 120, width: 400, height: 400))
        let open = TrackedWindow(id: 3, frame: CGRect(x: 1050, y: 300, width: 350, height: 300))
        for seed in 0..<50 {
            var rng = SplitMix64(seed: UInt64(seed))
            let spot = PerchFinder.find(windows: [front, hidden, open], ghostSize: size, regions: [screen], taken: [], using: &rng)
            XCTAssertEqual(spot?.windowID, 3, "seed \(seed)")
        }
    }

    func testFindAvoidsSittingOnTopOfAnotherGhost() {
        let window = TrackedWindow(id: 1, frame: CGRect(x: 100, y: 300, width: 400, height: 300))
        let taken = [PerchSpot(windowID: 1, fraction: 0.5)]
        for seed in 0..<50 {
            var rng = SplitMix64(seed: UInt64(seed))
            guard let spot = PerchFinder.find(windows: [window], ghostSize: size, regions: [screen], taken: taken, using: &rng) else { continue }
            XCTAssertGreaterThanOrEqual(abs(spot.fraction - 0.5) * 400, size.width * 1.2)
        }
    }
}

final class WindowMotionTests: XCTestCase {
    private func frame(x: CGFloat) -> [TrackedWindow] {
        [TrackedWindow(id: 9, frame: CGRect(x: x, y: 300, width: 500, height: 400))]
    }

    func testShakingBackAndForthIsDetected() {
        var tracker = WindowMotionTracker()
        var shaken = false
        for step in 0..<12 {
            let x: CGFloat = step % 2 == 0 ? 200 : 260
            shaken = shaken || tracker.update(frame(x: x), at: Double(step) / 15).shaken.contains(9)
        }
        XCTAssertTrue(shaken)
    }

    func testSteadyDragIsNotAShake() {
        var tracker = WindowMotionTracker()
        for step in 0..<30 {
            let result = tracker.update(frame(x: 200 + CGFloat(step) * 40), at: Double(step) / 15)
            XCTAssertFalse(result.shaken.contains(9))
            if step > 0 { XCTAssertEqual(result.velocities[9]?.dx ?? 0, 600, accuracy: 0.5) }
        }
    }
}

final class DragShakeTests: XCTestCase {
    func testFastBackAndForthIsAShake() {
        // Swings left and right every 0.16 s at roughly 750 pt/s.
        var shaking = DragShakeDetector()
        var shaken = false
        for frame in 0..<60 {
            let t = Double(frame) / 60
            let x = 400 + 60 * CGFloat(sin(t * 2 * .pi / 0.32))
            if shaking.record(CGPoint(x: x, y: 300), at: t) { shaken = true }
        }
        XCTAssertTrue(shaken)
    }

    func testFastMoveInOneDirectionIsNotAShake() {
        var steady = DragShakeDetector()
        XCTAssertFalse((0..<60).contains { frame in
            steady.record(CGPoint(x: 100 + CGFloat(frame) * 15, y: 300), at: Double(frame) / 60)
        })
    }

    func testGentleWiggleIsNotAShake() {
        var slow = DragShakeDetector()
        XCTAssertFalse((0..<120).contains { frame in
            let t = Double(frame) / 60
            return slow.record(CGPoint(x: 400 + 10 * CGFloat(sin(t * 2 * .pi / 0.32)), y: 300), at: t)
        })
    }
}
