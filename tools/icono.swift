// Genera el ícono de JenBar (concepto C: «J de progreso») como PNG de 1024 px.
// Uso: swift tools/icono.swift salida.png
import AppKit

let lado: CGFloat = 1024
let s = lado / 160                       // el boceto original mide 160 × 160
func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: y * s) }

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(lado), pixelsHigh: Int(lado), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
// Coordenadas con origen arriba a la izquierda, como el boceto.
ctx.cgContext.translateBy(x: 0, y: lado)
ctx.cgContext.scaleBy(x: 1, y: -1)

// Fondo: cuadrado redondeado con el margen de los íconos de macOS (100 px a 1024).
let m: CGFloat = 100
NSColor(srgbRed: 0.09, green: 0.09, blue: 0.10, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: m, y: m, width: lado - 2 * m, height: lado - 2 * m),
             xRadius: 185, yRadius: 185).fill()

// El boceto se reduce para entrar en el área útil y se centra.
let k = (lado - 2 * m) / lado
ctx.cgContext.translateBy(x: lado / 2, y: lado / 2)
ctx.cgContext.scaleBy(x: k, y: k)
ctx.cgContext.translateBy(x: -lado / 2, y: -lado / 2 + 3 * s)

func trazo(_ color: NSColor, _ hasta: CGFloat) {
    let b = NSBezierPath()
    b.move(to: p(104, 32))
    b.line(to: p(104, 98))
    // Curva de la J: de 0° (derecha) hacia abajo y a la izquierda; en coordenadas invertidas va en sentido horario.
    b.appendArc(withCenter: p(80, 98), radius: 24 * s, startAngle: 0, endAngle: hasta, clockwise: false)
    b.lineWidth = 14 * s
    b.lineCapStyle = .round
    color.setStroke()
    b.stroke()
}
trazo(NSColor(srgbRed: 0.23, green: 0.23, blue: 0.25, alpha: 1), 180)   // total
trazo(NSColor(srgbRed: 0.13, green: 0.77, blue: 0.37, alpha: 1), 90)    // restante
NSColor(srgbRed: 0.96, green: 0.62, blue: 0.04, alpha: 1).setFill()     // punto: consumo
NSBezierPath(ovalIn: NSRect(x: (56 - 7) * s, y: (98 - 7) * s, width: 14 * s, height: 14 * s)).fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
