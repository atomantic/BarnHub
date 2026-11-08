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
    @State private var documentToDelete: HorseDocument?
    @State private var toast = ToastState()
    @State private var showShareSheet = false
    @State private var shareURL: URL?

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
                message: "Are you sure you want to delete \"\(documentToDelete?.title ?? "this document")\"?",
                confirmTitle: "Delete",
                confirmRole: .destructive
            ) {
                guard let doc = documentToDelete else { return }
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
        .sheet(isPresented: $showShareSheet, onDismiss: {
            ShareTempFiles.cleanUp(shareURL)
            shareURL = nil
        }) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func documentRow(_ doc: HorseDocument) -> some View {
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
        BarnHubLogger.success("Document added horse=\(horse.name) title=\(title) type=\(type.rawValue)")
    }

    private func shareDocument(_ doc: HorseDocument) {
        guard let data = doc.fileData else { return }
        do {
            ShareTempFiles.cleanUp(shareURL)
            shareURL = try ShareTempFiles.write(data, fileName: doc.title, fileExtension: doc.fileExtension)
            showShareSheet = true
        } catch {
            BarnHubLogger.error("Failed to write document for sharing error=\(error.localizedDescription)")
            toast.show(appLocalized("Failed to share document"), isError: true)
        }
    }
}
