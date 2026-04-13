import Foundation
import SwiftData

@Model
final class HorseDocument {
    var title: String = ""
    var createdAt: Date = Date.now
    var typeRaw: String = DocumentType.pdf.rawValue

    @Attribute(.externalStorage)
    var fileData: Data? = nil

    @Relationship(deleteRule: .nullify)
    var horse: Horse? = nil

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
