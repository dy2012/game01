import Foundation

/// SplitMix64：小而快的确定性伪随机生成器，同 seed 序列在所有平台一致
struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// 以 UTC 日为单位的“全球同题”时钟，第 0 天 = 2026-01-01
enum DailyClock {
    static let epochDay = 20454  // 2026-01-01 距 1970-01-01 的天数
    static let secondsPerDay: Double = 86_400

    static func dayNumber(at date: Date = Date()) -> Int {
        Int(floor(date.timeIntervalSince1970 / secondsPerDay)) - epochDay
    }

    /// 下一个谜题的刷新时刻（下一个 UTC 零点）
    static func nextPuzzleDate(after date: Date = Date()) -> Date {
        let nextDay = Double(dayNumber(at: date) + epochDay + 1) * secondsPerDay
        return Date(timeIntervalSince1970: nextDay)
    }
}

/// 每日谜题：seed 决定全局所有玩家的初始盘面与新方块序列
struct DailyPuzzle: Sendable {
    let seed: UInt64

    /// 每日挑战：按天号派生 seed，全球同题
    init(dayNumber: Int) {
        seed = UInt64(bitPattern: Int64(dayNumber)) &* 0x9E3779B97F4A7C15 &+ 0x2545F4914F6CDD1D
    }

    /// 自由练习：随机 seed
    init() {
        var rng = SystemRandomNumberGenerator()
        seed = rng.next()
    }

    /// 第 index 个新方块。只依赖 (seed, index)，与走法无关，因此重放确定
    func spawn(at index: Int) -> Spawn {
        var rng = SeededGenerator(seed: seed &+ UInt64(bitPattern: Int64(index)) &* 0xD1B54A32D192ED03)
        let value = rng.next() % 10 == 0 ? 4 : 2
        let slot = Int(rng.next() % 16)
        return Spawn(value: value, slot: slot)
    }

    func makeInitialBoard() -> GameBoard {
        var board = GameBoard()
        board.placeInitialSpawns(spawn(at: 0), spawn(at: 1))
        return board
    }
}
