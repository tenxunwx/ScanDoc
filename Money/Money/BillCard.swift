import SwiftUI

struct BillCard: View {
    let denom: Int

    private var tint: Color { billTint(denom) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(colors: [tint.opacity(0.92), tint],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                .padding(5)

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: -3) {
                    Text("¥")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Text("\(denom)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.white.opacity(0.95))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
        }
        .frame(width: 134, height: 64)
        .overlay(alignment: .trailing) {
            Text("\(denom)")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.16))
                .padding(.trailing, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 7, x: 0, y: 5)
    }
}
