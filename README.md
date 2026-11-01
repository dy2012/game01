# 每日合合（MergeDaily）

类 Wordle 的每日 2048 挑战 iOS App：**全球同题、一天一局、比分数、连胜打卡、战绩分享**。

| 项 | 值 |
| --- | --- |
| 中文名（Display Name） | 每日合合 |
| 英文名（Product Name） | MergeDaily |
| Bundle ID | com.dy2012.mergehehe |

## 玩法

- **每日挑战**：初始盘面和之后出现的每个新方块都由当天日期（UTC）种子确定，全世界玩家拿到完全相同的题目；走完（或放弃）即结算，一天一局。
- **自由练习**：随机种子无限畅玩，成绩单独统计。
- 滑动合并方块，出现 2048 后可继续冲击更高分。
- 完成后可生成战绩图 / 文案分享，附带连胜 streak 与终局盘面的 emoji 缩略。

## 技术要点

| 模块 | 说明 |
| --- | --- |
| 确定性引擎 | `DailyPuzzle` 用 SplitMix64 以 (seed, spawnIndex) 派生每个新方块，重放只依赖日期与走法，无需服务器 |
| 断点续玩 | 每步自动存档到 UserDefaults，重开 App 从中断处继续 |
| 战绩 | 每日结果 + 连胜 streak 本地持久化，`recentResults` 生成近 7 天视图 |
| UI | SwiftUI，iOS 18+，棋盘动画、分享卡 `ImageRenderer` 渲染 |

## 构建与测试

项目文件由 [xcodegen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成（仓库已包含生成好的 `MergeDaily.xcodeproj`，直接用 Xcode 打开即可）。改动 `project.yml` 后执行 `xcodegen generate` 重新生成。

```bash
# 生成 App 图标（可选，仓库已包含生成结果）
swift scripts/make_icon.swift MergeDaily/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png

# 编译（需 Xcode 26+；目标模拟器名按本机实际修改）
xcodebuild -project MergeDaily.xcodeproj -scheme MergeDaily \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 单元测试
xcodebuild -project MergeDaily.xcodeproj -scheme MergeDaily \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## 目录

```
MergeDaily/
├── MergeDailyApp.swift      # 入口
├── GameViewModel.swift      # 状态管理（每日/练习双棋盘）
├── Models/
│   ├── GameBoard.swift      # 4x4 棋盘与合并算法
│   ├── DailyPuzzle.swift    # 每日种子与确定性方块序列
│   └── StatsStore.swift     # 战绩持久化与 streak
└── Views/
    ├── ContentView.swift    # 主界面
    ├── BoardView.swift      # 棋盘与手势
    ├── ResultCardView.swift # 分享战绩卡
    ├── StatsView.swift      # 统计页
    └── Theme.swift          # 配色
MergeDailyTests/             # 引擎与战绩单元测试
```
