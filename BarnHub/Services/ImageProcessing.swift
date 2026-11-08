import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Downsamples and re-encodes photos with ImageIO, so a 48 MP picture never
/// has to be decoded at full size and the same code runs on iOS, Mac Catalyst
/// and native macOS. Everything here is synchronous and thread-safe: call the
/// `async` variants from views so the work happens off the main actor.
enum ImageProcessing {
    /// Horse and feed product photos.
    static let photoMaxPixelSize = 1024
    /// Photographed or picked documents (Coggins, papers): enough to read print.
    static let documentMaxPixelSize = 2048
    /// Inline thumbnails used by rows, the sidebar and avatars.
    static let thumbnailMaxPixelSize = 256
    static let jpegQuality: CGFloat = 0.8

    // MARK: - Downsampling

    /// Decodes `data` at no more than `maxPixelSize` on its longest side, with the
    /// EXIF orientation applied. Never upscales.
    static func downsampledCGImage(from data: Data, maxPixelSize: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Re-encodes any ImageIO-readable image (HEIC, PNG, JPEG, RAW…) as a JPEG no
    /// larger than `maxPixelSize`, upright, at scale 1.
    static func downsampledJPEG(from data: Data, maxPixelSize: Int) -> Data? {
        guard let image = downsampledCGImage(from: data, maxPixelSize: maxPixelSize) else { return nil }
        return jpegData(from: image)
    }

    /// Scales an already-decoded image (the camera hands us one) to fit
    /// `maxPixelSize` and encodes it once as JPEG. `orientation` is written to
    /// the file's metadata rather than baked into the pixels.
    static func downsampledJPEG(
        from image: CGImage,
        orientation: CGImagePropertyOrientation = .up,
        maxPixelSize: Int
    ) -> Data? {
        guard let scaled = scaled(image, maxPixelSize: maxPixelSize) else { return nil }
        return jpegData(from: scaled, orientation: orientation)
    }

    static func thumbnailJPEG(from data: Data) -> Data? {
        downsampledJPEG(from: data, maxPixelSize: thumbnailMaxPixelSize)
    }

    static func jpegData(from image: CGImage, orientation: CGImagePropertyOrientation = .up) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: jpegQuality,
            kCGImagePropertyOrientation: orientation.rawValue
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    private static func scaled(_ image: CGImage, maxPixelSize: Int) -> CGImage? {
        let longest = max(image.width, image.height)
        guard longest > maxPixelSize, longest > 0 else { return image }
        let factor = CGFloat(maxPixelSize) / CGFloat(longest)
        let width = max(1, Int((CGFloat(image.width) * factor).rounded()))
        let height = max(1, Int((CGFloat(image.height) * factor).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// The file extension for the image format in `data`, e.g. "heic" or "png";
    /// "jpg" when it can't be told.
    static func fileExtension(forImageData data: Data?) -> String {
        guard let data,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let typeID = CGImageSourceGetType(source) as String?,
              let type = UTType(typeID) else { return "jpg" }
        if type.conforms(to: .jpeg) { return "jpg" }
        return type.preferredFilenameExtension ?? "jpg"
    }

    // MARK: - Off-main entry points

    static func downsampledJPEGInBackground(from data: Data, maxPixelSize: Int) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            downsampledJPEG(from: data, maxPixelSize: maxPixelSize)
        }.value
    }

    static func downsampledJPEGInBackground(
        from image: CGImage,
        orientation: CGImagePropertyOrientation,
        maxPixelSize: Int
    ) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            downsampledJPEG(from: image, orientation: orientation, maxPixelSize: maxPixelSize)
        }.value
    }

    /// A photo for a horse or feed product, plus its inline thumbnail.
    struct ProcessedPhoto {
        let photo: Data
        let thumbnail: Data?
    }

    static func processPhoto(from data: Data) async -> ProcessedPhoto? {
        await Task.detached(priority: .userInitiated) {
            guard let photo = downsampledJPEG(from: data, maxPixelSize: photoMaxPixelSize) else { return nil }
            return ProcessedPhoto(photo: photo, thumbnail: thumbnailJPEG(from: photo))
        }.value
    }

    static func processPhoto(from image: CGImage, orientation: CGImagePropertyOrientation) async -> ProcessedPhoto? {
        await Task.detached(priority: .userInitiated) {
            guard let photo = downsampledJPEG(from: image, orientation: orientation, maxPixelSize: photoMaxPixelSize) else { return nil }
            return ProcessedPhoto(photo: photo, thumbnail: thumbnailJPEG(from: photo))
        }.value
    }

    static func thumbnailJPEGInBackground(from data: Data) async -> Data? {
        await Task.detached(priority: .utility) { thumbnailJPEG(from: data) }.value
    }
}

// MARK: - Document import

enum DocumentImport {
    /// Largest file accepted from the Files picker. Bigger scans stall the UI and
    /// the CloudKit export of the asset.
    static let maxFileSize = 25_000_000  // decimal MB, so the message reads "25 MB"

    enum ImportError: LocalizedError {
        case fileTooLarge(bytes: Int)
        case unreadable(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .fileTooLarge(let bytes):
                let size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
                let limit = ByteCountFormatter.string(fromByteCount: Int64(DocumentImport.maxFileSize), countStyle: .file)
                return appLocalized("This file is \(size). Files up to \(limit) can be imported.", comment: "Document import error: the picked file is over the size limit. First value is the file size, second the limit, e.g. 30 MB / 25 MB")
            case .unreadable(let underlying):
                return appLocalized("Could not open file: \(underlying.localizedDescription)", comment: "File open error")
            }
        }
    }

    /// Throws `fileTooLarge` without reading the file when it's over the cap.
    static func checkSize(of url: URL) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let size = values.fileSize, size > maxFileSize {
            throw ImportError.fileTooLarge(bytes: size)
        }
    }

    /// Size-checks and reads a file picked with `fileImporter`, off the main actor.
    static func readFile(at url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            // Picker URLs are security scoped on iOS; on macOS they may not be, so
            // try the read either way and let it report a real error.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                try checkSize(of: url)
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                // The size from resource values can be missing (e.g. a file
                // provider); check what was actually read too.
                guard data.count <= maxFileSize else { throw ImportError.fileTooLarge(bytes: data.count) }
                return data
            } catch let error as ImportError {
                throw error
            } catch {
                throw ImportError.unreadable(underlying: error)
            }
        }.value
    }
}
