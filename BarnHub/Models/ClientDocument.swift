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

    var fileName: String {
        let safe = title.replacingOccurrences(of: " ", with: "_")
        let ext = documentType == .photo ? "jpg" : "pdf"
        return "\(safe).\(ext)"
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
        case .pdf: return "PDF"
        case .photo: return "Photo"
        }
    }

    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .photo: return "photo.fill"
        }
    }
}
