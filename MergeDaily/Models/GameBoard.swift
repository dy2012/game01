import Foundation

enum Direction: String, CaseIterable, Codable, Sendable {
    case up, down, left, right
}

/// 一次新方块：value 为数值（2 或 4），slot 用于在当前空位列表中确定性选位
struct Spawn: Equatable, Sendable {
    let value: Int
    let slot: Int
}

/// 存活方块的一次位移（棋盘索引，行优先）
struct TileSlide: Equatable, Sendable {
    let from: Int
    let to: Int
}

/// 一次合并：两个源格合成目标格
struct TileMerge: Equatable, Sendable {
    let sources: [Int]
    let destination: Int
    let value: Int
}

/// 一步移动的完整事件，供 UI 做分阶段动画（滑动 → 结算 → 新方块）
struct MoveResult: Equatable, Sendable {
    let direction: Direction
    let slides: [TileSlide]
    let merges: [TileMerge]
    let spawn: Spawn
    let spawnIndex: Int
    let gained: Int
}

/// 4x4 棋盘，行优先存储，0 表示空格
struct GameBoard: Codable, Equatable, Hashable, Sendable {
    static let size = 4

    private(set) var tiles: [Int]
    private(set) var score: Int = 0
    private(set) var moves: Int = 0
    /// 已生成到第几个新方块，配合 seed 可确定性重放整局
    private(set) var spawnIndex: Int = 0

    init(tiles: [Int] = Array(repeating: 0, count: GameBoard.size * GameBoard.size),
         score: Int = 0,
         moves: Int = 0,
         spawnIndex: Int = 0) {
        self.tiles = tiles
        self.score = score
        self.moves = moves
        self.spawnIndex = spawnIndex
    }

    var maxTile: Int { tiles.max() ?? 0 }
    var hasReached2048: Bool { maxTile >= 2048 }
    var nonEmptyCount: Int { tiles.filter { $0 != 0 }.count }

    var isOver: Bool {
        Direction.allCases.allSatisfy { !canMove($0) }
    }

    func canMove(_ direction: Direction) -> Bool {
        for line in 0..<Self.size {
            let values = Self.lineIndices(line, direction: direction).map { tiles[$0] }
            if Self.mergeLine(values).changed { return true }
        }
        return false
    }

    /// 执行一步移动并在产生变化时生成新方块。
    /// spawn 闭包接收当前 spawnIndex，返回该步生成的方块；
    /// 返回 nil 表示该方向无变化（非法移动），不会产生任何副作用。
    @discardableResult
    mutating func move(_ direction: Direction, spawn: (Int) -> Spawn) -> MoveResult? {
        var slides: [TileSlide] = []
        var merges: [TileMerge] = []
        var gainedTotal = 0
        var moved = false

        for line in 0..<Self.size {
            let indices = Self.lineIndices(line, direction: direction)
            let outcome = Self.mergeLine(indices.map { tiles[$0] })
            guard outcome.changed else { continue }
            moved = true
            gainedTotal += outcome.gained
            for (slot, value) in outcome.merged.enumerated() {
                tiles[indices[slot]] = value
            }
            for lineMove in outcome.moves {
                slides.append(TileSlide(from: indices[lineMove.from], to: indices[lineMove.to]))
            }
            for lineMerge in outcome.merges {
                let sources = [indices[lineMerge.fromA], indices[lineMerge.fromB]].sorted()
                merges.append(TileMerge(sources: sources,
                                        destination: indices[lineMerge.to],
                                        value: lineMerge.value))
            }
        }

        guard moved else { return nil }

        let newSpawn = spawn(spawnIndex)
        let spawnAt = place(newSpawn) ?? -1
        spawnIndex += 1
        moves += 1
        score += gainedTotal

        return MoveResult(direction: direction,
                          slides: slides,
                          merges: merges,
                          spawn: newSpawn,
                          spawnIndex: spawnAt,
                          gained: gainedTotal)
    }

    /// 开局落子（前两个方块）
    mutating func placeInitialSpawns(_ first: Spawn, _ second: Spawn) {
        place(first)
        spawnIndex += 1
        place(second)
        spawnIndex += 1
    }

    /// 在空位中确定性放置方块：空位按行优先排序，取 slot 对空位数取模；返回落点
    @discardableResult
    mutating func place(_ spawn: Spawn) -> Int? {
        let empty = tiles.indices.filter { tiles[$0] == 0 }
        guard !empty.isEmpty else { return nil }
        let index = empty[spawn.slot % empty.count]
        tiles[index] = spawn.value
        return index
    }

    /// 返回该方向第 line 条线的 4 个格位下标，顺序为“滑动方向的头部在前”
    static func lineIndices(_ line: Int, direction: Direction) -> [Int] {
        var indices: [Int]
        switch direction {
        case .left: indices = (0..<size).map { line * size + $0 }
        case .right: indices = (0..<size).map { line * size + $0 }
        case .up: indices = (0..<size).map { $0 * size + line }
        case .down: indices = (0..<size).map { $0 * size + line }
        }
        if direction == .right || direction == .down {
            indices.reverse()
        }
        return indices
    }

    struct LineMove: Equatable, Sendable {
        let from: Int
        let to: Int
    }

    struct LineMerge: Equatable, Sendable {
        let fromA: Int
        let fromB: Int
        let to: Int
        let value: Int
    }

    /// 单线合并：向头部压缩，相邻同值各合并一次（不连锁）。
    /// moves 记录存活方块的位移，merges 记录合并对（线内坐标）。
    static func mergeLine(_ line: [Int]) -> (merged: [Int], gained: Int, changed: Bool,
                                             moves: [LineMove], merges: [LineMerge]) {
        let nonZero = line.enumerated().filter { $0.element != 0 }.map { (offset: $0.offset, value: $0.element) }
        var merged: [Int] = []
        var moves: [LineMove] = []
        var merges: [LineMerge] = []
        var gained = 0
        var i = 0
        while i < nonZero.count {
            let destination = merged.count
            if i + 1 < nonZero.count, nonZero[i].value == nonZero[i + 1].value {
                let value = nonZero[i].value * 2
                merges.append(LineMerge(fromA: nonZero[i].offset, fromB: nonZero[i + 1].offset,
                                        to: destination, value: value))
                merged.append(value)
                gained += value
                i += 2
            } else {
                if nonZero[i].offset != destination {
                    moves.append(LineMove(from: nonZero[i].offset, to: destination))
                }
                merged.append(nonZero[i].value)
                i += 1
            }
        }
        while merged.count < line.count {
            merged.append(0)
        }
        return (merged, gained, merged != line, moves, merges)
    }
}
