// SPDX-License-Identifier: Apache-2.0
// SpeakerHop waveform connects two endpoints without depicting receiver hardware.
import AppKit
let size = NSSize(width: 1024, height: 1024)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(srgbRed: 0.035, green: 0.13, blue: 0.16, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let teal = NSColor(srgbRed: 0.47, green: 0.94, blue: 0.79, alpha: 1)
let blue = NSColor(srgbRed: 0.42, green: 0.82, blue: 1, alpha: 1)
NSColor(srgbRed: 0.12, green: 0.30, blue: 0.34, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 135, y: 270, width: 754, height: 484), xRadius: 180, yRadius: 180).fill()
let wave = NSBezierPath()
let points: [(Double, Double)] = [(240,512),(345,512),(385,405),(435,625),(485,335),(535,690),(585,415),(630,580),(675,512),(784,512)]
wave.move(to: NSPoint(x: points[0].0, y: points[0].1))
for p in points.dropFirst() { wave.line(to: NSPoint(x: p.0, y: p.1)) }
wave.lineWidth = 34
wave.lineCapStyle = .round
wave.lineJoinStyle = .round
teal.setStroke()
wave.stroke()
for (x, color) in [(240.0, teal), (784.0, blue)] {
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: x - 72, y: 440, width: 144, height: 144)).fill()
    NSColor(srgbRed: 0.035, green: 0.13, blue: 0.16, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: x - 29, y: 483, width: 58, height: 58)).fill()
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
