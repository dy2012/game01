import Foundation
import Observation

/// 每日一局的存档快照（断点续玩）
struct DailySnapshot: Codable, Equatable {
    let day: Int
    let board: GameBoard
    let startedAt: Date
}

/// 一天完成的战绩
struct DayResult: Codable, Equatable, Identifiable {
    let day: Int
    let score: Int
    let moves: Int
    let maxTile: Int
    let tiles: [Int]
    let seconds: Int
    let date: Date

    var id: Int { day }
}

/// 战绩与练习最佳分的本地持久化（UserDefaults）
@Observable
final class StatsStore {
    private(set) var results: [Int: DayResult] = [:]
    private(set) var practiceBest = 0

    private let defaults: UserDefaults
    private static let resultsKey = "daily2048.results"
    private static let practiceBestKey = "daily2048.practiceBest"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.resultsKey),
           let decoded = try? JSONDecoder().decode([Int: DayResult].self, from: data) {
            results = decoded
        }
        practiceBest = defaults.integer(forKey: Self.practiceBestKey)
    }

    func record(_ result: DayResult) {
        results[result.day] = result
        persist()
    }

    func hasPlayed(day: Int) -> Bool {
        results[day] != nil
    }

    func updatePracticeBest(score: Int) {
        guard score > practiceBest else { return }
        practiceBest = score
        defaults.set(score, forKey: Self.practiceBestKey)
    }

    /// 当天或昨天起往前连续完成的天数
    var currentStreak: Int {
        let today = DailyClock.dayNumber()
        var day = hasPlayed(day: today) ? today : today - 1
        var streak = 0
        while hasPlayed(day: day) {
            streak += 1
            day -= 1
        }
        return streak
    }

    var maxStreak: Int {
        let days = results.keys.sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1
        var run = 1
        for i in 1..<days.count {
            run = days[i] == days[i - 1] + 1 ? run + 1 : 1
            best = max(best, run)
        }
        return best
    }

    var playedDays: Int { results.count }
    var bestDailyScore: Int { results.values.map(\.score).max() ?? 0 }

    /// 最近 count 天（含今天），未完成为 nil
    func recentResults(count: Int = 7) -> [DayResult?] {
        let today = DailyClock.dayNumber()
        return Array((today - count + 1)...today).map { results[$0] }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(results) {
            defaults.set(data, forKey: Self.resultsKey)
        }
    }
}
