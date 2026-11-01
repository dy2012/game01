import SwiftUI
import UIKit

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @State private var showStats = false
    @State private var showGiveUpDialog = false
    @State private var copiedTip = false

    var body: some View {
        // 游戏是单屏应用，用固定布局而非 ScrollView，
        // 避免棋盘滑动与页面滚动手势冲突
        VStack(spacing: 14) {
            header
            scoreRow
            modePicker
            boardSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)   // 空间不足时优先保证棋盘，状态区可被压缩
            statusSection
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        // 经典 2048 米色牌面属于浅色体系，锁定浅色避免 sheet/alert 跟随系统深色造成割裂
        .preferredColorScheme(.light)
        .sheet(isPresented: $showStats) {
            StatsView(viewModel: viewModel)
        }
        .alert("🎉 达成 2048！", isPresented: Binding(
            get: { viewModel.showWin },
            set: { if !$0 { viewModel.dismissWin() } }
        )) {
            Button("继续冲击更高分") { viewModel.dismissWin() }
        } message: {
            Text("今日棋盘已经出现 2048，继续合并可以拿更高分。")
        }
        .task {
            // 触感引擎预热放到首帧之后，不阻塞冷启动
            Haptics.prepare()
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("每日合合")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("第 \(viewModel.displayDay) 天 · 🔥\(viewModel.currentStreak) 连胜")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.text.opacity(0.7))
            }
            Spacer()
            HStack(spacing: 14) {
                Button {
                    viewModel.soundEnabled.toggle()
                } label: {
                    Image(systemName: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.text)
                }
                Button {
                    showStats = true
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.text)
                }
            }
        }
    }

    // MARK: - 分数

    private var scoreRow: some View {
        HStack(spacing: 10) {
            scoreBox(title: "得分", value: viewModel.displayScore)
            scoreBox(title: viewModel.mode == .daily ? "每日最佳" : "练习最佳",
                     value: viewModel.mode == .daily ? viewModel.stats.bestDailyScore : viewModel.practiceBest)
        }
    }

    private func scoreBox(title: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.text.opacity(0.7))
            Text("\(value)")
                .font(.system(.title2, design: .rounded).weight(.black))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.9), value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.board.opacity(0.25)))
    }

    // MARK: - 模式切换

    private var modePicker: some View {
        Picker("模式", selection: Binding(
            get: { viewModel.mode },
            set: { viewModel.switchMode(to: $0) }
        )) {
            ForEach(GameMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .tint(Theme.accentOrange)
    }

    // MARK: - 棋盘

    private var boardSection: some View {
        BoardView(tiles: viewModel.displayTiles,
                  nudge: viewModel.nudge) { direction in
            viewModel.move(direction)
        }
        .overlay {
            if viewModel.isFinished {
                finishedOverlay
            }
        }
    }

    private var finishedOverlay: some View {
        ZStack {
            Rectangle()
                .fill(Theme.background.opacity(0.72))
                .ignoresSafeArea()
            VStack(spacing: 10) {
                Text(viewModel.mode == .daily ? "今日已结算" : "本局结束")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Text("\(viewModel.board.score) 分")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accentOrange)
                if viewModel.mode == .practice {
                    Button("再来一局") {
                        withAnimation { viewModel.restartPractice() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accentOrange)
                }
            }
        }
        .allowsHitTesting(viewModel.mode == .practice)
        .transition(.opacity)
    }

    // MARK: - 底部状态

    @ViewBuilder
    private var statusSection: some View {
        switch viewModel.mode {
        case .daily:
            if viewModel.isFinished {
                dailyResultSection
            } else {
                VStack(spacing: 12) {
                    Text("全球同题 · 一步一策 · 结束即结算，一天一局")
                        .font(.footnote)
                        .foregroundStyle(Theme.text.opacity(0.7))
                    Button(role: .destructive) {
                        showGiveUpDialog = true
                    } label: {
                        Text("放弃并结算")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
                .confirmationDialog("确定放弃今日挑战？将按当前分数结算。",
                                    isPresented: $showGiveUpDialog, titleVisibility: .visible) {
                    Button("放弃并结算", role: .destructive) {
                        withAnimation { viewModel.giveUpDaily() }
                    }
                    Button("继续挑战", role: .cancel) {}
                }
            }
        case .practice:
            Text("练习不占用每日挑战次数，随时重开")
                .font(.footnote)
                .foregroundStyle(Theme.text.opacity(0.7))
        }
    }

    @ViewBuilder
    private var dailyResultSection: some View {
        if let result = viewModel.todayResult {
            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    statChip("最大方块", "\(result.maxTile)")
                    statChip("步数", "\(result.moves)")
                    statChip("用时", formatDuration(result.seconds))
                }
                shareButtons(result: result)
                CountdownView()
            }
        }
    }

    private func statChip(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.text)
        }
    }

    private func shareButtons(result: DayResult) -> some View {
        ShareCardController(result: result, streak: viewModel.currentStreak, copiedTip: $copiedTip)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return m >= 60 ? String(format: "%d:%02d:%02d", m / 60, m % 60, s) : String(format: "%d:%02d", m, s)
    }
}

// MARK: - 分享区（图片 + 文案）

private struct ShareCardController: View {
    let result: DayResult
    let streak: Int
    @Binding var copiedTip: Bool

    @State private var shareImage: Image?

    var body: some View {
        VStack(spacing: 10) {
            if let shareImage {
                ShareLink(item: shareImage, preview: SharePreview("每日合合 第\(result.day + 1)天", image: shareImage)) {
                    shareLabel("分享战绩图", systemImage: "square.and.arrow.up.fill")
                }
            }
            ShareLink(item: result.shareText(streak: streak), subject: Text("每日合合"), message: nil) {
                shareLabel("分享文案", systemImage: "text.quote")
            }
            Button {
                UIPasteboard.general.string = result.shareText(streak: streak)
                withAnimation { copiedTip = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation { copiedTip = false }
                }
            } label: {
                shareLabel(copiedTip ? "已复制 ✓" : "复制文案", systemImage: "doc.on.doc")
            }
            .buttonStyle(.plain)
        }
        .task {
            let renderer = ImageRenderer(content: ResultCardView(displayDay: result.day + 1,
                                                                 result: result,
                                                                 streak: streak))
            renderer.scale = 2
            shareImage = renderer.uiImage.map { Image(uiImage: $0) }
        }
    }

    private func shareLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title).font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(Theme.board.opacity(0.3)))
    }
}

// MARK: - 倒计时

struct CountdownView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, DailyClock.nextPuzzleDate().timeIntervalSince(context.date))
            Text("距下一题 \(format(remaining))")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}

#Preview {
    ContentView()
}
