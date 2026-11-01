import XCTest
@testable import MergeDaily

final class StatsStoreTests: XCTestCase {

    private func makeStore() -> (StatsStore, UserDefaults) {
        let suite = "test.stats.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (StatsStore(defaults: defaults), defaults)
    }

    private func result(day: Int, score: Int = 100) -> DayResult {
        DayResult(day: day, score: score, moves: 50, maxTile: 64,
                  tiles: Array(repeating: 0, count: 16), seconds: 120, date: Date())
    }

    func testRecordAndQuery() {
        let (store, _) = makeStore()
        let today = DailyClock.dayNumber()
        XCTAssertFalse(store.hasPlayed(day: today))
        store.record(result(day: today))
        XCTAssertTrue(store.hasPlayed(day: today))
        XCTAssertEqual(store.playedDays, 1)
        XCTAssertEqual(store.bestDailyScore, 100)
    }

    func testCurrentStreakFromToday() {
        let (store, _) = makeStore()
        let today = DailyClock.dayNumber()
        store.record(result(day: today))
        store.record(result(day: today - 1))
        store.record(result(day: today - 2))
        XCTAssertEqual(store.currentStreak, 3)
        XCTAssertEqual(store.maxStreak, 3)
    }

    func testStreakContinuesFromYesterday() {
        // 今天还没玩，昨天的连胜仍在
        let (store, _) = makeStore()
        let today = DailyClock.dayNumber()
        store.record(result(day: today - 1))
        store.record(result(day: today - 2))
        XCTAssertEqual(store.currentStreak, 2)
    }

    func testStreakBreaksOnGap() {
        let (store, _) = makeStore()
        let today = DailyClock.dayNumber()
        store.record(result(day: today))
        store.record(result(day: today - 2))  // 昨天缺席
        store.record(result(day: today - 3))
        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertEqual(store.maxStreak, 2)
    }

    func testPersistenceAcrossInstances() {
        let suite = "test.stats.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let today = DailyClock.dayNumber()
        StatsStore(defaults: defaults).record(result(day: today, score: 250))

        let reloaded = StatsStore(defaults: defaults)
        XCTAssertEqual(reloaded.bestDailyScore, 250)
        XCTAssertEqual(reloaded.currentStreak, 1)
    }

    func testPracticeBest() {
        let (store, _) = makeStore()
        store.updatePracticeBest(score: 300)
        store.updatePracticeBest(score: 200)
        XCTAssertEqual(store.practiceBest, 300)
    }

    func testRecentResults() {
        let (store, _) = makeStore()
        let today = DailyClock.dayNumber()
        store.record(result(day: today))
        let recent = store.recentResults(count: 7)
        XCTAssertEqual(recent.count, 7)
        XCTAssertNotNil(recent[6])
        XCTAssertNil(recent[0])
    }
}
