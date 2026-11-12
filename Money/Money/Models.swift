import Foundation
import SwiftUI

enum GameMode: String, CaseIterable, Identifiable {
    case short      // 30 秒
    case long       // 60 秒
    case endless    // 不限时

    var id: String { rawValue }

    var title: String {
        switch self {
        case .short: return "30 秒"
        case .long: return "60 秒"
        case .endless: return "不限时"
        }
    }

    var subtitle: String {
        switch self {
        case .short: return "一口气冲"
        case .long: return "稳中求快"
        case .endless: return "没有终点"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .short: return 30
        case .long: return 60
        case .endless: return nil
        }
    }

    var bestKey: String {
        "best." + rawValue
    }
}

/// 一张飞起来的钞票。位置由出生时间解析计算，不累积误差。
struct Bill: Identifiable {
    let id = UUID()
    let denom: Int
    let originX: CGFloat      // 0…1，相对屏幕宽度
    let born: Date
    let riseSpeed: CGFloat    // 点/秒
    let driftSpeed: CGFloat   // 左右漂移，点/秒
    let startRotation: Double
    let spin: Double          // 度/秒
    let startScale: CGFloat

    static let life: TimeInterval = 1.7

    static func make(at date: Date) -> Bill {
        let denom = pickDenomination()
        return Bill(denom: denom,
                    originX: CGFloat.random(in: 0.12...0.88),
                    born: date,
                    riseSpeed: CGFloat.random(in: 980...1320),
                    driftSpeed: CGFloat.random(in: -70...70),
                    startRotation: Double.random(in: -18...18),
                    spin: Double.random(in: -140...140),
                    startScale: CGFloat.random(in: 0.82...1.0))
    }

    private static func pickDenomination() -> Int {
        let roll = Double.random(in: 0...1)
        switch roll {
        case ..<0.42: return 100
        case ..<0.66: return 50
        case ..<0.84: return 20
        case ..<0.94: return 10
        default: return 5
        }
    }

    func age(at now: Date) -> TimeInterval {
        now.timeIntervalSince(born)
    }

    func isAlive(at now: Date) -> Bool {
        age(at: now) < Bill.life
    }

    func opacity(at now: Date) -> Double {
        let t = age(at: now)
        guard t > Bill.life - 0.45 else { return 1 }
        return max(0, (Bill.life - t) / 0.45)
    }

    func scale(at now: Date) -> CGFloat {
        let progress = min(age(at: now) / Bill.life, 1)
        return startScale * (1 - 0.18 * CGFloat(progress))
    }

    func position(at now: Date, in size: CGSize) -> CGPoint {
        let t = CGFloat(age(at: now))
        return CGPoint(x: originX * size.width + driftSpeed * t,
                       y: size.height + 90 - riseSpeed * t)
    }
}

func billTint(_ denom: Int) -> Color {
    switch denom {
    case 100: return Color(red: 0.78, green: 0.24, blue: 0.32)
    case 50: return Color(red: 0.16, green: 0.52, blue: 0.42)
    case 20: return Color(red: 0.66, green: 0.44, blue: 0.20)
    case 10: return Color(red: 0.20, green: 0.42, blue: 0.62)
    default: return Color(red: 0.44, green: 0.32, blue: 0.62)
    }
}
