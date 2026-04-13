import SwiftUI

extension Image {
    /// Create a SwiftUI Image from raw photo data, cross-platform.
    init?(photoData: Data) {
#if os(iOS) || targetEnvironment(macCatalyst)
        guard let uiImage = UIImage(data: photoData) else { return nil }
        self.init(uiImage: uiImage)
#else
        guard let nsImage = NSImage(data: photoData) else { return nil }
        self.init(nsImage: nsImage)
#endif
    }
}

extension Data {
    func downsampledImage(maxDimension: CGFloat) -> Data {
#if os(iOS) || targetEnvironment(macCatalyst)
        guard let uiImage = UIImage(data: self) else { return self }
        let size = uiImage.size
        let scale = Swift.min(maxDimension / Swift.max(size.width, size.height), 1.0)
        guard scale < 1.0 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in uiImage.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.8) ?? self
#else
        guard let nsImage = NSImage(data: self) else { return self }
        let size = nsImage.size
        let scale = Swift.min(maxDimension / Swift.max(size.width, size.height), 1.0)
        guard scale < 1.0 else { return self }
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        nsImage.draw(in: NSRect(origin: .zero, size: newSize))
        resized.unlockFocus()
        guard let tiffData = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: 0.8)]) else {
            return self
        }
        return jpegData
#endif
    }
}
