#!/usr/bin/env swift
// Run from the project root: swift scripts/generate_artwork.swift [project-root] [--icon-only]
// Native, original vector artwork; no downloaded assets or dependencies.
import AppKit
import ImageIO
import UniformTypeIdentifiers
let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
try FileManager.default.createDirectory(atPath: root + "/App/Assets.xcassets/AppIcon.appiconset", withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: root + "/Stickers/Resources", withIntermediateDirectories: true)
do {
let side = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:side,pixelsHigh:side,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
let ink = NSColor(calibratedRed: 0.27, green: 0.12, blue: 0.37, alpha: 1)
let yellow = NSColor(calibratedRed: 1, green: 0.83, blue: 0.28, alpha: 1)
let berry = NSColor(calibratedRed: 0.79, green: 0.07, blue: 0.43, alpha: 1)
let pink = NSColor(calibratedRed: 1, green: 0.50, blue: 0.66, alpha: 1)
NSGradient(starting: NSColor(calibratedRed:0.71,green:0.62,blue:0.95,alpha:1), ending:NSColor(calibratedRed:1,green:0.75,blue:0.88,alpha:1))!.draw(in:NSRect(x:0,y:0,width:side,height:side),angle:90)
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
// Draw into a Core Graphics opaque RGB context. Three-channel AppKit bitmap
// contexts may fail to render; skip-alpha RGBA storage has a supported layout.
let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                        bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.draw(bitmap.cgImage!, in: CGRect(x: 0, y: 0, width: side, height: side))
let url = URL(fileURLWithPath: root + "/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination), "Failed to write app icon")
}
if !CommandLine.arguments.contains("--icon-only") {
let output = root + "/Stickers/Resources"
let ink = NSColor(calibratedRed:0.19,green:0.20,blue:0.25,alpha:1)
let coral = NSColor(calibratedRed:0.99,green:0.44,blue:0.34,alpha:1)
let yellow = NSColor(calibratedRed:1,green:0.84,blue:0.43,alpha:1)
let lavender = NSColor(calibratedRed:0.82,green:0.79,blue:0.96,alpha:1)
let mint = NSColor(calibratedRed:0.77,green:0.88,blue:0.79,alpha:1)
func rounded(_ r:NSRect,_ radius:CGFloat,_ color:NSColor) {color.setFill();NSBezierPath(roundedRect:r,xRadius:radius,yRadius:radius).fill()}
for (index, name) in ["lisa-smile","lisa-heart","lisa-bravo","lisa-zen"].enumerated() {
 let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:300,pixelsHigh:300,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
 NSColor.clear.setFill(); NSRect(x:0,y:0,width:300,height:300).fill(using:.copy)
 rounded(NSRect(x:45,y:58,width:210,height:216),54,.white)
 rounded(NSRect(x:52,y:65,width:196,height:202),48,[yellow,coral,lavender,mint][index])
 if index == 3 {
   for x:CGFloat in [105,173] {let p=NSBezierPath();p.move(to:NSPoint(x:x,y:172));p.curve(to:NSPoint(x:x+22,y:172),controlPoint1:NSPoint(x:x+5,y:157),controlPoint2:NSPoint(x:x+17,y:157));p.lineWidth=6;p.lineCapStyle = .round;ink.setStroke();p.stroke()}
 } else {
   for x in [110,178] {rounded(NSRect(x:x,y:159,width:12,height:24),6,ink)}
 }
 let p=NSBezierPath();p.move(to:NSPoint(x:128,y:139));p.curve(to:NSPoint(x:172,y:139),controlPoint1:NSPoint(x:137,y:120),controlPoint2:NSPoint(x:163,y:120));p.lineWidth=6;p.lineCapStyle = .round;ink.setStroke();p.stroke()
 NSColor.white.withAlphaComponent(0.55).setFill();for x in [80,200] {NSBezierPath(ovalIn:NSRect(x:x,y:143,width:22,height:12)).fill()}
 if index == 1 {
   let heart=NSBezierPath();heart.move(to:NSPoint(x:150,y:204));heart.curve(to:NSPoint(x:128,y:231),controlPoint1:NSPoint(x:139,y:216),controlPoint2:NSPoint(x:122,y:218));heart.curve(to:NSPoint(x:150,y:232),controlPoint1:NSPoint(x:133,y:246),controlPoint2:NSPoint(x:145,y:244));heart.curve(to:NSPoint(x:172,y:231),controlPoint1:NSPoint(x:157,y:244),controlPoint2:NSPoint(x:167,y:246));heart.curve(to:NSPoint(x:150,y:204),controlPoint1:NSPoint(x:180,y:218),controlPoint2:NSPoint(x:161,y:216));heart.close();NSColor.white.setFill();heart.fill()
 } else {
   for x in [118,143,168] {rounded(NSRect(x:x,y:216,width:16,height:16),4,.white.withAlphaComponent(0.75))}
 }
 rounded(NSRect(x:37,y:18,width:226,height:58),25,.white)
 let titles=["ON JOUE ?","CŒUR SUR TOI","BRAVO !","PAUSE ZEN"]
 let paragraph=NSMutableParagraphStyle();paragraph.alignment = .center
 let font=NSFont.systemFont(ofSize:23,weight:.heavy)
 (titles[index] as NSString).draw(in:NSRect(x:35,y:31,width:230,height:31),withAttributes:[.font:font,.foregroundColor:ink,.paragraphStyle:paragraph])
 if index == 2 {for (x,y):(CGFloat,CGFloat) in [(28,240),(264,232),(30,152),(266,145)] {let star=NSBezierPath();star.move(to:NSPoint(x:x,y:y+14));star.line(to:NSPoint(x:x+4,y:y+4));star.line(to:NSPoint(x:x+14,y:y));star.line(to:NSPoint(x:x+4,y:y-4));star.line(to:NSPoint(x:x,y:y-14));star.line(to:NSPoint(x:x-4,y:y-4));star.line(to:NSPoint(x:x-14,y:y));star.line(to:NSPoint(x:x-4,y:y+4));star.close();coral.setFill();star.fill()}}
 NSGraphicsContext.restoreGraphicsState()
 try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output+"/"+name+".png"))
}
}
