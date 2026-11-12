import Foundation

enum Tier: String, CaseIterable {
    case great = "大吉"
    case upper = "上吉"
    case middle = "中吉"
    case small = "小吉"
    case even = "平"

    var stars: Int {
        switch self {
        case .great: return 5
        case .upper: return 4
        case .middle: return 3
        case .small: return 2
        case .even: return 1
        }
    }

    var note: String {
        switch self {
        case .great: return "万事可行，趁势而为。"
        case .upper: return "顺水行舟，宜进不宜退。"
        case .middle: return "不急不缓，稳中有得。"
        case .small: return "小处着手，莫问远方。"
        case .even: return "守成为要，动静皆宜。"
        }
    }
}

struct LuckyColor {
    let name: String
    let red: Double
    let green: Double
    let blue: Double
}

struct Fortune {
    let tier: Tier
    let poemLines: [String]
    let color: LuckyColor
    let number: Int
    let good: [String]
    let bad: [String]
}

/// 按日期播种的确定性随机：同一天摇多少次，都是同一支签。
enum FortuneEngine {
    private static let colors: [LuckyColor] = [
        LuckyColor(name: "朱砂", red: 0.70, green: 0.23, blue: 0.18),
        LuckyColor(name: "鎏金", red: 0.79, green: 0.64, blue: 0.15),
        LuckyColor(name: "月白", red: 0.93, green: 0.92, blue: 0.88),
        LuckyColor(name: "黛青", red: 0.23, green: 0.29, blue: 0.35),
        LuckyColor(name: "琥珀", red: 0.78, green: 0.57, blue: 0.18),
        LuckyColor(name: "竹青", red: 0.43, green: 0.55, blue: 0.45),
        LuckyColor(name: "藕荷", red: 0.75, green: 0.66, blue: 0.75),
        LuckyColor(name: "湖蓝", red: 0.24, green: 0.49, blue: 0.56),
        LuckyColor(name: "玄色", red: 0.16, green: 0.16, blue: 0.18),
        LuckyColor(name: "杏黄", red: 0.91, green: 0.76, blue: 0.48)
    ]

    private static let poems: [[String]] = [
        ["风过竹林", "声自清"],
        ["水行深处", "自成渠"],
        ["月满则亏", "留三分"],
        ["静水流深", "不争先"],
        ["云开见山", "路自明"],
        ["一叶知秋", "宜早谋"],
        ["执炬夜行", "莫问远"],
        ["松间明月", "照归途"],
        ["临渊不羡", "退而结网"],
        ["风起于萍", "末可期"],
        ["心远地偏", "车马自稀"],
        ["积羽沉舟", "群轻折轴"],
        ["守拙抱朴", "不与人争"],
        ["潮落石出", "方见真章"],
        ["半山听雨", "半山行"],
        ["不系之舟", "随波自适"]
    ]

    private static let goodPool = ["出行", "会友", "签约", "搬迁", "静思", "读书", "远行",
                                   "断舍离", "早睡", "求医", "宴饮", "修缮", "馈赠",
                                   "独处", "练习", "整理", "复盘", "散步", "种花"]
    private static let badPool = ["争执", "熬夜", "久坐", "贪凉", "拖延", "轻诺", "多言",
                                  "借贷", "赶工", "夜宵", "逞强", "翻旧账", "空腹饮茶",
                                  "临时改约", "强行劝人"]

    static func fortune(for date: Date = Date()) -> Fortune {
        var rng = SplitMix64(seed: seed(from: date))

        let tier: Tier
        switch rng.int(100) {
        case ..<12: tier = .great
        case ..<35: tier = .upper
        case ..<62: tier = .middle
        case ..<86: tier = .small
        default: tier = .even
        }

        let poem = poems[rng.int(poems.count)]
        let color = colors[rng.int(colors.count)]
        let number = rng.int(9) + 1

        var good: [String] = []
        while good.count < 3 {
            let item = goodPool[rng.int(goodPool.count)]
            if !good.contains(item) { good.append(item) }
        }

        var bad: [String] = []
        while bad.count < 3 {
            let item = badPool[rng.int(badPool.count)]
            if !bad.contains(item) { bad.append(item) }
        }

        return Fortune(tier: tier,
                       poemLines: poem,
                       color: color,
                       number: number,
                       good: good,
                       bad: bad)
    }

    private static func seed(from date: Date) -> UInt64 {
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let year = UInt64(comps.year ?? 2025)
        let month = UInt64(comps.month ?? 1)
        let day = UInt64(comps.day ?? 1)
        return year &* 10000 &+ month &* 100 &+ day
    }
}

struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func int(_ upper: Int) -> Int {
        guard upper > 0 else { return 0 }
        return Int(next() % UInt64(upper))
    }
}

/// 农历与干支，纯本地计算，不联网。
enum LunarFormatter {
    private static let monthNames = ["正", "二", "三", "四", "五", "六",
                                     "七", "八", "九", "十", "冬", "腊"]
    private static let dayNames = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                                   "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                                   "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
    private static let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private static let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

    static func text(for date: Date) -> String {
        var calendar = Calendar(identifier: .chinese)
        calendar.locale = Locale(identifier: "zh_CN")
        let comps = calendar.dateComponents([.year, .month, .day], from: date)

        let month = comps.month ?? 1
        let day = comps.day ?? 1

        let monthText = (month >= 1 && month <= monthNames.count) ? monthNames[month - 1] + "月" : ""
        let dayText = (day >= 1 && day <= dayNames.count) ? dayNames[day - 1] : ""
        let cycle = comps.year ?? 1
        let stem = stems[(cycle - 1) % 10]
        let branch = branches[(cycle - 1) % 12]

        return "\(stem)\(branch)年 \(monthText)\(dayText)"
    }

    static func weekdayText(for date: Date) -> String {
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: date)
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        guard weekday >= 1, weekday <= 7 else { return "" }
        return names[weekday - 1]
    }

    static func dateText(for date: Date) -> String {
        let comps = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: date)
        return "\(comps.month ?? 1) 月 \(comps.day ?? 1) 日"
    }
}
