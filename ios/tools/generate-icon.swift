// SPDX-License-Identifier: Apache-2.0
// SpeakerHop waveform connects two endpoints without depicting receiver hardware.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
guard let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Cannot create an opaque icon drawing context")
}
let background = CGColor(red: 0.035, green: 0.13, blue: 0.16, alpha: 1)
let teal = CGColor(red: 0.47, green: 0.94, blue: 0.79, alpha: 1)
let blue = CGColor(red: 0.42, green: 0.82, blue: 1, alpha: 1)
context.setFillColor(background)
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.setFillColor(CGColor(red: 0.12, green: 0.30, blue: 0.34, alpha: 1))
context.addPath(CGPath(roundedRect: CGRect(x: 135, y: 270, width: 754, height: 484), cornerWidth: 180, cornerHeight: 180, transform: nil))
context.fillPath()
let wave = CGMutablePath()
let points: [(Double, Double)] = [(240,512),(345,512),(385,405),(435,625),(485,335),(535,690),(585,415),(630,580),(675,512),(784,512)]
wave.move(to: CGPoint(x: points[0].0, y: points[0].1))
for p in points.dropFirst() { wave.addLine(to: CGPoint(x: p.0, y: p.1)) }
context.addPath(wave)
context.setLineWidth(34)
context.setLineCap(.round)
context.setLineJoin(.round)
context.setStrokeColor(teal)
context.strokePath()
for (x, color) in [(240.0, teal), (784.0, blue)] {
    context.setFillColor(color)
    context.fillEllipse(in: CGRect(x: x - 72, y: 440, width: 144, height: 144))
    context.setFillColor(background)
    context.fillEllipse(in: CGRect(x: x - 29, y: 483, width: 58, height: 58))
}
guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Cannot encode the icon")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write the icon") }
