import XCTest
@testable import MergeDaily

final class GameBoardTests: XCTestCase {

    // MARK: - 单线合并

    func testMergeLineBasicPair() {
        let result = GameBoard.mergeLine([2, 2, 0, 0])
        XCTAssertEqual(result.merged, [4, 0, 0, 0])
        XCTAssertEqual(result.gained, 4)
        XCTAssertTrue(result.changed)
    }

    func testMergeLineNoDoubleMerge() {
        // 2+2=4 后不能与后面的 4 再合并；4+4=8 各合并一次
        let result = GameBoard.mergeLine([2, 2, 4, 4])
        XCTAssertEqual(result.merged, [4, 8, 0, 0])
        XCTAssertEqual(result.gained, 12)
    }

    func testMergeLineFourSame() {
        let result = GameBoard.mergeLine([2, 2, 2, 2])
        XCTAssertEqual(result.merged, [4, 4, 0, 0])
        XCTAssertEqual(result.gained, 8)
    }

    func testMergeLineUnchanged() {
        // 已压实且无相同相邻：既不合并也不移动
        let unchanged = GameBoard.mergeLine([2, 4, 8, 16])
        XCTAssertEqual(unchanged.merged, [2, 4, 8, 16])
        XCTAssertFalse(unchanged.changed)
        XCTAssertEqual(unchanged.gained, 0)

        // 仅滑动、不合并，也算有变化
        let shifted = GameBoard.mergeLine([2, 0, 4, 8])
        XCTAssertEqual(shifted.merged, [2, 4, 8, 0])
        XCTAssertTrue(shifted.changed)
    }

    // MARK: - 移动与计分

    func testMoveLeftScores() {
        var board = GameBoard(tiles: [2, 2, 0, 0,
                                      0, 0, 0, 0,
                                      0, 0, 0, 0,
                                      0, 0, 0, 0])
        let result = board.move(.left) { _ in Spawn(value: 2, slot: 0) }
        XCTAssertNotNil(result)
        XCTAssertEqual(board.score, 4)
        XCTAssertEqual(board.moves, 1)
        XCTAssertEqual(board.spawnIndex, 1)
        // 左端合并成 4，新方块在尾部空位
        XCTAssertEqual(board.tiles[0], 4)
        XCTAssertEqual(board.nonEmptyCount, 2)
    }

    func testInvalidMoveReturnsNil() {
        var board = GameBoard(tiles: [2, 4, 8, 16,
                                      0, 0, 0, 0,
                                      0, 0, 0, 0,
                                      0, 0, 0, 0])
        let result = board.move(.left) { _ in Spawn(value: 2, slot: 0) }
        XCTAssertNil(result)
        XCTAssertEqual(board.moves, 0)
        XCTAssertEqual(board.score, 0)
    }

    // MARK: - 移动事件

    func testMoveResultTransitions() {
        // 第一行 [2, 2, 4, 0] 左滑：2+2 合并到格0，4 滑到格1
        var board = GameBoard(tiles: [2, 2, 4, 0,
                                      0, 0, 0, 0,
                                      0, 0, 0, 0,
                                      0, 0, 0, 0])
        let result = board.move(.left) { _ in Spawn(value: 2, slot: 0) }
        XCTAssertNotNil(result)
        let events = result!
        XCTAssertEqual(events.merges, [TileMerge(sources: [0, 1], destination: 0, value: 4)])
        XCTAssertEqual(events.slides, [TileSlide(from: 2, to: 1)])
        XCTAssertEqual(events.gained, 4)
        // 第一行变为 [4,4,0,0]，新方块落在行优先最小的空格（index 2）
        XCTAssertEqual(events.spawnIndex, 2)
        XCTAssertEqual(events.spawn.value, 2)
    }

    func testMoveResultRightDirection() {
        // [2, 2, 0, 0] 右滑：两个 2 都滑向行尾并合并
        var board = GameBoard(tiles: [2, 2, 0, 0,
                                      0, 0, 0, 0,
                                      0, 0, 0, 0,
                                      0, 0, 0, 0])
        let result = board.move(.right) { _ in Spawn(value: 4, slot: 5) }
        let events = result!
        XCTAssertEqual(events.merges, [TileMerge(sources: [0, 1], destination: 3, value: 4)])
        XCTAssertTrue(events.slides.isEmpty)
        XCTAssertEqual(board.tiles[3], 4)
        XCTAssertEqual(events.gained, 4)
    }

    func testMoveUpAndDownMerges() {
        // 第 1、2 行同列各有 2：上滑合并到格 4，下滑合并到格 8
        var upBoard = GameBoard(tiles: [0, 2, 0, 0,
                                        0, 2, 0, 0,
                                        0, 0, 0, 0,
                                        0, 0, 0, 0])
        let up = upBoard.move(.up) { _ in Spawn(value: 2, slot: 0) }!
        XCTAssertEqual(up.merges, [TileMerge(sources: [1, 5], destination: 1, value: 4)])
        XCTAssertEqual(upBoard.tiles[1], 4)

        var downBoard = GameBoard(tiles: [0, 2, 0, 0,
                                          0, 2, 0, 0,
                                          0, 0, 0, 0,
                                          0, 0, 0, 0])
        let down = downBoard.move(.down) { _ in Spawn(value: 2, slot: 0) }!
        XCTAssertEqual(down.merges, [TileMerge(sources: [1, 5], destination: 13, value: 4)])
        XCTAssertEqual(downBoard.tiles[13], 4)
    }

    func testGameOverDetection() {
        var board = GameBoard(tiles: [2, 4, 2, 4,
                                      4, 2, 4, 2,
                                      2, 4, 2, 4,
                                      4, 2, 4, 2])
        XCTAssertTrue(board.isOver)

        board = GameBoard(tiles: [2, 4, 2, 4,
                                  4, 2, 4, 2,
                                  2, 4, 2, 4,
                                  4, 2, 4, 0])
        XCTAssertFalse(board.isOver)
    }

    // MARK: - 每日确定性

    func testSpawnDeterminismSameDay() {
        let puzzle = DailyPuzzle(dayNumber: 42)
        let replay = DailyPuzzle(dayNumber: 42)
        for index in 0..<100 {
            XCTAssertEqual(puzzle.spawn(at: index), replay.spawn(at: index))
        }
        for index in 0..<100 {
            XCTAssertTrue([2, 4].contains(puzzle.spawn(at: index).value))
        }
    }

    func testSameMovesProduceSameBoard() {
        let directions: [Direction] = [.left, .up, .right, .down, .left, .left, .up, .right,
                                       .down, .down, .left, .up, .right, .left, .up, .down]
        var first = DailyPuzzle(dayNumber: 304).makeInitialBoard()
        var second = DailyPuzzle(dayNumber: 304).makeInitialBoard()
        let puzzle = DailyPuzzle(dayNumber: 304)
        for direction in directions {
            first.move(direction, spawn: puzzle.spawn(at:))
            second.move(direction, spawn: puzzle.spawn(at:))
        }
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.score, second.score)
    }

    func testDifferentDaysProduceDifferentBoards() {
        var boards = Set<GameBoard>()
        for day in 0..<10 {
            boards.insert(DailyPuzzle(dayNumber: day).makeInitialBoard())
        }
        XCTAssertGreaterThan(boards.count, 1)
    }

    func testDayNumberArithmetic() {
        // 2026-11-01T00:00:00Z 是第 304 天
        let date = Date(timeIntervalSince1970: Double(20454 + 304) * 86_400)
        XCTAssertEqual(DailyClock.dayNumber(at: date), 304)
        // 下一个 UTC 零点
        let next = DailyClock.nextPuzzleDate(after: date)
        XCTAssertEqual(next.timeIntervalSince(date), 86_400, accuracy: 0.001)
    }
}
