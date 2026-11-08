import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import BarnHub

final class ImageProcessingTests: XCTestCase {

    // MARK: - Helpers

    private func makeImage(width: Int, height: Int) throws -> CGImage {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 0.3, green: 0.5, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width / 3, height: height / 3))
        return try XCTUnwrap(context.makeImage())
    }

    private func encode(_ image: CGImage, as type: UTType) throws -> Data {
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output as CFMutableData, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private struct Info {
        let width: Int
        let height: Int
        let type: String
    }

    private func info(of data: Data) throws -> Info {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try XCTUnwrap(props[kCGImagePropertyPixelWidth] as? Int)
        let height = try XCTUnwrap(props[kCGImagePropertyPixelHeight] as? Int)
        let type = try XCTUnwrap(CGImageSourceGetType(source) as String?)
        return Info(width: width, height: height, type: type)
    }

    // MARK: - Downsampling

    func test_largePNG_downsizesToMaxDimensionAsJPEG() throws {
        let png = try encode(makeImage(width: 4000, height: 3000), as: .png)

        let output = try XCTUnwrap(ImageProcessing.downsampledJPEG(from: png, maxPixelSize: ImageProcessing.documentMaxPixelSize))
        let result = try info(of: output)

        // Pixel size is exactly the cap — not cap × screen scale.
        XCTAssertEqual(max(result.width, result.height), 2048)
        XCTAssertEqual(result.width, 2048)
        XCTAssertEqual(result.height, 1536)
        XCTAssertEqual(result.type, UTType.jpeg.identifier)
        XCTAssertEqual(output.prefix(2), Data([0xFF, 0xD8]), "JPEG SOI marker")
    }

    func test_photoCap_is1024() throws {
        let png = try encode(makeImage(width: 3000, height: 4000), as: .png)
        let output = try XCTUnwrap(ImageProcessing.downsampledJPEG(from: png, maxPixelSize: ImageProcessing.photoMaxPixelSize))
        let result = try info(of: output)
        XCTAssertEqual(result.height, 1024)
        XCTAssertEqual(result.width, 768)
    }

    func test_smallImage_isNotUpscaled() throws {
        let png = try encode(makeImage(width: 300, height: 200), as: .png)
        let output = try XCTUnwrap(ImageProcessing.downsampledJPEG(from: png, maxPixelSize: 2048))
        let result = try info(of: output)
        XCTAssertEqual(result.width, 300)
        XCTAssertEqual(result.height, 200)
        XCTAssertEqual(result.type, UTType.jpeg.identifier)
    }

    func test_decodedImage_downsizesWithOrientationInMetadata() throws {
        let image = try makeImage(width: 4032, height: 3024)
        let output = try XCTUnwrap(ImageProcessing.downsampledJPEG(from: image, orientation: .right, maxPixelSize: 2048))
        let result = try info(of: output)
        XCTAssertEqual(max(result.width, result.height), 2048)
        XCTAssertEqual(result.type, UTType.jpeg.identifier)

        let source = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(props[kCGImagePropertyOrientation] as? UInt32, CGImagePropertyOrientation.right.rawValue)

        // Reading it back with the transform applied gives an upright (portrait) image.
        let upright = try XCTUnwrap(ImageProcessing.downsampledCGImage(from: output, maxPixelSize: 4096))
        XCTAssertGreaterThan(upright.height, upright.width)
    }

    func test_thumbnail_isAtMost256px() throws {
        let png = try encode(makeImage(width: 4000, height: 3000), as: .png)
        let photo = try XCTUnwrap(ImageProcessing.downsampledJPEG(from: png, maxPixelSize: ImageProcessing.photoMaxPixelSize))
        let thumbnail = try XCTUnwrap(ImageProcessing.thumbnailJPEG(from: photo))
        let result = try info(of: thumbnail)
        XCTAssertLessThanOrEqual(max(result.width, result.height), 256)
        XCTAssertEqual(max(result.width, result.height), 256)
        XCTAssertEqual(result.type, UTType.jpeg.identifier)
        XCTAssertLessThan(thumbnail.count, 100_000)
    }

    func test_processPhoto_returnsCappedPhotoAndThumbnail() async throws {
        let png = try encode(makeImage(width: 5000, height: 2500), as: .png)
        let processed = await ImageProcessing.processPhoto(from: png)
        let result = try XCTUnwrap(processed)
        XCTAssertEqual(try info(of: result.photo).width, 1024)
        XCTAssertEqual(try info(of: XCTUnwrap(result.thumbnail)).width, 256)
    }

    func test_invalidData_returnsNil() {
        XCTAssertNil(ImageProcessing.downsampledJPEG(from: Data("not an image".utf8), maxPixelSize: 1024))
    }

    func test_fileExtension_detectsFormat() throws {
        let image = try makeImage(width: 10, height: 10)
        XCTAssertEqual(ImageProcessing.fileExtension(forImageData: try encode(image, as: .png)), "png")
        XCTAssertEqual(ImageProcessing.fileExtension(forImageData: try encode(image, as: .jpeg)), "jpg")
        XCTAssertEqual(ImageProcessing.fileExtension(forImageData: nil), "jpg")
    }

    // MARK: - Import size cap

    private func makeSparseFile(size: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sparse-\(UUID().uuidString).pdf")
        XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: nil))
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(size))
        try handle.close()
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func test_checkSize_rejectsFileOver25MB() throws {
        let url = try makeSparseFile(size: DocumentImport.maxFileSize + 1)
        XCTAssertThrowsError(try DocumentImport.checkSize(of: url)) { error in
            guard case DocumentImport.ImportError.fileTooLarge(let bytes) = error else {
                return XCTFail("Expected fileTooLarge, got \(error)")
            }
            XCTAssertEqual(bytes, DocumentImport.maxFileSize + 1)
            XCTAssertFalse((error as? LocalizedError)?.errorDescription?.isEmpty ?? true)
        }
    }

    func test_checkSize_acceptsFileAtLimit() throws {
        let url = try makeSparseFile(size: DocumentImport.maxFileSize)
        XCTAssertNoThrow(try DocumentImport.checkSize(of: url))
    }

    func test_readFile_rejectsOversizeWithoutReading() async throws {
        let url = try makeSparseFile(size: 200 * 1024 * 1024)
        do {
            _ = try await DocumentImport.readFile(at: url)
            XCTFail("Expected fileTooLarge")
        } catch DocumentImport.ImportError.fileTooLarge {
            // expected
        }
    }

    func test_readFile_readsSmallFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("small-\(UUID().uuidString).pdf")
        try Data("%PDF-1.4".utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let data = try await DocumentImport.readFile(at: url)
        XCTAssertEqual(data, Data("%PDF-1.4".utf8))
    }

    // MARK: - Share temp files

    func test_sanitizedFileName_removesSeparatorsAndKeepsOneExtension() {
        XCTAssertEqual(ShareTempFiles.sanitizedFileName("Coggins 2026/05", fileExtension: "pdf"), "Coggins_2026-05.pdf")
        XCTAssertEqual(ShareTempFiles.sanitizedFileName("Invoice.pdf", fileExtension: "pdf"), "Invoice.pdf")
        XCTAssertEqual(ShareTempFiles.sanitizedFileName("../../etc", fileExtension: "jpg"), "etc.jpg")
        XCTAssertEqual(ShareTempFiles.sanitizedFileName("a:b*c?", fileExtension: "heic"), "a-b-c.heic")
        XCTAssertEqual(ShareTempFiles.sanitizedFileName("   ", fileExtension: "pdf"), "BarnHub.pdf")
    }

    func test_write_usesUniqueFolderPerShare() throws {
        let first = try ShareTempFiles.write(Data([1]), fileName: "Same", fileExtension: "pdf")
        let second = try ShareTempFiles.write(Data([2]), fileName: "Same", fileExtension: "pdf")
        defer { ShareTempFiles.cleanUp(first); ShareTempFiles.cleanUp(second) }

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first.lastPathComponent, "Same.pdf")
        XCTAssertEqual(try Data(contentsOf: first), Data([1]))
        XCTAssertEqual(try Data(contentsOf: second), Data([2]))

        #if !os(macOS)
        ShareTempFiles.cleanUp(first)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.deletingLastPathComponent().path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
        #endif
    }
}
