#!/usr/bin/env swift
// Original Lisa procedural icon adapted from generate_artwork.swift.
// Run: swift scripts/generate_message_icons.swift [project-root]
import AppKit
import ImageIO
import UniformTypeIdentifiers
let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
let catalog = URL(fileURLWithPath: root).appendingPathComponent("Stickers/Assets.xcassets")
let iconSet = catalog.appendingPathComponent("iMessage App Icon.stickersiconset")
try FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)
func render(width: Int, height: Int, output: URL) throws {
let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
NSGradient(starting: NSColor(calibratedRed:0.71,green:0.62,blue:0.95,alpha:1), ending:NSColor(calibratedRed:1,green:0.75,blue:0.88,alpha:1))!.draw(in:NSRect(x:0,y:0,width:width,height:height),angle:90)
// Keep mascot proportions and the complete original composition; extend only the background.
let scale = CGFloat(min(width, height)) / 1024
let transform = NSAffineTransform()
transform.translateX(by: (CGFloat(width) - 1024 * scale) / 2, yBy: (CGFloat(height) - 1024 * scale) / 2)
transform.scale(by: scale)
transform.concat()
let ink = NSColor(calibratedRed: 0.27, green: 0.12, blue: 0.37, alpha: 1)
let yellow = NSColor(calibratedRed: 1, green: 0.83, blue: 0.28, alpha: 1)
let berry = NSColor(calibratedRed: 0.79, green: 0.07, blue: 0.43, alpha: 1)
let pink = NSColor(calibratedRed: 1, green: 0.50, blue: 0.66, alpha: 1)

func rounded(_ rect: NSRect, _ radius: CGFloat, _ color: NSColor) {
 color.setFill(); NSBezierPath(roundedRect:rect,xRadius:radius,yRadius:radius).fill()
}
func oval(_ rect:NSRect, _ color:NSColor) {color.setFill(); NSBezierPath(ovalIn:rect).fill()}
// Puffy little cloud bank and a cast shadow keep the jelly grounded.
oval(NSRect(x:-70,y:20,width:520,height:200),.white.withAlphaComponent(0.24))
oval(NSRect(x:650,y:15,width:500,height:270),.white.withAlphaComponent(0.20))
oval(NSRect(x:217,y:94,width:595,height:88),ink.withAlphaComponent(0.15))
rounded(NSRect(x:254,y:127,width:202,height:103),52,berry)
rounded(NSRect(x:563,y:127,width:202,height:103),52,berry)
rounded(NSRect(x:275,y:175,width:104,height:22),12,pink)
rounded(NSRect(x:588,y:175,width:104,height:22),12,pink)
rounded(NSRect(x:86,y:388,width:135,height:112),55,yellow)
rounded(NSRect(x:803,y:425,width:135,height:112),55,yellow)
let body = NSBezierPath(roundedRect:NSRect(x:167,y:192,width:690,height:662),xRadius:224,yRadius:224)
rounded(NSRect(x:167,y:169,width:690,height:662),224,NSColor(calibratedRed:0.95,green:0.43,blue:0.16,alpha:1))
NSGradient(colors:[NSColor(calibratedRed:1,green:0.62,blue:0.18,alpha:1),yellow,NSColor(calibratedRed:1,green:0.95,blue:0.56,alpha:1)])!.draw(in:body,angle:90)
NSColor.white.withAlphaComponent(0.84).setStroke();body.lineWidth=12;body.stroke()
oval(NSRect(x:245,y:717,width:173,height:49),.white.withAlphaComponent(0.65))
// Three forehead tiles echo the sudoku grid.
for (i,x) in [431,498,565].enumerated() {rounded(NSRect(x:x,y:i == 1 ? 727 : 716,width:46,height:48),13,.white.withAlphaComponent(0.88))}
for x:CGFloat in [308,557] {
 oval(NSRect(x:x,y:447,width:153,height:190),.white)
 oval(NSRect(x:x+46,y:464,width:84,height:128),ink)
 oval(NSRect(x:x+54,y:536,width:30,height:35),.white)
 oval(NSRect(x:x+101,y:484,width:13,height:14),.white.withAlphaComponent(0.72))
}
oval(NSRect(x:252,y:416,width:108,height:51),pink.withAlphaComponent(0.85))
oval(NSRect(x:671,y:416,width:108,height:51),pink.withAlphaComponent(0.85))
let mouth=NSBezierPath();mouth.move(to:NSPoint(x:429,y:387));mouth.curve(to:NSPoint(x:595,y:387),controlPoint1:NSPoint(x:470,y:374),controlPoint2:NSPoint(x:551,y:374));mouth.curve(to:NSPoint(x:429,y:387),controlPoint1:NSPoint(x:598,y:265),controlPoint2:NSPoint(x:423,y:265));mouth.close();ink.setFill();mouth.fill()
NSGraphicsContext.saveGraphicsState();mouth.addClip();oval(NSRect(x:455,y:299,width:118,height:43),pink);NSGraphicsContext.restoreGraphicsState()
func sparkle(_ cx:CGFloat,_ cy:CGFloat,_ radius:CGFloat) {
 let star=NSBezierPath();star.move(to:NSPoint(x:cx,y:cy+radius));star.line(to:NSPoint(x:cx+radius*0.23,y:cy+radius*0.23));star.line(to:NSPoint(x:cx+radius,y:cy));star.line(to:NSPoint(x:cx+radius*0.23,y:cy-radius*0.23));star.line(to:NSPoint(x:cx,y:cy-radius));star.line(to:NSPoint(x:cx-radius*0.23,y:cy-radius*0.23));star.line(to:NSPoint(x:cx-radius,y:cy));star.line(to:NSPoint(x:cx-radius*0.23,y:cy+radius*0.23));star.close();NSColor.white.setFill();star.fill()
}
sparkle(856,830,72);sparkle(127,663,30);sparkle(736,914,22)

NSGraphicsContext.restoreGraphicsState()
let context = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
context.draw(bitmap.cgImage!,in:CGRect(x:0,y:0,width:width,height:height))
let destination = CGImageDestinationCreateWithURL(output as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(destination,context.makeImage()!,nil)
precondition(CGImageDestinationFinalize(destination),"Failed to write message icon")
}
let slots: [(String, Int, Int)] = [
    ("messages-iphone-58x58.png", 58, 58),
    ("messages-iphone-87x87.png", 87, 87),
    ("messages-iphone-120x90.png", 120, 90),
    ("messages-iphone-180x135.png", 180, 135),
    ("messages-ipad-58x58.png", 58, 58),
    ("messages-ipad-134x100.png", 134, 100),
    ("messages-ipad-148x110.png", 148, 110),
    ("messages-universal-54x40.png", 54, 40),
    ("messages-universal-81x60.png", 81, 60),
    ("messages-universal-64x48.png", 64, 48),
    ("messages-universal-96x72.png", 96, 72),
    ("messages-ios-marketing-1024x768.png", 1024, 768),
]
for (name, width, height) in slots { try render(width:width,height:height,output:iconSet.appendingPathComponent(name)) }
print("Generated \(slots.count) opaque iMessage icon slots")
