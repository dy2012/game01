import XCTest
@testable import MergeDaily

/// 显示层与引擎的一致性压力测试：各种节奏连滑后，两者必须完全收敛
@MainActor
final class GameViewModelTests: XCTestCase {

    private func makeVM() -> GameViewModel {
        let suite = "test.vm.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return GameViewModel(defaults: defaults)
    }

    /// 显示的牌值集合、分数必须与引擎完全一致
    private func assertConsistent(_ vm: GameViewModel, _ context: String) {
        let expected = vm.board.tiles.filter { $0 > 0 }.sorted()
        let shown = vm.displayTiles.map(\.value).sorted()
        XCTAssertEqual(shown, expected,
                       "\(context)：显示 \(shown) vs 引擎 \(expected)")
        XCTAssertEqual(vm.displayScore, vm.board.score, "\(context)：分数不一致")
        // 每张牌的位置也必须与引擎一致
        var enginePositions: [Int: Int] = [:]   // value -> count
        for (index, value) in vm.board.tiles.enumerated() where value > 0 {
            enginePositions[value, default: 0] += 1
        }
        var shownPositions: [Int: Int] = [:]
        for tile in vm.displayTiles {
            let engineValue = vm.board.tiles[tile.index]
            XCTAssertEqual(tile.value, engineValue,
                           "\(context)：格 \(tile.index) 显示 \(tile.value) vs 引擎 \(engineValue)")
            shownPositions[tile.value, default: 0] += 1
        }
        XCTAssertEqual(shownPositions, enginePositions, "\(context)：位置分布不一致")
    }

    func testDisplayConsistencyUnderMixedRhythm() async {
        let vm = makeVM()
        vm.switchMode(to: .practice)

        var rng = SeededGenerator(seed: 20261101)
        for step in 0..<400 {
            let direction = Direction.allCases[Int(rng.next() % 4)]
            vm.move(direction)
            // 模拟真实点按节奏：极快连点 / 稍慢 / 等结算完成后再滑
            let waits = [0, 3, 12, 30, 60, 85, 90, 130]
            try? await Task.sleep(for: .milliseconds(waits[Int(rng.next() % UInt64(waits.count))]))
            // 周期性校验：先保证本步结算动画期结束
            if step % 23 == 0 {
                try? await Task.sleep(for: .milliseconds(160))
                assertConsistent(vm, "第 \(step) 步")
            }
        }
        try? await Task.sleep(for: .milliseconds(300))
        assertConsistent(vm, "终态")
    }

    func testDisplayConsistencyFastTapBurst() async {
        // 极限连点：0 间隔连发（最容易撞上快进路径）
        let vm = makeVM()
        vm.switchMode(to: .practice)
        var rng = SeededGenerator(seed: 777)
        for step in 0..<200 {
            let direction = Direction.allCases[Int(rng.next() % 4)]
            vm.move(direction)
        }
        try? await Task.sleep(for: .milliseconds(400))
        assertConsistent(vm, "连发后")
    }

    func testPracticeRestartAndModeSwitchConsistency() async {
        let vm = makeVM()
        vm.switchMode(to: .practice)
        var rng = SeededGenerator(seed: 42)
        for _ in 0..<30 {
            vm.move(Direction.allCases[Int(rng.next() % 4)])
            try? await Task.sleep(for: .milliseconds(20))
        }
        vm.switchMode(to: .daily)
        assertConsistent(vm, "切到每日")
        vm.switchMode(to: .practice)
        try? await Task.sleep(for: .milliseconds(150))
        assertConsistent(vm, "切回练习")
        vm.restartPractice()
        assertConsistent(vm, "重开练习")
    }
}
