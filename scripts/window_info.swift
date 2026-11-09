// window_info: helper for take_screenshots_macos.sh.
//
//   window_info visible      -> "x y w h screenHeight": the main screen's visible
//                               frame (excludes menu bar and Dock), top-left origin,
//                               points, plus the full screen height
//   window_info window <pid> -> "<CGWindowID> x y w h" of that process's frontmost
//                               normal window, top-left origin, points
//   window_info flatten <png> -> rewrites the PNG on white without an alpha channel
//                               (App Store Connect rejects screenshots with alpha;
//                               a window capture has transparent rounded corners)
//
// Compiled with swiftc rather than run with `swift -e`: the interpreter doesn't
// inherit the terminal's Screen Recording grant, so it sees no other app's windows.
import AppKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let args = CommandLine.arguments
guard args.count >= 2 else { fail("usage: window_info visible | window <pid>") }

switch args[1] {
case "visible":
    guard let screen = NSScreen.main ?? NSScreen.screens.first else { fail("no screen") }
    let full = screen.frame, visible = screen.visibleFrame
    // AppKit is bottom-left origin; System Events and screencapture use top-left.
    let top = full.maxY - visible.maxY
    print(Int(visible.minX), Int(top), Int(visible.width), Int(visible.height), Int(full.height))
case "window":
    guard args.count >= 3, let pid = Int(args[2]) else { fail("usage: window_info window <pid>") }
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        fail("window list unavailable")
    }
    // Front-to-back order: the first layer-0 window of the process is its frontmost.
    for window in windows {
        guard window[kCGWindowOwnerPID as String] as? Int == pid,
              window[kCGWindowLayer as String] as? Int == 0,
              let number = window[kCGWindowNumber as String] as? Int,
              let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict),
              bounds.width > 200, bounds.height > 200 else { continue }
        print(number, Int(bounds.minX), Int(bounds.minY), Int(bounds.width), Int(bounds.height))
        exit(0)
    }
    fail("no window for pid \(pid)")
case "flatten":
    guard args.count >= 3 else { fail("usage: window_info flatten <png>") }
    let url = URL(fileURLWithPath: args[2])
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let context = CGContext(
              data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fail("can't read \(url.path)") }
    let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(rect)
    context.draw(image, in: rect)
    guard let flat = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fail("can't write \(url.path)")
    }
    CGImageDestinationAddImage(destination, flat, nil)
    guard CGImageDestinationFinalize(destination) else { fail("can't write \(url.path)") }
default:
    fail("unknown command \(args[1])")
}
