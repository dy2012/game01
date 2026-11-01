import SwiftUI

/// 棋盘：网格背景 + 带身份的方块绝对定位渲染。
/// 方块的 index 变化即产生滑动动画，数值变化配合 pop 标记做合并放大。
struct BoardView: View {
    let tiles: [TileModel]
    var nudge: GameViewModel.Nudge? = nil
    let onSwipe: (Direction) -> Void

    @State private var swipeConsumed = false
    @State private var nudgeOffset: CGSize = .zero

    private let padding: CGFloat = 10
    private let spacing: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            // 布局未稳定或空间被挤占时 geo 可能为负/NaN，钳制下限避免非法尺寸传给 frame
            let width = geo.size.width.isFinite ? max(0, geo.size.width) : 0
            let cell = max(24, (width - padding * 2 - spacing * 3) / 4)
            let step = cell + spacing
            let origin = CGPoint(x: padding + cell / 2, y: padding + cell / 2)
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.board)
                // 空格底座
                ForEach(0..<GameBoard.size * GameBoard.size, id: \.self) { index in
                    RoundedRectangle(cornerRadius: cell * 0.1)
                        .fill(Theme.cellEmpty)
                        .frame(width: cell, height: cell)
                        .position(x: origin.x + CGFloat(index % 4) * step,
                                  y: origin.y + CGFloat(index / 4) * step)
                }
                // 方块
                ForEach(tiles) { tile in
                    TileView(value: tile.value, size: cell, pop: tile.pop)
                        .frame(width: cell, height: cell)
                        .position(x: origin.x + CGFloat(tile.index % 4) * step,
                                  y: origin.y + CGFloat(tile.index / 4) * step)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .offset(nudgeOffset)
        .onChange(of: nudge) { _, new in
            guard let new else { return }
            let distance: CGFloat = 5
            let target: CGSize
            switch new.direction {
            case .left: target = CGSize(width: -distance, height: 0)
            case .right: target = CGSize(width: distance, height: 0)
            case .up: target = CGSize(width: 0, height: -distance)
            case .down: target = CGSize(width: 0, height: distance)
            }
            // 朝滑动方向轻推后回弹，示意“这个方向走不动”
            withAnimation(.easeOut(duration: 0.05)) { nudgeOffset = target }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(55))
                withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                    nudgeOffset = .zero
                }
            }
        }
        .gesture(swipeGesture)
        // 外接键盘方向键（iPad / Catalyst）
        .focusable()
        .onKeyPress { press in
            switch press.key {
            case .upArrow: onSwipe(.up); return .handled
            case .downArrow: onSwipe(.down); return .handled
            case .leftArrow: onSwipe(.left); return .handled
            case .rightArrow: onSwipe(.right); return .handled
            default: return .ignored
            }
        }
    }

    /// 走棋手势：方向明确后立即触发（不等抬手）。
    /// 起步轨迹往往是斜的，必须等主导轴明显领先才判定方向，
    /// 否则横滑会被误判成竖滑，把相邻的牌拆散。
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // 手势被系统取消（边缘/控制中心抢占等）时 onEnded 不会回调，
                // consumed 会永久卡死导致棋盘无响应；
                // 新一次触摸的 translation 会从近零开始，借此解锁
                if swipeConsumed,
                   abs(value.translation.width) < 4, abs(value.translation.height) < 4 {
                    swipeConsumed = false
                }
                guard !swipeConsumed else { return }
                let dx = abs(value.translation.width)
                let dy = abs(value.translation.height)
                if dx >= 22 && dx > dy * 1.4 {
                    swipeConsumed = true
                    onSwipe(value.translation.width > 0 ? .right : .left)
                } else if dy >= 22 && dy > dx * 1.4 {
                    swipeConsumed = true
                    onSwipe(value.translation.height > 0 ? .down : .up)
                }
            }
            .onEnded { value in
                // 兜底：轨迹始终模糊（近 45°）或未达阈值时，按最终主导轴判定
                if !swipeConsumed {
                    let dx = abs(value.translation.width)
                    let dy = abs(value.translation.height)
                    guard max(dx, dy) >= 20 else { return }
                    if dx >= dy {
                        onSwipe(value.translation.width > 0 ? .right : .left)
                    } else {
                        onSwipe(value.translation.height > 0 ? .down : .up)
                    }
                }
                swipeConsumed = false
            }
    }
}

struct TileView: View {
    let value: Int
    var size: CGFloat = 70
    var pop: Bool = false

    var body: some View {
        Text("\(value)")
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(Theme.tileTextColor(value))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.tileColor(value))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.1))
            .scaleEffect(pop ? 1.16 : 1)
    }

    private var fontSize: CGFloat {
        switch value {
        case ..<100: size * 0.42
        case ..<1000: size * 0.34
        case ..<10000: size * 0.26
        default: size * 0.21
        }
    }
}

#Preview {
    let board = DailyPuzzle(dayNumber: 304).makeInitialBoard()
    let tiles = board.tiles.enumerated().compactMap { index, value in
        value > 0 ? TileModel(id: UUID(), value: value, index: index) : nil
    }
    return BoardView(tiles: tiles) { _ in }
        .padding(40)
}
