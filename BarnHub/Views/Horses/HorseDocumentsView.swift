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
    @State private var showDeleteConfirmation = false
    @State private var documentToDelete: HorseDocument?
    @State private var toast = ToastState()
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    private var horse: Horse? {
        modelContext.model(for: horseID) as? Horse
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
                        await MainActor.run {
                            addDocument(title: "Photo \(Date.now.shortFormatted)", type: .photo, data: data)
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
                toast.show(appLocalized("Document deleted"))
                documentToDelete = nil
            }
        }
        .toast(toast)
        .onDisappear { photoLoadTask?.cancel() }
        .sheet(isPresented: $showShareSheet) {
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
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else { return }
        let name = url.deletingPathExtension().lastPathComponent
        addDocument(title: name, type: .pdf, data: data)
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
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(doc.fileName)
        try? data.write(to: tempURL)
        shareURL = tempURL
        showShareSheet = true
    }
}
