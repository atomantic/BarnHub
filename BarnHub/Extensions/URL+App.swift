import Foundation

extension URL {
    static var privacyPolicy: URL {
        guard let url = URL(string: "https://adameivy.com/barn.io/privacy") else {
            fatalError("Invalid privacyPolicy URL")
        }
        return url
    }

    static var termsOfUse: URL {
        guard let url = URL(string: "https://adameivy.com/barn.io/terms") else {
            fatalError("Invalid termsOfUse URL")
        }
        return url
    }
}
