// 合成游戏音效：swift scripts/make_sounds.swift <输出目录>
// 生成 move / merge / win / gameover 四个 wav（44.1kHz 单声道 16bit）
// 音色：柔和铃铛"叮"——基频 + 非谐波钟声泛音 + 指数余韵
import Foundation

let sampleRate = 44100.0
let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "MergeDaily/Sounds"

func writeWav(_ samples: [Double], _ name: String) {
    let pcm = samples.map { Int16(max(-1, min(1, $0)) * 32000) }
    var data = Data()
    func str(_ s: String) { data.append(contentsOf: s.utf8) }
    func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }

    str("RIFF"); u32(UInt32(36 + pcm.count * 2)); str("WAVE")
    str("fmt "); u32(16); u16(1); u16(1)
    u32(UInt32(sampleRate)); u32(UInt32(sampleRate) * 2); u16(2); u16(16)
    str("data"); u32(UInt32(pcm.count * 2))
    pcm.withUnsafeBytes { data.append(contentsOf: $0) }

    let url = URL(fileURLWithPath: outputDir).appendingPathComponent("\(name).wav")
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    try! data.write(to: url)
    print("生成 \(url.path) (\(String(format: "%.0f", Double(samples.count) / sampleRate * 1000))ms)")
}

func render(_ duration: Double, _ fill: (Double) -> Double) -> [Double] {
    let count = Int(duration * sampleRate)
    return (0..<count).map { i in fill(Double(i) / sampleRate) }
}

/// 铃铛单音：非谐波泛音模拟钟声，高次泛音衰减更快，3ms 起音防爆音
func bellTone(_ t: Double, freq: Double, decay: Double, amp: Double) -> Double {
    let partials: [(ratio: Double, amp: Double)] = [(1.0, 1.0), (2.76, 0.35), (5.40, 0.12)]
    var value = 0.0
    for partial in partials {
        value += sin(2 * .pi * freq * partial.ratio * t)
            * partial.amp * exp(-t * decay * partial.ratio)
    }
    let attack = min(1, t / 0.003)
    return value * attack * amp
}

// move：很轻很短的高音小铃“叮”
let moveSound = render(0.22) { t in
    bellTone(t, freq: 1174.7, decay: 22, amp: 0.13)
}

// merge：中音“叮—”，带余韵；播放速率随合并档位升高而变调
let mergeSound = render(0.45) { t in
    bellTone(t, freq: 783.99, decay: 9, amp: 0.32)
}

// win：C6-E6-G6-C7 上行琶音，清脆风铃感
let winSound: [Double] = {
    let notes: [(freq: Double, start: Double)] = [
        (1046.50, 0.00), (1318.51, 0.12), (1567.98, 0.24), (2093.00, 0.36)
    ]
    return render(0.85) { t in
        var value = 0.0
        for note in notes where t >= note.start {
            let local = t - note.start
            guard local < 0.6 else { continue }
            value += bellTone(local, freq: note.freq, decay: 8, amp: 0.28)
        }
        return value
    }
}()

// gameover：低两声“叮、叮”，柔和收尾
let gameoverSound: [Double] = {
    let notes: [(freq: Double, start: Double)] = [(523.25, 0.0), (392.00, 0.18)]
    return render(0.75) { t in
        var value = 0.0
        for note in notes where t >= note.start {
            let local = t - note.start
            guard local < 0.5 else { continue }
            value += bellTone(local, freq: note.freq, decay: 7, amp: 0.30)
        }
        return value
    }
}()

writeWav(moveSound, "move")
writeWav(mergeSound, "merge")
writeWav(winSound, "win")
writeWav(gameoverSound, "gameover")
