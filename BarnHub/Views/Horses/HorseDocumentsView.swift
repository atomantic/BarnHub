import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct HorseDocumentsView: View {
    let horseID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

    @State private var showPDFPicker = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var fileImportTask: Task<Void, Never>?
    @State private var showDeleteConfirmation = false
    @State private var documentToDelete: PendingDeletion?
    @State private var toast = ToastState()
    @State private var previewURL: URL?
    @State private var shareFile: SharedFile?

    private var horse: Horse? {
        modelContext.existingModel(for: horseID)
    }

    private var documents: [HorseDocument] {
        (horse?.documents ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if documents.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Documents",
                    subtitle: "Tap + to upload Coggins tests, health certificates, registration papers, and more."
                )
            } else {
                List {
                    ForEach(documents, id: \.persistentModelID) { doc in
                        documentRow(doc)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    documentToDelete = PendingDeletion(id: doc.persistentModelID, name: doc.title)
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
                    Label("Add Document", systemImage: "plus")
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
                        let jpeg = await ImageProcessing.downsampledJPEGInBackground(
                            from: data, maxPixelSize: ImageProcessing.documentMaxPixelSize
                        )
                        guard !Task.isCancelled else { return }
                        if let jpeg {
                            addDocument(title: "Photo \(Date.now.shortFormatted)", type: .photo, data: jpeg)
                        } else {
                            toast.show(appLocalized("Failed to load photo"), isError: true)
                        }
                    }
                } catch is CancellationError {
                    return
                } catch {
                    await MainActor.run {
                        toast.show(appLocalized("Failed to load photo"), isError: true)
                    }
                }
                await MainActor.run { selectedPhoto = nil }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { capture in
                photoLoadTask?.cancel()
                photoLoadTask = Task {
                    let jpeg = await ImageProcessing.downsampledJPEGInBackground(
                        from: capture.image,
                        orientation: capture.orientation,
                        maxPixelSize: ImageProcessing.documentMaxPixelSize
                    )
                    guard !Task.isCancelled else { return }
                    if let jpeg {
                        addDocument(title: "Scan \(Date.now.shortFormatted)", type: .photo, data: jpeg)
                    } else {
                        toast.show(appLocalized("Failed to load photo"), isError: true)
                    }
                }
            }
        }
        #endif
        .overlay {
            ConfirmationDialog(
                isPresented: $showDeleteConfirmation,
                title: "Delete Document",
                message: "Are you sure you want to delete \"\(documentToDelete?.name ?? "this document")\"?",
                confirmTitle: "Delete",
                confirmRole: .destructive
            ) {
                guard let pending = documentToDelete,
                      let doc: HorseDocument = modelContext.existingModel(for: pending.id) else {
                    documentToDelete = nil
                    return
                }
                modelContext.deleteWithLogging(doc)
                toast.show(appLocalized("Document deleted"))
                documentToDelete = nil
            }
        }
        .toast(toast)
        .onDisappear {
            photoLoadTask?.cancel()
            fileImportTask?.cancel()
        }
        .documentPresentation(preview: $previewURL, share: $shareFile)
    }

    private func documentRow(_ doc: HorseDocument) -> some View {
        Button {
            previewDocument(doc)
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
        .foregroundStyle(.primary)  // not .tint(.primary): a hierarchical tint can loop endlessly on Mac Catalyst
    }

    private func handlePDFImport(_ result: Result<[URL], Error>) {
        let url: URL
        switch result {
        case .success(let urls):
            guard let first = urls.first else { return }
            url = first
        case .failure(let error):
            BarnHubLogger.error("PDF picker failed error=\(error.localizedDescription)")
            toast.show(appLocalized("Could not open file: \(error.localizedDescription)", comment: "File open error"), isError: true)
            return
        }
        fileImportTask?.cancel()
        fileImportTask = Task {
            do {
                let data = try await DocumentImport.readFile(at: url)
                guard !Task.isCancelled else { return }
                addDocument(title: url.deletingPathExtension().lastPathComponent, type: .pdf, data: data)
            } catch {
                guard !Task.isCancelled else { return }
                BarnHubLogger.error("PDF import failed error=\(error.localizedDescription)")
                toast.show(error.localizedDescription, isError: true)
            }
        }
    }

    private func addDocument(title: String, type: DocumentType, data: Data) {
        guard let horse else { return }
        let doc = HorseDocument(title: title, documentType: type, fileData: data)
        doc.horse = horse
        modelContext.insert(doc)
        modelContext.saveWithLogging()
        toast.show(appLocalized("Document added"))
        BarnHubLogger.success("Horse document added type=\(type.rawValue) documents=\(horse.documents?.count ?? 0)")
    }

    /// Opens the document in Quick Look, so a photo or PDF can be read in place.
    private func previewDocument(_ doc: HorseDocument) {
        guard let url = writeTempFile(for: doc) else { return }
        previewURL = url
    }

    private func shareDocument(_ doc: HorseDocument) {
        guard let url = writeTempFile(for: doc) else { return }
        shareFile = SharedFile(url: url)
    }

    private func writeTempFile(for doc: HorseDocument) -> URL? {
        guard let data = doc.fileData else {
            // A document synced from another device can arrive before its file does.
            BarnHubLogger.warning("Document has no file data yet type=\(doc.typeRaw)")
            toast.show(appLocalized("This file is still downloading from iCloud. Try again in a moment.", comment: "Toast when a synced document's file hasn't arrived yet"), isError: true)
            return nil
        }
        do {
            return try ShareTempFiles.write(data, fileName: doc.title, fileExtension: doc.fileExtension)
        } catch {
            BarnHubLogger.error("Failed to write document temp file error=\(error.localizedDescription)")
            toast.show(appLocalized("Failed to open document", comment: "Error toast when a stored document can't be written out to preview or share"), isError: true)
            return nil
        }
    }
}
