import AppKit

// Иконка приложения: три вертикальных слайдера в стиле SF slider.vertical.3
let px = 1024
let W = CGFloat(px), H = CGFloat(px)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Сквиркл с полями ~10%
let margin = W * 0.1
let r = CGRect(x: margin, y: margin, width: W - margin * 2, height: H - margin * 2)
let squircle = CGPath(roundedRect: r, cornerWidth: r.width * 0.225, cornerHeight: r.width * 0.225, transform: nil)
ctx.addPath(squircle)
ctx.clip()

// Градиент: глубокий синий → фиолетовый
let colors = [NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.85, alpha: 1).cgColor,
              NSColor(calibratedRed: 0.55, green: 0.20, blue: 0.85, alpha: 1).cgColor] as CFArray
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: r.minX, y: r.maxY), end: CGPoint(x: r.maxX, y: r.minY), options: [])

// Три слайдера: тонкая вертикальная линия + горизонтальная плашка-ползунок
let lineW = r.width * 0.038          // толщина линии
let lineH = r.height * 0.56          // высота линии
let knobW = r.width * 0.16           // ширина плашки
let knobH = lineW * 1.9              // толщина плашки
let xs: [CGFloat] = [0.29, 0.50, 0.71].map { r.minX + r.width * $0 }
let knobYs: [CGFloat] = [0.64, 0.40, 0.56].map { r.minY + r.height * $0 }
let top = r.midY + lineH / 2
let bottom = r.midY - lineH / 2

ctx.setFillColor(NSColor.white.cgColor)
for (x, ky) in zip(xs, knobYs) {
    // линия
    let line = CGRect(x: x - lineW / 2, y: bottom, width: lineW, height: top - bottom)
    ctx.addPath(CGPath(roundedRect: line, cornerWidth: lineW / 2, cornerHeight: lineW / 2, transform: nil))
    ctx.fillPath()
    // плашка-ползунок
    let knob = CGRect(x: x - knobW / 2, y: ky - knobH / 2, width: knobW, height: knobH)
    ctx.addPath(CGPath(roundedRect: knob, cornerWidth: knobH / 2, cornerHeight: knobH / 2, transform: nil))
    ctx.fillPath()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "icon2_1024.png"))
print("ok")
