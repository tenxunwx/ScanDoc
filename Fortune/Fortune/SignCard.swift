import SwiftUI

enum Palette {
    static let gold = Color(red: 0.85, green: 0.72, blue: 0.44)
    static let goldDeep = Color(red: 0.60, green: 0.45, blue: 0.19)
    static let ink = Color(red: 0.16, green: 0.14, blue: 0.12)
    static let inkSoft = Color(red: 0.44, green: 0.40, blue: 0.35)
    static let paper = Color(red: 0.965, green: 0.945, blue: 0.885)
    static let paperDeep = Color(red: 0.905, green: 0.875, blue: 0.795)
    static let seal = Color(red: 0.69, green: 0.22, blue: 0.18)
    static let night = Color(red: 0.035, green: 0.045, blue: 0.07)
}

struct SignCard: View {
    let fortune: Fortune
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer().frame(height: 20)

            HStack(alignment: .top, spacing: 10) {
                tierBlock
                Spacer(minLength: 4)
                poemBlock
            }

            Spacer().frame(height: 18)

            Rectangle()
                .fill(Palette.goldDeep.opacity(0.32))
                .frame(height: 0.8)

            Spacer().frame(height: 13)

            luckyRow
        }
        .padding(22)
        .frame(maxWidth: 360)
        .background(
            LinearGradient(colors: [Palette.paper, Palette.paperDeep],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Palette.goldDeep.opacity(0.45), lineWidth: 0.8)
                .padding(6)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 26, x: 0, y: 14)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(LunarFormatter.dateText(for: date))
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Palette.ink)
                    Text(LunarFormatter.weekdayText(for: date))
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(Palette.inkSoft)
                }
                Text(LunarFormatter.text(for: date))
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            seal
        }
    }

    private var seal: some View {
        Text("今日")
            .font(.system(size: 13, weight: .semibold, design: .serif))
            .foregroundStyle(Color.white.opacity(0.94))
            .frame(width: 44, height: 44)
            .background(Palette.seal)
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    .padding(3.5)
            )
            .rotationEffect(.degrees(-5))
    }

    // MARK: - 签等

    private var tierBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(fortune.tier.rawValue)
                .font(.system(size: 50, weight: .medium, design: .serif))
                .foregroundStyle(Palette.ink)
                .fixedSize()

            HStack(spacing: 3.5) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < fortune.tier.stars ? Palette.goldDeep : Palette.inkSoft.opacity(0.22))
                        .frame(width: 5, height: 5)
                }
            }

            Text(fortune.tier.note)
                .font(.system(size: 11, design: .serif))
                .foregroundStyle(Palette.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 116, alignment: .leading)
        }
    }

    // MARK: - 竖排签文

    private var poemBlock: some View {
        HStack(alignment: .top, spacing: 11) {
            ForEach(Array(fortune.poemLines.reversed().enumerated()), id: \.offset) { _, line in
                VStack(spacing: 5) {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, character in
                        Text(String(character))
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .foregroundStyle(Palette.ink)
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    // MARK: - 幸运色 / 数字

    private var luckyRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(red: fortune.color.red,
                            green: fortune.color.green,
                            blue: fortune.color.blue))
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Palette.ink.opacity(0.18), lineWidth: 0.6))

            VStack(alignment: .leading, spacing: 1) {
                Text("幸运色")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.inkSoft)
                Text(fortune.color.name)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.ink)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("幸运数")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.inkSoft)
                Text("\(fortune.number)")
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.ink)
            }
        }
    }
}

/// 宜 / 忌
struct AdviceCard: View {
    let fortune: Fortune

    var body: some View {
        HStack(alignment: .top, spacing: 26) {
            column(title: "宜", items: fortune.good, tint: Palette.goldDeep)
            Rectangle()
                .fill(Palette.goldDeep.opacity(0.2))
                .frame(width: 0.8)
                .frame(maxHeight: 78)
            column(title: "忌", items: fortune.bad, tint: Palette.inkSoft)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: 360)
        .background(Color.white.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }

    private func column(title: String, items: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .serif))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(Color.white.opacity(0.82))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
