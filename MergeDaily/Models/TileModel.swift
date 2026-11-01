import Foundation

/// UI 层的方块：带身份，位置变化即产生滑动动画
struct TileModel: Identifiable, Equatable {
    let id: UUID
    var value: Int
    var index: Int          // 棋盘索引，行优先
    var pop: Bool = false   // 合并结算时的放大标记
}
