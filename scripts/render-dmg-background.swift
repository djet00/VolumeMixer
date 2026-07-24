import AppKit

// Аргумент: масштаб (1 или 2)
let scale = CGFloat(Double(CommandLine.arguments.dropFirst().first ?? "1") ?? 1)
let W: CGFloat = 700 * scale
let H: CGFloat = 440 * scale

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Кремовый фон, как у дорогих установщиков
ctx.setFillColor(NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.94, alpha: 1).cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

// Заголовок: серифный шрифт, две строки, «перетащи» курсивом
let serif = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .largeTitle)
    .withDesign(.serif)!
let font = NSFont(descriptor: serif, size: 38 * scale)!
let italic = NSFont(descriptor: serif.withSymbolicTraits(.italic), size: 38 * scale) ?? font
let dark = NSColor(calibratedWhite: 0.08, alpha: 1)

let line1 = NSMutableAttributedString()
line1.append(NSAttributedString(string: "Чтобы установить, ", attributes: [.font: font, .foregroundColor: dark]))
line1.append(NSAttributedString(string: "перетащи", attributes: [.font: italic, .foregroundColor: dark]))
let line2 = NSAttributedString(string: "микшер в «Программы»", attributes: [.font: font, .foregroundColor: dark])

let s1 = line1.size(), s2 = line2.size()
line1.draw(at: NSPoint(x: (W - s1.width) / 2, y: H - 84 * scale))
line2.draw(at: NSPoint(x: (W - s2.width) / 2, y: H - 136 * scale))

// Фирменная стрелка-завиток между иконками (цвет из градиента иконки)
let purple = NSColor(calibratedRed: 0.45, green: 0.25, blue: 0.85, alpha: 1)
ctx.setStrokeColor(purple.cgColor)
ctx.setLineWidth(5 * scale)
ctx.setLineCap(.round)
let cy = 235 * scale   // вертикальный центр ряда иконок (от низа; 205 от верха)
let path = CGMutablePath()
path.move(to: CGPoint(x: 258 * scale, y: cy + 18 * scale))
path.addCurve(to: CGPoint(x: 345 * scale, y: cy - 8 * scale),
              control1: CGPoint(x: 288 * scale, y: cy - 24 * scale),
              control2: CGPoint(x: 322 * scale, y: cy - 26 * scale))
path.addCurve(to: CGPoint(x: 432 * scale, y: cy + 10 * scale),
              control1: CGPoint(x: 372 * scale, y: cy + 12 * scale),
              control2: CGPoint(x: 408 * scale, y: cy + 18 * scale))
ctx.addPath(path)
ctx.strokePath()
// наконечник
let tip = CGPoint(x: 432 * scale, y: cy + 10 * scale)
ctx.setFillColor(purple.cgColor)
let head = CGMutablePath()
head.move(to: CGPoint(x: tip.x + 12 * scale, y: tip.y + 2 * scale))
head.addLine(to: CGPoint(x: tip.x - 8 * scale, y: tip.y + 9 * scale))
head.addLine(to: CGPoint(x: tip.x - 1 * scale, y: tip.y - 11 * scale))
head.closeSubpath()
ctx.addPath(head)
ctx.fillPath()

// Подсказка про первый запуск — конкретные шаги, мелко внизу
let small = NSFont.systemFont(ofSize: 11 * scale)
let smallBold = NSFont.systemFont(ofSize: 11 * scale, weight: .semibold)
let gray = NSColor(calibratedWhite: 0.42, alpha: 1)
let steps: [(String, NSFont)] = [
    ("При первом запуске macOS скажет «разработчик не подтверждён» — это норма, разрешается один раз:", smallBold),
    ("Системные настройки → Конфиденциальность и безопасность → прокрутить вниз → «Всё равно открыть».", small),
]
// Рисуем СРАЗУ под иконками, а не у нижнего края: Finder может добавить
// тулбар и панель пути (~130px), которые обрезают низ фона. Всё важное
// должно жить в верхних ~330px, ниже — пустой запас под обрез.
for (i, step) in steps.enumerated() {
    let line = NSAttributedString(string: step.0, attributes: [.font: step.1, .foregroundColor: gray])
    let size = line.size()
    line.draw(at: NSPoint(x: (W - size.width) / 2, y: (144 - CGFloat(i) * 22) * scale))
}

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: scale > 1 ? "dmg-bg@2x.png" : "dmg-bg.png"))
print("ok \(Int(W))x\(Int(H))")
