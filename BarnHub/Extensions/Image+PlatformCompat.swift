import SwiftUI
import ImageIO

#if os(iOS) || targetEnvironment(macCatalyst)
extension CGImagePropertyOrientation {
    /// The EXIF orientation matching a UIImage's orientation, so a camera image's
    /// pixels can be encoded as-is with the rotation kept in metadata.
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
#endif
