import Foundation
import CoreMotion
import Combine

/// 摇一摇检测。静止时加速度约 1G，用力甩会冲到 2G 以上。
final class ShakeDetector: ObservableObject {
    private let manager = CMMotionManager()
    private var lastTrigger = Date.distantPast

    var onShake: (() -> Void)?

    func start() {
        guard manager.isAccelerometerAvailable, !manager.isAccelerometerActive else { return }
        manager.accelerometerUpdateInterval = 1.0 / 50.0
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let a = data.acceleration
            let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            guard magnitude > 2.3 else { return }

            let now = Date()
            guard now.timeIntervalSince(self.lastTrigger) > 1.1 else { return }
            self.lastTrigger = now
            self.onShake?()
        }
    }

    func stop() {
        manager.stopAccelerometerUpdates()
    }

    deinit {
        manager.stopAccelerometerUpdates()
    }
}
