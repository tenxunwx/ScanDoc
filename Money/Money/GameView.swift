import SwiftUI
import UIKit

struct GameView: View {
    let mode: GameMode
    let onExit: () -> Void

    @State private var bills: [Bill] = []
    @State private var total = 0
    @State private var count = 0

    @State private var accumulated: CGFloat = 0
    @State private var lastTranslation: CGFloat = 0

    @State private var startedAt = Date()
    @State private var endDate: Date?
    @State private var isRunning = false
    @State private var finished = false
    @State private var isNewRecord = false
    @State private var sessionID = UUID()

    @State private var hintBobbing = false
    @State private var hapticTick = 0

    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let spawnThreshold: CGFloat = 30

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date
                ZStack {
                    background

                    billsLayer(now: now, size: geo.size)

                    hud(now: now)

                    if finished {
                        ResultOverlay(mode: mode,
                                      total: total,
                                      count: count,
                                      isNewRecord: isNewRecord,
                                      onRetry: { start() },
                                      onExit: onExit)
                            .transition(.opacity)
                    }
                }
                .contentShape(Rectangle())
                .gesture(swipeGesture)
                .simultaneousGesture(TapGesture().onEnded { pushBill() })
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onAppear {
            start()
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                hintBobbing = true
            }
        }
        .onChange(of: finished) { done in
            guard done else { return }
            commitRecord()
        }
    }

    // MARK: - 图层

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.19, blue: 0.14),
                Color(red: 0.02, green: 0.07, blue: 0.055)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            RadialGradient(colors: [Color.white.opacity(0.07), Color.clear],
                           center: .top,
                           startRadius: 0,
                           endRadius: 420)
        )
    }

    private func billsLayer(now: Date, size: CGSize) -> some View {
        ZStack {
            ForEach(bills) { bill in
                BillCard(denom: bill.denom)
                    .rotationEffect(.degrees(bill.startRotation + bill.spin * bill.age(at: now)))
                    .scaleEffect(bill.scale(at: now))
                    .opacity(bill.opacity(at: now))
                    .position(bill.position(at: now, in: size))
            }
        }
        .allowsHitTesting(false)
    }

    private func hud(now: Date) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                timePill(now: now)
                countPill
                Spacer()
                Button(action: onExit) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 54)

            totalDisplay
                .padding(.top, 22)

            Spacer()

            hint
                .padding(.bottom, 40)
        }
    }

    private func timePill(now: Date) -> some View {
        HStack(spacing: 5) {
            Image(systemName: mode == .endless ? "infinity" : "timer")
                .font(.system(size: 11, weight: .medium))
            Text(timeText(now: now))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.1), in: Capsule())
    }

    private var countPill: some View {
        Text("\(count) 张")
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.1), in: Capsule())
    }

    private var totalDisplay: some View {
        VStack(spacing: 3) {
            Text("¥" + formatted(total))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
    }

    private var hint: some View {
        VStack(spacing: 7) {
            Image(systemName: "chevron.up")
                .font(.system(size: 20, weight: .semibold))
                .offset(y: hintBobbing ? -7 : 0)
            Text(count == 0 ? "向上滑动开始数钱" : "继续往上滑")
                .font(.footnote)
        }
        .foregroundStyle(.white.opacity(0.34))
        .opacity(isRunning ? 1 : 0)
    }

    // MARK: - 手势

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isRunning else { return }
                let delta = value.translation.height - lastTranslation
                lastTranslation = value.translation.height
                guard delta < 0 else { return }

                accumulated += -delta
                while accumulated >= spawnThreshold {
                    accumulated -= spawnThreshold
                    pushBill()
                }
            }
            .onEnded { _ in
                lastTranslation = 0
                accumulated = 0
            }
    }

    // MARK: - 逻辑

    private func start() {
        sessionID = UUID()
        let session = sessionID

        bills = []
        total = 0
        count = 0
        accumulated = 0
        lastTranslation = 0
        hapticTick = 0
        isNewRecord = false
        finished = false
        startedAt = Date()
        endDate = mode.seconds.map { Date().addingTimeInterval($0) }
        isRunning = true
        impact.prepare()

        guard let endDate else { return }
        let nanos = UInt64(max(0, endDate.timeIntervalSinceNow) * 1_000_000_000)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: nanos)
            guard sessionID == session else { return }
            isRunning = false
            withAnimation(.easeOut(duration: 0.25)) {
                finished = true
            }
        }
    }

    private func pushBill() {
        guard isRunning else { return }
        let now = Date()

        bills.removeAll { !$0.isAlive(at: now) }
        if bills.count >= 55 {
            bills.removeFirst(bills.count - 54)
        }
        let bill = Bill.make(at: now)
        bills.append(bill)

        total += bill.denom
        count += 1

        hapticTick += 1
        if hapticTick % 3 == 0 {
            impact.impactOccurred(intensity: 0.65)
        }
    }

    private func commitRecord() {
        guard mode != .endless else { return }
        let best = UserDefaults.standard.integer(forKey: mode.bestKey)
        if total > best {
            UserDefaults.standard.set(total, forKey: mode.bestKey)
            isNewRecord = true
        } else {
            isNewRecord = false
        }
    }

    private func timeText(now: Date) -> String {
        if let endDate {
            let remaining = max(0, endDate.timeIntervalSince(now))
            return String(format: "%02d:%02d", Int(remaining) / 60, Int(remaining) % 60)
        }
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        return String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60)
    }

    private func formatted(_ value: Int) -> String {
        Self.formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
