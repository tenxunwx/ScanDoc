import SwiftUI

struct ResultOverlay: View {
    let mode: GameMode
    let total: Int
    let count: Int
    let isNewRecord: Bool
    let onRetry: () -> Void
    let onExit: () -> Void

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("时间到")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 26)

                Text("¥" + formatted(total))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.top, 6)
                    .padding(.horizontal, 20)

                Text("共 \(count) 张")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 2)

                if isNewRecord {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                        Text("新纪录")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color(red: 0.99, green: 0.79, blue: 0.4))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.99, green: 0.79, blue: 0.4).opacity(0.14), in: Capsule())
                    .padding(.top, 12)
                }

                VStack(spacing: 10) {
                    Button(action: onRetry) {
                        Text("再来一次")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(red: 0.05, green: 0.12, blue: 0.09))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(red: 0.96, green: 0.97, blue: 0.94),
                                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onExit) {
                        Text("换个时长")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 22)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: 320)
            .background(Color(red: 0.075, green: 0.11, blue: 0.095),
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
            )
            .padding(.horizontal, 32)
        }
    }

    private func formatted(_ value: Int) -> String {
        Self.formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
