import SwiftUI
import UIKit

private struct StarDot: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let r: Double
    let o: Double
}

struct FortuneView: View {
    @StateObject private var detector = ShakeDetector()

    @State private var fortune = FortuneEngine.fortune()
    @State private var revealed = false
    @State private var flash = false
    @State private var ringSpin = false
    @State private var pulse = false
    @State private var stars: [StarDot] = []

    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let success = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            background

            if revealed {
                revealedLayer
            } else {
                idleLayer
            }

            Color.white
                .opacity(flash ? 0.42 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear(perform: setup)
        .onDisappear { detector.stop() }
    }

    // MARK: - 背景

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.night, Color(red: 0.07, green: 0.08, blue: 0.115)],
                startPoint: .top,
                endPoint: .bottom
            )

            GeometryReader { geo in
                ForEach(stars) { star in
                    Circle()
                        .fill(Color.white.opacity(star.o))
                        .frame(width: star.r, height: star.r)
                        .position(x: star.x * geo.size.width, y: star.y * geo.size.height)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - 待摇状态

    private var idleLayer: some View {
        VStack(spacing: 0) {
            Spacer()
            orb
            Spacer().frame(height: 44)

            VStack(spacing: 9) {
                Text("摇一摇 · 问今日")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.gold.opacity(0.88))
                    .tracking(1.5)

                Text("或轻点中央")
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.26))
            }

            Spacer()
            Spacer().frame(height: 46)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { draw() }
    }

    private var orb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [Palette.gold.opacity(0.20), Color.clear],
                                   center: .center,
                                   startRadius: 4,
                                   endRadius: 172)
                )
                .frame(width: 344, height: 344)

            Circle()
                .strokeBorder(Palette.gold.opacity(0.16),
                              style: StrokeStyle(lineWidth: 0.8, dash: [1, 7]))
                .frame(width: 296, height: 296)
                .rotationEffect(.degrees(ringSpin ? 360 : 0))
                .animation(.linear(duration: 52).repeatForever(autoreverses: false), value: ringSpin)

            Circle()
                .strokeBorder(
                    LinearGradient(colors: [Palette.gold.opacity(0.55), Palette.gold.opacity(0.06)],
                                   startPoint: .top,
                                   endPoint: .bottom),
                    lineWidth: 1
                )
                .frame(width: 236, height: 236)
                .rotationEffect(.degrees(ringSpin ? -360 : 0))
                .animation(.linear(duration: 24).repeatForever(autoreverses: false), value: ringSpin)

            Circle()
                .strokeBorder(Palette.gold.opacity(0.13), lineWidth: 0.8)
                .frame(width: 182, height: 182)
                .scaleEffect(pulse ? 1.045 : 0.975)
                .animation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true), value: pulse)

            Text("签")
                .font(.system(size: 46, weight: .light, design: .serif))
                .foregroundStyle(Palette.gold.opacity(0.92))
        }
        .frame(width: 344, height: 344)
    }

    // MARK: - 揭晓状态

    private var revealedLayer: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                SignCard(fortune: fortune, date: Date())
                    .padding(.top, 28)

                AdviceCard(fortune: fortune)

                Button(action: redraw) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .medium))
                        Text("再问一次")
                            .font(.system(size: 13, design: .serif))
                    }
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.horizontal, 17)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.055), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                Text("同一天，同一支签")
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.22))
                    .padding(.bottom, 34)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
        }
        .transition(.asymmetric(insertion: .scale(scale: 0.93).combined(with: .opacity),
                                removal: .opacity))
    }

    // MARK: - 逻辑

    private func setup() {
        stars = (0..<64).map { _ in
            StarDot(x: .random(in: 0...1),
                    y: .random(in: 0...1),
                    r: .random(in: 0.8...2.0),
                    o: .random(in: 0.12...0.55))
        }
        ringSpin = true
        pulse = true
        heavy.prepare()
        detector.onShake = { [self] in
            draw()
        }
        detector.start()
    }

    private func draw() {
        fortune = FortuneEngine.fortune()
        heavy.impactOccurred(intensity: 1.0)

        withAnimation(.easeOut(duration: 0.3)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.easeOut(duration: 0.55)) { flash = false }
        }

        withAnimation(.spring(response: 0.62, dampingFraction: 0.76)) {
            revealed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            success.notificationOccurred(.success)
        }
    }

    private func redraw() {
        withAnimation(.easeOut(duration: 0.16)) { revealed = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) { [self] in
            draw()
        }
    }
}
