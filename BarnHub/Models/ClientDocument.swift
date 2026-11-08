import Foundation
import SwiftData

@Model
final class ClientDocument {
    var title: String = ""
    var createdAt: Date = Date.now
    var typeRaw: String = DocumentType.pdf.rawValue

    @Attribute(.externalStorage)
    var fileData: Data? = nil

    @Relationship(deleteRule: .nullify)
    var client: Client? = nil

    var documentType: DocumentType {
        get { DocumentType(rawValue: typeRaw) ?? .pdf }
        set { typeRaw = newValue.rawValue }
    }

    /// The extension the shared file should carry: photos picked before
    /// documents were normalized to JPEG may still be HEIC or PNG.
    var fileExtension: String {
        documentType == .photo ? ImageProcessing.fileExtension(forImageData: fileData) : "pdf"
    }

    init(title: String = "", documentType: DocumentType = .pdf, fileData: Data? = nil) {
        self.title = title
        self.typeRaw = documentType.rawValue
        self.createdAt = .now
        self.fileData = fileData
    }
}

enum DocumentType: String, CaseIterable, Identifiable {
    case pdf
    case photo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pdf:   return appLocalized("PDF",   comment: "Document type")
        case .photo: return appLocalized("Photo", comment: "Document type")
        }
    }

    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .photo: return "photo.fill"
        }
    }
}
