import Foundation
import SwiftUI
import Observation

enum GameMode: String, CaseIterable {
    case daily = "每日挑战"
    case practice = "自由练习"
}

@Observable
final class GameViewModel {
    enum Phase: Equatable {
        case playing
        case finished
    }

    // 每日 / 练习两副棋盘各自独立，切换模式互不影响
    private(set) var dailyBoard: GameBoard
    private(set) var practiceBoard: GameBoard
    private(set) var mode: GameMode = .daily
    private(set) var dailyPhase: Phase = .playing
    private(set) var practicePhase: Phase = .playing
    private(set) var showWin = false

    // UI 渲染状态（与引擎棋盘解耦，驱动分阶段动画）
    private(set) var displayTiles: [TileModel] = []
    private(set) var displayScore = 0
    private(set) var nudge: Nudge?
    var soundEnabled: Bool = SoundPlayer.isEnabled {
        didSet { SoundPlayer.isEnabled = soundEnabled }
    }

    let stats: StatsStore

    private let defaults: UserDefaults
    private let dailyPuzzle: DailyPuzzle
    private(set) var practicePuzzle: DailyPuzzle
    private var dailyStartedAt = Date()
    private var winCelebrated = false

    // 动画编排
    private var animTask: Task<Void, Never>?
    private var pendingResult: MoveResult?

    static let snapshotKey = "daily2048.snapshot"

    var board: GameBoard { mode == .daily ? dailyBoard : practiceBoard }
    var phase: Phase { mode == .daily ? dailyPhase : practicePhase }
    var isFinished: Bool { phase == .finished }
    var dayNumber: Int { DailyClock.dayNumber() }
    /// 展示用天号：第 1 天起计
    var displayDay: Int { dayNumber + 1 }
    var todayResult: DayResult? {
        stats.results[dayNumber]
    }
    var currentStreak: Int { stats.currentStreak }
    var practiceBest: Int { stats.practiceBest }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stats = StatsStore(defaults: defaults)
        self.stats = stats
        let today = DailyClock.dayNumber()
        dailyPuzzle = DailyPuzzle(dayNumber: today)

        var isFreshDay = false
        if let result = stats.results[today] {
            // 今天已完成：直接呈现终局盘面
            dailyBoard = GameBoard(tiles: result.tiles,
                                   score: result.score,
                                   moves: result.moves,
                                   spawnIndex: result.moves + 2)
            dailyPhase = .finished
            dailyStartedAt = Date()
        } else if let snapshot = Self.loadSnapshot(day: today, defaults: defaults) {
            // 中断续玩
            dailyBoard = snapshot.board
            dailyStartedAt = snapshot.startedAt
        } else {
            // 全新的一天
            dailyBoard = dailyPuzzle.makeInitialBoard()
            dailyStartedAt = Date()
            isFreshDay = true
        }

        let newPractice = DailyPuzzle()
        practicePuzzle = newPractice
        practiceBoard = newPractice.makeInitialBoard()

        displayTiles = Self.settledTiles(from: dailyBoard)
        displayScore = dailyBoard.score
        soundEnabled = SoundPlayer.isEnabled

        if isFreshDay {
            saveDailySnapshot()
        }
    }

    // MARK: - 交互

    func switchMode(to newMode: GameMode) {
        guard newMode != mode else { return }
        mode = newMode
        withAnimation(.easeOut(duration: 0.18)) {
            syncDisplay()
        }
    }

    /// 无效移动的“推不动”提示
    struct Nudge: Equatable {
        let direction: Direction
        let id = UUID()
    }

    func move(_ direction: Direction) {
        guard phase == .playing, !showWin else { return }

        // 新滑动到来：立即结算完上一步（保留动画与反馈），保证状态一致
        animTask?.cancel()
        finalizePendingSettle()
        // 快进可能触发终局结算或 2048 弹窗，需要重新检查
        guard phase == .playing, !showWin else { return }
        // 防御：显示与引擎不一致（历史错乱）时全量对齐自愈
        if !displayMatchesEngine() {
            syncDisplay()
        }

        let result: MoveResult?
        switch mode {
        case .daily:
            var board = dailyBoard
            result = board.move(direction, spawn: dailyPuzzle.spawn(at:))
            dailyBoard = board
            if result != nil { saveDailySnapshot() }
        case .practice:
            var board = practiceBoard
            result = board.move(direction, spawn: practicePuzzle.spawn(at:))
            practiceBoard = board
        }
        guard let result else {
            nudge = Nudge(direction: direction)
            return
        }

        pendingResult = result
        SoundPlayer.play(.move)

        // 阶段 A：滑动——存活方块与被合并方块一起滑向目标位（数值不变）
        var tiles = displayTiles
        for slide in result.slides {
            if let i = tiles.firstIndex(where: { $0.index == slide.from }) {
                tiles[i].index = slide.to
            }
        }
        for merge in result.merges {
            for source in merge.sources {
                if let i = tiles.firstIndex(where: { $0.index == source }) {
                    tiles[i].index = merge.destination
                }
            }
        }
        withAnimation(.easeOut(duration: 0.10)) {
            displayTiles = tiles
        }

        // 阶段 B（+85ms，滑动收尾时）：合并结算 + 新方块落位（同一个等待点，
        // 状态一次到位，连滑取消时由快进全量对齐，不会丢牌）
        animTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(85))
            guard let self, !Task.isCancelled else { return }
            self.settleMerge(result)
        }
    }

    /// 放弃今日挑战，以当前分数结算
    func giveUpDaily() {
        guard mode == .daily, dailyPhase == .playing else { return }
        animTask?.cancel()
        finalizePendingSettle()
        finishDaily()
    }

    func restartPractice() {
        animTask?.cancel()
        finalizePendingSettle()
        winCelebrated = false
        practicePuzzle = DailyPuzzle()
        practiceBoard = practicePuzzle.makeInitialBoard()
        practicePhase = .playing
        syncDisplay()
    }

    func dismissWin() {
        showWin = false
    }

    // MARK: - 动画阶段

    /// 阶段 B：合并结算——结果方块翻倍放大、触感、音效；
    /// 新方块与结算同批写入状态（动画稍延迟），保证任何时刻显示与引擎一致
    private func settleMerge(_ result: MoveResult) {
        pendingResult = nil
        var tiles = displayTiles
        var maxValue = 0

        for merge in result.merges {
            // 目标格收敛为一张结果牌：保留一张承载合并值，其余全部清除（防御叠加残留）
            let occupants = tiles.filter { $0.index == merge.destination }
            if let keeper = occupants.first {
                tiles.removeAll { $0.index == merge.destination && $0.id != keeper.id }
                if let i = tiles.firstIndex(where: { $0.id == keeper.id }) {
                    tiles[i].value = merge.value
                    tiles[i].pop = true
                }
            } else {
                tiles.append(TileModel(id: UUID(), value: merge.value, index: merge.destination, pop: true))
            }
            maxValue = max(maxValue, merge.value)
        }

        var newTile: TileModel? = (result.spawnIndex >= 0
                                    && board.tiles[result.spawnIndex] == result.spawn.value)
            ? TileModel(id: UUID(), value: result.spawn.value, index: result.spawnIndex)
            : nil
        // 防重复：该位置已有显示牌时不再插入
        if let tile = newTile, tiles.contains(where: { $0.index == tile.index }) {
            newTile = nil
        }

        if result.merges.isEmpty && newTile == nil {
            // 纯滑动只同步分数显示
            displayTiles = tiles
            displayScore = board.score
        } else {
            if !result.merges.isEmpty {
                Haptics.merge(maxValue: maxValue)
                SoundPlayer.play(.merge, rate: SoundPlayer.mergeRate(for: maxValue))
            }
            withAnimation(.spring(response: 0.16, dampingFraction: 0.6)) {
                displayTiles = tiles
                displayScore = board.score
            }
            if let newTile {
                // 状态立即落位，动画延迟 40ms 出现（衔接感）
                withAnimation(.easeOut(duration: 0.09).delay(0.04)) {
                    displayTiles.append(newTile)
                }
            }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(120))
                guard let self else { return }
                var cleared = self.displayTiles
                for i in cleared.indices {
                    cleared[i].pop = false
                }
                withAnimation(.easeOut(duration: 0.1)) {
                    self.displayTiles = cleared
                }
            }
        }

        // 引擎权威校正：本步涉及的所有格子必须与引擎完全一致。
        // 正常路径此校验零触发；任何幽灵牌/丢牌在此被当场修复
        reconcileWithEngine(result)

        checkEndConditions()
    }

    /// 对本步涉及的格子（合并的源与目标、新方块落点）逐格校正为引擎状态
    private func reconcileWithEngine(_ result: MoveResult) {
        var touched = Set(result.merges.flatMap { merge in [merge.destination] + merge.sources })
        if result.spawnIndex >= 0 {
            touched.insert(result.spawnIndex)
        }

        var tiles = displayTiles
        var changed = false
        for index in touched {
            let engineValue = board.tiles[index]
            let occupants = tiles.filter { $0.index == index }
            if occupants.count != 1 || occupants.first?.value != engineValue {
                changed = true
                tiles.removeAll { $0.index == index }
                if engineValue > 0 {
                    let pop = occupants.first(where: { $0.value == engineValue })?.pop ?? true
                    tiles.append(TileModel(id: UUID(), value: engineValue, index: index, pop: pop))
                }
            }
        }
        if changed {
            displayTiles = tiles
            displayScore = board.score
        }
    }

    /// 快进：立即把未完成的结算正常执行完（保留动画与反馈，而非瞬移），
    /// 新方块也在 settleMerge 内同步落位，连滑永不丢牌
    private func finalizePendingSettle() {
        guard let pending = pendingResult else { return }
        settleMerge(pending)
    }

    /// 胜利/终局检查（在结算时刻触发，保证玩家看到最后一步）
    private func checkEndConditions() {
        guard phase == .playing else { return }
        if board.hasReached2048 && !winCelebrated {
            winCelebrated = true
            showWin = true
            Haptics.win()
            SoundPlayer.play(.win)
        }
        if board.isOver {
            switch mode {
            case .daily:
                finishDaily()
            case .practice:
                stats.updatePracticeBest(score: practiceBoard.score)
                practicePhase = .finished
            }
            Haptics.gameOver()
            SoundPlayer.play(.gameover)
        }
    }

    private func finishDaily() {
        let result = DayResult(day: dayNumber,
                               score: dailyBoard.score,
                               moves: dailyBoard.moves,
                               maxTile: dailyBoard.maxTile,
                               tiles: dailyBoard.tiles,
                               seconds: max(0, Int(Date().timeIntervalSince(dailyStartedAt))),
                               date: Date())
        stats.record(result)
        defaults.removeObject(forKey: Self.snapshotKey)
        dailyPhase = .finished
    }

    /// 把渲染状态对齐到引擎棋盘（模式切换 / 重开 / 快进）
    private func syncDisplay() {
        displayTiles = Self.settledTiles(from: board)
        displayScore = board.score
    }

    /// 显示与引擎的牌值集合是否一致（每格一张、数值相同）
    private func displayMatchesEngine() -> Bool {
        guard displayTiles.count == board.nonEmptyCount else { return false }
        for tile in displayTiles where board.tiles[tile.index] != tile.value {
            return false
        }
        return true
    }

    private static func settledTiles(from board: GameBoard) -> [TileModel] {
        var tiles: [TileModel] = []
        for (index, value) in board.tiles.enumerated() where value > 0 {
            tiles.append(TileModel(id: UUID(), value: value, index: index))
        }
        return tiles
    }

    // MARK: - 存档

    private static func loadSnapshot(day: Int, defaults: UserDefaults) -> DailySnapshot? {
        guard let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(DailySnapshot.self, from: data),
              snapshot.day == day else { return nil }
        return snapshot
    }

    private func saveDailySnapshot() {
        let snapshot = DailySnapshot(day: dayNumber, board: dailyBoard, startedAt: dailyStartedAt)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.snapshotKey)
        }
    }
}
