import SwiftUI
import SwiftData
import PhotosUI

struct FeedProductEditView: View {
    let productID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var notes = ""
    @State private var defaultUnit: FeedUnit = .scoops
    @State private var photoData: Data?
    @State private var thumbnailData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var showCamera = false
    @State private var toast = ToastState()

    private var isNew: Bool { productID == nil }
    private var existingProduct: FeedProduct? { modelContext.existingModel(for: productID) }
    /// Editing a record that was deleted meanwhile (here or on another device).
    private var wasDeletedElsewhere: Bool { modelContext.isDeletedRecord(productID, as: FeedProduct.self) }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    if photoData != nil {
                        CachedPhotoView(data: photoData, maxPixelSize: 360) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.secondary.opacity(0.15)
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "leaf.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundStyle(.secondary.opacity(0.4))
                    }

                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(photoData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                                .font(.subheadline)
                        }

                        #if os(iOS)
                        Button {
                            showCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera")
                                .font(.subheadline)
                        }
                        #endif

                        if photoData != nil {
                            Button(role: .destructive) {
                                withAnimation {
                                    photoData = nil
                                    thumbnailData = nil
                                    selectedPhoto = nil
                                }
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Product Info") {
                TextField("Name", text: $name)
                TextField("Brand", text: $brand)
                Picker("Default Unit", selection: $defaultUnit) {
                    ForEach(FeedUnit.allCases) { u in
                        Text(u.displayName).tag(u)
                    }
                }
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 60)
            }

        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(isNew ? "New Feed Product" : "Edit Product")
        .toolbar {
            // In the bar rather than at the bottom of the form, so it's always
            // reachable and sits next to Cancel when the form opens as a sheet.
            ToolbarItem(placement: .pinnedConfirmation) {
                Button(isNew ? "Add" : "Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .inlineNavTitle()
        .deletedRecordNotice(wasDeletedElsewhere)
        .toast(toast)
        .task { loadExisting() }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            photoLoadTask?.cancel()
            photoLoadTask = Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self) else { return }
                    let processed = await ImageProcessing.processPhoto(from: data)
                    guard !Task.isCancelled else { return }
                    apply(processed)
                    selectedPhoto = nil
                } catch is CancellationError {
                    // cancelled
                } catch {
                    toast.show(appLocalized("Failed to load photo"), isError: true)
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { capture in
                photoLoadTask?.cancel()
                photoLoadTask = Task {
                    let processed = await ImageProcessing.processPhoto(from: capture.image, orientation: capture.orientation)
                    guard !Task.isCancelled else { return }
                    apply(processed)
                }
            }
        }
        #endif
        .onDisappear { photoLoadTask?.cancel() }
    }

    private func apply(_ processed: ImageProcessing.ProcessedPhoto?) {
        guard let processed else {
            toast.show(appLocalized("Failed to load photo"), isError: true)
            return
        }
        photoData = processed.photo
        thumbnailData = processed.thumbnail
    }

    private func loadExisting() {
        guard let product = existingProduct else { return }
        name = product.name
        brand = product.brand
        notes = product.notes
        defaultUnit = product.defaultUnit
        photoData = product.photoData
        thumbnailData = product.thumbnailData
    }

    private func save() {
        // Never insert a replacement for a record deleted while the form was open.
        guard !wasDeletedElsewhere else {
            toast.showAndDismiss(appLocalized("This item was deleted", comment: "Toast when saving a record that was deleted elsewhere"), isError: true, dismiss: dismiss)
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let product = existingProduct {
            product.name = trimmedName
            product.brand = brand
            product.notes = notes
            product.defaultUnit = defaultUnit
            product.photoData = photoData
            product.thumbnailData = thumbnailData
            BarnHubLogger.info("Updating feed product name=\(trimmedName)")
        } else {
            let product = FeedProduct(
                name: trimmedName,
                brand: brand,
                notes: notes,
                defaultUnit: defaultUnit,
                photoData: photoData
            )
            product.thumbnailData = thumbnailData
            modelContext.insert(product)
            BarnHubLogger.info("Creating feed product name=\(trimmedName)")
        }

        modelContext.saveWithLogging()
        toast.showAndDismiss(
            isNew ? appLocalized("Product added") : appLocalized("Product updated"),
            dismiss: dismiss
        )
    }
}
