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
