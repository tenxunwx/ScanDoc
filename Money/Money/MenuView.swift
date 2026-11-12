import SwiftUI

struct MenuView: View {
    @State private var activeMode: GameMode?

    @AppStorage("best.short") private var bestShort = 0
    @AppStorage("best.long") private var bestLong = 0
    @AppStorage("best.endless") private var bestEndless = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.19, blue: 0.14),
                    Color(red: 0.02, green: 0.07, blue: 0.055)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("数钱")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("选个时长，向上滑动，越快越多")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                HStack(spacing: 12) {
                    ForEach(GameMode.allCases) { mode in
                        modeCard(mode)
                    }
                }
                .padding(.top, 44)
                .frame(maxWidth: 560)

                Spacer()

                Text("每张钞票面额随机，30 秒与 60 秒分别记录最好成绩")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 36)
            }
            .padding(.horizontal, 20)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $activeMode) { mode in
            GameView(mode: mode, onExit: { activeMode = nil })
        }
    }

    private func modeCard(_ mode: GameMode) -> some View {
        Button {
            activeMode = mode
        } label: {
            VStack(spacing: 9) {
                Text(mode.title)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(mode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.5)
                    .padding(.vertical, 4)

                Text(bestText(for: mode))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func bestText(for mode: GameMode) -> String {
        let best: Int
        switch mode {
        case .short: best = bestShort
        case .long: best = bestLong
        case .endless: best = bestEndless
        }
        guard best > 0 else { return "还没数过" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let text = formatter.string(from: NSNumber(value: best)) ?? "\(best)"
        return "最佳 ¥" + text
    }
}
