// 生成 1024x1024 App 图标：swift scripts/make_icon.swift <输出路径>
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon1024.png"

guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("无法创建画布")
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// 背景暖色渐变
let gradient = CGGradient(colorsSpace: nil, colors: [
    CGColor(red: 0.980, green: 0.973, blue: 0.937, alpha: 1),
    CGColor(red: 0.949, green: 0.839, blue: 0.596, alpha: 1),
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])

// 棋盘
ctx.setFillColor(CGColor(red: 0.733, green: 0.678, blue: 0.627, alpha: 1))
ctx.addPath(rounded(CGRect(x: 122, y: 122, width: 780, height: 780), 72))
ctx.fillPath()

// 四个空格底
ctx.setFillColor(CGColor(red: 0.804, green: 0.757, blue: 0.706, alpha: 1))
for position in [(172.0, 172.0), (532.0, 172.0), (172.0, 532.0), (532.0, 532.0)] {
    ctx.addPath(rounded(CGRect(x: position.0, y: position.1, width: 320, height: 320), 36))
    ctx.fillPath()
}

func drawTile(_ rect: CGRect, fill: CGColor, label: String, fontSize: CGFloat, textColor: CGColor) {
    ctx.addPath(rounded(rect, 36))
    ctx.setFillColor(fill)
    ctx.fillPath()

    let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): textColor,
    ]
    let attributed = NSAttributedString(string: label, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributed)
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    var leading: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
    ctx.textPosition = CGPoint(x: rect.midX - width / 2,
                               y: rect.midY - (ascent + descent) / 2 + descent)
    CTLineDraw(line, ctx)
}

// 左下：方块 2
drawTile(CGRect(x: 172, y: 172, width: 320, height: 320),
         fill: CGColor(red: 0.933, green: 0.894, blue: 0.855, alpha: 1),
         label: "2", fontSize: 200,
         textColor: CGColor(red: 0.467, green: 0.431, blue: 0.396, alpha: 1))
// 右上：方块 2048
drawTile(CGRect(x: 532, y: 532, width: 320, height: 320),
         fill: CGColor(red: 0.929, green: 0.761, blue: 0.180, alpha: 1),
         label: "2048", fontSize: 96,
         textColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1))

guard let image = ctx.makeImage() else { fatalError("渲染失败") }
let url = URL(fileURLWithPath: output) as CFURL
guard let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("无法创建输出文件")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("写入失败") }
print("图标已生成: \(output)")
