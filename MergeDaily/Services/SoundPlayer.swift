import AVFoundation

/// 短音效播放：ambient 类别（尊重静音键），预加载零延迟。
enum SoundPlayer {
    enum Effect: String, CaseIterable {
        case move      // 每步滑动
        case merge     // 合并
        case win       // 达成 2048
        case gameover  // 终局
    }

    static let enabledKey = "sound.enabled"

    private static var players: [Effect: AVAudioPlayer] = [:]
    private static var configured = false

    static var isEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: enabledKey) == nil
                ? true
                : UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
        }
    }

    static func configure() {
        guard !configured else { return }
        configured = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for effect in Effect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[effect] = player
        }
    }

    /// rate 可做音调变化（合并档位越高音调越高）
    static func play(_ effect: Effect, rate: Float = 1) {
        configure()
        guard isEnabled, let player = players[effect] else { return }
        player.rate = max(0.5, min(2, rate))
        player.currentTime = 0
        player.play()
    }

    /// 合并音调：数值每翻一档音调微升，变化保持含蓄
    static func mergeRate(for value: Int) -> Float {
        let tier = max(0, log2(Double(max(4, value))) - 3)   // 8 → 0 档
        return Float(0.95 + min(0.3, tier * 0.04))
    }
}
