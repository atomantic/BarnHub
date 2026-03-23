import Foundation

extension URL {
    static var privacyPolicy: URL {
        guard let url = URL(string: "https://barnhub.online/privacy") else {
            fatalError("Invalid privacyPolicy URL")
        }
        return url
    }

    static var termsOfUse: URL {
        guard let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") else {
            fatalError("Invalid termsOfUse URL")
        }
        return url
    }
}
