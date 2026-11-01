import CoreHaptics

/// 触感反馈：基于 CoreHaptics 引擎。
/// 不用 UIFeedbackGenerator 的原因：AVAudioSession 处于激活状态（正在播音效）时，
/// 系统会抑制 UIFeedbackGenerator 的触感；CHHapticEngine 专为音频+触觉共存设计。
/// 模拟器/不支持设备上静默跳过。
enum Haptics {
    private static var engine: CHHapticEngine?
    private static var players: [String: any CHHapticPatternPlayer] = [:]

    static func prepare() {
        configureEngine()
    }

    private static func configureEngine() {
        guard engine == nil else { return }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let newEngine = try CHHapticEngine()
            newEngine.stoppedHandler = { _ in
                // 系统可能因资源回收停止引擎，下次触发时重新启动
            }
            try newEngine.start()
            engine = newEngine
        } catch {
            engine = nil
        }
    }

    private static func fire(_ key: String, intensity: Float, sharpness: Float) {
        configureEngine()
        guard let engine else { return }

        let player: any CHHapticPatternPlayer
        if let cached = players[key] {
            player = cached
        } else {
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ], relativeTime: 0)
            guard let pattern = try? CHHapticPattern(events: [event], parameters: []),
                  let created = try? engine.makePlayer(with: pattern) else { return }
            players[key] = created
            player = created
        }

        do {
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // 引擎偶发异常时静默跳过，不影响游戏
        }
    }

    /// 普通合并轻点一下，高档合并（≥128）更明显
    static func merge(maxValue: Int) {
        if maxValue >= 128 {
            fire("merge-big", intensity: 0.7, sharpness: 0.6)
        } else {
            fire("merge", intensity: 0.4, sharpness: 0.4)
        }
    }

    /// 达成 2048
    static func win() {
        fire("win", intensity: 1.0, sharpness: 0.3)
    }

    /// 终局结算
    static func gameOver() {
        fire("gameover", intensity: 0.6, sharpness: 0.2)
    }
}
