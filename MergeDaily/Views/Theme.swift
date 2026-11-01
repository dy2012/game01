import SwiftUI

/// 经典 2048 配色
enum Theme {
    static let background = Color(red: 0.980, green: 0.973, blue: 0.937)  // #FAF8EF
    static let board = Color(red: 0.733, green: 0.678, blue: 0.627)      // #BBADA0
    static let cellEmpty = Color(red: 0.804, green: 0.757, blue: 0.706)  // #CDC1B4
    static let text = Color(red: 0.467, green: 0.431, blue: 0.396)       // #776E65
    static let accentOrange = Color(red: 0.929, green: 0.486, blue: 0.361) // #ED7762-ish
    static let tileGold = Color(red: 0.929, green: 0.761, blue: 0.180)   // #EDC22E

    static func tileColor(_ value: Int) -> Color {
        switch value {
        case 2: Color(red: 0.933, green: 0.894, blue: 0.855)
        case 4: Color(red: 0.929, green: 0.878, blue: 0.784)
        case 8: Color(red: 0.949, green: 0.722, blue: 0.471)
        case 16: Color(red: 0.961, green: 0.584, blue: 0.388)
        case 32: Color(red: 0.965, green: 0.486, blue: 0.373)
        case 64: Color(red: 0.965, green: 0.369, blue: 0.231)
        case 128: Color(red: 0.929, green: 0.812, blue: 0.447)
        case 256: Color(red: 0.929, green: 0.800, blue: 0.380)
        case 512: Color(red: 0.929, green: 0.784, blue: 0.314)
        case 1024: Color(red: 0.929, green: 0.773, blue: 0.247)
        case 2048: Color(red: 0.929, green: 0.761, blue: 0.180)
        default: Color(red: 0.239, green: 0.231, blue: 0.220)
        }
    }

    static func tileTextColor(_ value: Int) -> Color {
        value <= 4 ? text : .white
    }

    /// 战绩卡的方格 emoji（按方块量级分档）
    static func emoji(forTile value: Int) -> String {
        switch value {
        case 0: "⬜"
        case 2, 4: "🟫"
        case 8, 16: "🟪"
        case 32, 64: "🟦"
        case 128, 256: "🟩"
        case 512, 1024: "🟨"
        default: "🟥"
        }
    }
}
