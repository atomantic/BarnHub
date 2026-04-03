import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct ClientDocumentsView: View {
    let clientID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

    @State private var showPDFPicker = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var showDeleteConfirmation = false
    @State private var documentToDelete: ClientDocument?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    private var client: Client? {
        modelContext.model(for: clientID) as? Client
    }

    private var documents: [ClientDocument] {
        (client?.documents ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if documents.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Documents",
                    subtitle: "Tap + to upload a contract, agreement, or photo."
                )
            } else {
                ForEach(documents, id: \.persistentModelID) { doc in
                    documentRow(doc)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                documentToDelete = doc
                                showDeleteConfirmation = true
                            }
                            Button("Share") {
                                shareDocument(doc)
                            }
                            .tint(.blue)
                        }
                }
            }
        }
        .navigationTitle("Documents")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showPDFPicker = true
                    } label: {
                        Label("Import PDF", systemImage: "doc.fill")
                    }
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Choose Photo", systemImage: "photo.fill")
                    }
                    #if os(iOS)
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                    }
                    #endif
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showPDFPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handlePDFImport(result)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            photoLoadTask?.cancel()
            photoLoadTask = Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            addDocument(title: "Photo \(Date.now.shortFormatted)", type: .photo, data: data)
                        }
                    }
                } catch is CancellationError {
                    // Task was cancelled by a newer selection — no error toast needed.
                    return
                } catch {
                    await MainActor.run {
                        toastMessage = String(localized: "Failed to load photo")
                        showToast = true
                    }
                }
                await MainActor.run { selectedPhoto = nil }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { imageData in
                addDocument(title: "Scan \(Date.now.shortFormatted)", type: .photo, data: imageData)
            }
        }
        #endif
        .overlay {
            ConfirmationDialog(
                isPresented: $showDeleteConfirmation,
                title: "Delete Document",
                message: "Are you sure you want to delete \"\(documentToDelete?.title ?? "this document")\"?",
                confirmTitle: "Delete",
                confirmRole: .destructive
            ) {
                guard let doc = documentToDelete else { return }
                modelContext.deleteWithLogging(doc)
                toastMessage = String(localized: "Document deleted")
                showToast = true
                documentToDelete = nil
            }
        }
        .toast(isPresented: $showToast, message: toastMessage)
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func documentRow(_ doc: ClientDocument) -> some View {
        Button {
            shareDocument(doc)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: doc.documentType.icon)
                    .foregroundStyle(.barnGreen)
                    .font(.title3)
                    .frame(width: 32)
                    .accessibilityLabel(doc.documentType.displayName)

                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(doc.createdAt.shortFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(doc.documentType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.primary)
    }

    private func handlePDFImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else { return }
        let name = url.deletingPathExtension().lastPathComponent
        addDocument(title: name, type: .pdf, data: data)
    }

    private func addDocument(title: String, type: DocumentType, data: Data) {
        guard let client else { return }
        let doc = ClientDocument(title: title, documentType: type, fileData: data)
        doc.client = client
        modelContext.insert(doc)
        modelContext.saveWithLogging()
        toastMessage = String(localized: "Document added")
        showToast = true
        BarnHubLogger.success("Document added client=\(client.fullName) title=\(title) type=\(type.rawValue)")
    }

    private func shareDocument(_ doc: ClientDocument) {
        guard let data = doc.fileData else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(doc.fileName)
        try? data.write(to: tempURL)
        shareURL = tempURL
        showShareSheet = true
    }
}

#if os(iOS)
// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.8) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
