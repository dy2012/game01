import SwiftUI

struct StatsView: View {
    @Bindable var viewModel: GameViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("战绩") {
                    row("当前连胜", "\(viewModel.stats.currentStreak) 天 🔥")
                    row("最长连胜", "\(viewModel.stats.maxStreak) 天")
                    row("已完成天数", "\(viewModel.stats.playedDays)")
                    row("每日最佳", "\(viewModel.stats.bestDailyScore) 分")
                    row("练习最佳", "\(viewModel.practiceBest) 分")
                }

                Section("近 7 天") {
                    let today = DailyClock.dayNumber()
                    ForEach(Array((today - 6)...today), id: \.self) { day in
                        if let result = viewModel.stats.results[day] {
                            HStack {
                                Text("第 \(day + 1) 天")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(result.score) 分")
                                    .font(.system(.body, design: .rounded).weight(.bold))
                                Text("最大 \(result.maxTile)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if day == today {
                            HStack {
                                Text("第 \(day + 1) 天").foregroundStyle(.secondary)
                                Spacer()
                                Text("进行中 / 未完成")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                Section {
                    Text("每日谜题按 UTC 日期生成，全球玩家同题；北京时间每天 08:00 刷新。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.system(.body, design: .rounded).weight(.semibold))
        }
    }
}

#Preview {
    StatsView(viewModel: GameViewModel(defaults: UserDefaults(suiteName: "preview")!))
}
