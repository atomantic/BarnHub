import SwiftUI
import SwiftData
import CoreGraphics

/// Shows image data decoded off the main actor at no more than `maxPixelSize`,
/// through a shared in-memory cache, so list rows and avatars don't re-decode a
/// photo on every render. Shows `placeholder` while decoding or when there's no
/// image.
struct CachedPhotoView<Content: View, Placeholder: View>: View {
    let data: Data?
    let maxPixelSize: Int
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var decoded: DecodedImage?

    init(
        data: Data?,
        maxPixelSize: Int = ImageProcessing.thumbnailMaxPixelSize,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.data = data
        self.maxPixelSize = maxPixelSize
        self.content = content
        self.placeholder = placeholder
    }

    private var cacheKey: String? {
        data.map { PhotoDecodeCache.key(for: $0, maxPixelSize: maxPixelSize) }
    }

    var body: some View {
        let key = cacheKey
        let image = key.flatMap { k in decoded?.key == k ? decoded?.image : PhotoDecodeCache.shared.image(forKey: k) }
        Group {
            if let image {
                content(Image(decorative: image, scale: 1))
            } else {
                placeholder()
            }
        }
        .task(id: key) {
            guard let key, let data else { decoded = nil; return }
            if let cached = PhotoDecodeCache.shared.image(forKey: key) {
                decoded = DecodedImage(key: key, image: cached)
                return
            }
            let size = maxPixelSize
            let image = await Task.detached(priority: .userInitiated) {
                ImageProcessing.downsampledCGImage(from: data, maxPixelSize: size)
            }.value
            guard !Task.isCancelled, let image else { return }
            PhotoDecodeCache.shared.setImage(image, forKey: key)
            decoded = DecodedImage(key: key, image: image)
        }
    }

    private struct DecodedImage {
        let key: String
        let image: CGImage
    }
}

/// Decoded images keyed by a fingerprint of their source data and target size.
final class PhotoDecodeCache: @unchecked Sendable {
    static let shared = PhotoDecodeCache()

    private final class Entry {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    private let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    func image(forKey key: String) -> CGImage? {
        cache.object(forKey: key as NSString)?.image
    }

    func setImage(_ image: CGImage, forKey key: String) {
        cache.setObject(Entry(image), forKey: key as NSString, cost: image.bytesPerRow * image.height)
    }

    /// A cheap content fingerprint: the length plus a hash of the head and tail.
    /// Image headers are often identical, but the end of the compressed data
    /// differs between any two pictures.
    static func key(for data: Data, maxPixelSize: Int) -> String {
        var hasher = Hasher()
        hasher.combine(data.count)
        data.prefix(256).withUnsafeBytes { hasher.combine(bytes: $0) }
        data.suffix(4096).withUnsafeBytes { hasher.combine(bytes: $0) }
        return "\(maxPixelSize)-\(data.count)-\(hasher.finalize())"
    }
}

// MARK: - Thumbnail backfill

/// A model with a full-size photo in external storage and a small inline thumbnail.
protocol PhotoThumbnailOwner: PersistentModel {
    var photoData: Data? { get }
    var thumbnailData: Data? { get set }
}

extension Horse: PhotoThumbnailOwner {}
extension FeedProduct: PhotoThumbnailOwner {}

@MainActor
enum ThumbnailBackfill {
    private static var inFlight: Set<PersistentIdentifier> = []

    /// Records saved before thumbnails existed (or synced from an older build)
    /// have a photo but no thumbnail. Make one off the main actor and save it.
    static func ensureThumbnail(for owner: some PhotoThumbnailOwner, in context: ModelContext) async {
        guard owner.thumbnailData == nil else { return }
        let id = owner.persistentModelID
        guard !inFlight.contains(id), let photo = owner.photoData else { return }
        inFlight.insert(id)
        defer { inFlight.remove(id) }
        guard let thumbnail = await ImageProcessing.thumbnailJPEGInBackground(from: photo) else {
            BarnHubLogger.warning("Thumbnail backfill: photo could not be decoded")
            return
        }
        // The record may have been deleted or given a new photo meanwhile.
        guard !owner.isDeleted, owner.thumbnailData == nil, owner.photoData == photo else { return }
        owner.thumbnailData = thumbnail
        context.saveWithLogging()
    }
}

extension View {
    /// Generates a missing thumbnail for `owner` the first time this view appears.
    func backfillsThumbnail(for owner: some PhotoThumbnailOwner) -> some View {
        modifier(ThumbnailBackfillModifier(owner: owner))
    }
}

private struct ThumbnailBackfillModifier<Owner: PhotoThumbnailOwner>: ViewModifier {
    let owner: Owner
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.task(id: owner.persistentModelID) {
            await ThumbnailBackfill.ensureThumbnail(for: owner, in: modelContext)
        }
    }
}
