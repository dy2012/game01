import SwiftUI

/// 分享用战绩卡（渲染为图片分享）
struct ResultCardView: View {
    let displayDay: Int
    let result: DayResult
    let streak: Int

    var body: some View {
        VStack(spacing: 14) {
            Text("每日合合")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Theme.text)
            Text("第 \(displayDay) 天")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                Text("\(result.score)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accentOrange)
                Text("分")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
            }

            HStack(spacing: 8) {
                chip(icon: "🎯", text: "\(result.maxTile)")
                chip(icon: "👟", text: "\(result.moves) 步")
                chip(icon: "🔥", text: "\(streak) 连胜")
            }

            VStack(spacing: 2) {
                ForEach(0..<GameBoard.size, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<GameBoard.size, id: \.self) { col in
                            Text(Theme.emoji(forTile: result.tiles[row * GameBoard.size + col]))
                                .font(.system(size: 24))
                        }
                    }
                }
            }

            Text("全球同题 · 每日 00:00 UTC 刷新")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.background)
                .shadow(color: .black.opacity(0.15), radius: 18, y: 6)
        )
    }

    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Text(icon).font(.system(size: 13))
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.cellEmpty.opacity(0.5)))
    }
}

extension DayResult {
    /// 文本分享文案
    func shareText(streak: Int) -> String {
        let board = (0..<GameBoard.size).map { row in
            (0..<GameBoard.size)
                .map { Theme.emoji(forTile: tiles[row * GameBoard.size + $0]) }
                .joined()
        }
        .joined(separator: "\n")
        return """
        每日合合 · 第 \(day + 1) 天
        🎯 \(score) 分 · 最大 \(maxTile) · \(moves) 步 · 🔥\(streak) 连胜
        \(board)
        """
    }
}

#Preview {
    let sample = DayResult(day: 304, score: 4392, moves: 137, maxTile: 256,
                           tiles: [2, 4, 8, 16, 32, 64, 128, 256, 2, 4, 8, 0, 0, 0, 2, 4],
                           seconds: 612, date: Date())
    ResultCardView(displayDay: 305, result: sample, streak: 3)
        .padding()
        .background(Color.gray.opacity(0.2))
}
