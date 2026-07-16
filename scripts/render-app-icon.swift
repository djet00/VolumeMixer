import AppKit

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Сквиркл с полями ~10% (как у нативных иконок macOS)
let margin = size * 0.1
let rect = CGRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
let path = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil)
ctx.addPath(path)
ctx.clip()

// Градиент фона: глубокий синий → фиолетовый
let colors = [NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.85, alpha: 1).cgColor,
              NSColor(calibratedRed: 0.55, green: 0.20, blue: 0.85, alpha: 1).cgColor] as CFArray
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])

// Три вертикальных ползунка
let trackW = rect.width * 0.055
let trackH = rect.height * 0.52
let knobR = rect.width * 0.075
let xs: [CGFloat] = [0.30, 0.50, 0.70].map { rect.minX + rect.width * $0 }
let knobYs: [CGFloat] = [0.62, 0.38, 0.55].map { rect.minY + rect.height * $0 }
let trackY = rect.midY - trackH / 2

ctx.setFillColor(NSColor.white.withAlphaComponent(0.35).cgColor)
for x in xs {
    let track = CGRect(x: x - trackW / 2, y: trackY, width: trackW, height: trackH)
    ctx.addPath(CGPath(roundedRect: track, cornerWidth: trackW / 2, cornerHeight: trackW / 2, transform: nil))
    ctx.fillPath()
}
ctx.setFillColor(NSColor.white.cgColor)
for (x, y) in zip(xs, knobYs) {
    ctx.fillEllipse(in: CGRect(x: x - knobR, y: y - knobR, width: knobR * 2, height: knobR * 2))
}
img.unlockFocus()

let tiff = img.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "icon_1024.png"))
print("ok")
