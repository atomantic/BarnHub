import SwiftUI
import SwiftData
import PhotosUI

struct HorseEditView: View {
    let horseID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var breed = ""
    @State private var dateOfBirth = Date.now
    @State private var colorMarkings = ""
    @State private var weight: Double = 0
    @State private var purchasePrice: Double = 0
    @State private var medicalNotes = ""
    @State private var feedingSchedule = ""
    @State private var stallNumber = ""
    @State private var isActive = true

    @State private var photoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoLoadTask: Task<Void, Never>?

    @State private var toast = ToastState()

    private var isNew: Bool { horseID == nil }
    private var existingHorse: Horse? { modelContext.existingModel(for: horseID) }

    private var addPhotoLabel: LocalizedStringKey { photoData == nil ? "Add Photo" : "Change Photo" }
    private var saveButtonLabel: LocalizedStringKey { isNew ? "Add Horse" : "Save Changes" }
    private var navigationTitleKey: LocalizedStringKey { isNew ? "New Horse" : "Edit Horse" }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    if let photoData, let image = Image(photoData: photoData) {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "photo.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundStyle(.secondary.opacity(0.4))
                            .accessibilityLabel("No photo")
                    }

                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(addPhotoLabel, systemImage: "photo")
                                .font(.subheadline)
                        }

                        if photoData != nil {
                            Button(role: .destructive) {
                                withAnimation {
                                    photoData = nil
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

            Section("Basic Info") {
                TextField("Name", text: $name)
                TextField("Breed", text: $breed)
                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                TextField("Color/Markings", text: $colorMarkings)
            }

            Section("Details") {
                HStack {
                    Text("Weight (lbs)")
                    Spacer()
                    TextField("0", value: $weight, format: .number)
                        .decimalKeyboard()
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Purchase Price")
                    Spacer()
                    TextField("$0", value: $purchasePrice, format: .currency(code: "USD"))
                        .decimalKeyboard()
                        .multilineTextAlignment(.trailing)
                }
                TextField("Stall Number", text: $stallNumber)
                Toggle("Active", isOn: $isActive)
            }

            Section("Medical Notes") {
                TextEditor(text: $medicalNotes)
                    .frame(minHeight: 80)
            }

            Section("Feeding Schedule") {
                TextEditor(text: $feedingSchedule)
                    .frame(minHeight: 80)
            }

            Section {
                Button(saveButtonLabel) {
                    save()
                }
                .frame(maxWidth: .infinity)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle(navigationTitleKey)
        .inlineNavTitle()
        #if os(macOS)
        .formStyle(.grouped)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        #endif
        .toast(toast)
        .task { loadExisting() }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            photoLoadTask?.cancel()
            photoLoadTask = Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            photoData = downsampleImageData(data, maxDimension: 800)
                            selectedPhoto = nil
                        }
                    }
                } catch is CancellationError {
                    // Task was cancelled by a newer selection — no error toast needed.
                } catch {
                    await MainActor.run {
                        toast.show(appLocalized("Failed to load photo"), isError: true)
                    }
                }
            }
        }
    }

    private func loadExisting() {
        guard let horse = existingHorse else { return }
        name = horse.name
        breed = horse.breed
        dateOfBirth = horse.dateOfBirth
        colorMarkings = horse.colorMarkings
        weight = horse.weight
        purchasePrice = horse.purchasePrice
        medicalNotes = horse.medicalNotes
        feedingSchedule = horse.feedingSchedule
        stallNumber = horse.stallNumber
        isActive = horse.isActive
        photoData = horse.photoData
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let horse = existingHorse {
            horse.name = trimmedName
            horse.breed = breed
            horse.dateOfBirth = dateOfBirth
            horse.colorMarkings = colorMarkings
            horse.weight = weight
            horse.purchasePrice = purchasePrice
            horse.medicalNotes = medicalNotes
            horse.feedingSchedule = feedingSchedule
            horse.stallNumber = stallNumber
            horse.isActive = isActive
            horse.photoData = photoData
            BarnHubLogger.info("Updating horse name=\(trimmedName)")
        } else {
            let horse = Horse(
                name: trimmedName,
                breed: breed,
                dateOfBirth: dateOfBirth,
                colorMarkings: colorMarkings,
                weight: weight,
                purchasePrice: purchasePrice,
                medicalNotes: medicalNotes,
                feedingSchedule: feedingSchedule,
                stallNumber: stallNumber,
                isActive: isActive,
                photoData: photoData
            )
            modelContext.insert(horse)
            BarnHubLogger.info("Creating horse name=\(trimmedName)")
        }

        modelContext.saveWithLogging()
        toast.showAndDismiss(isNew ? appLocalized("Horse added") : appLocalized("Horse updated"), dismiss: dismiss)
    }

    private func downsampleImageData(_ data: Data, maxDimension: CGFloat) -> Data {
#if os(iOS) || targetEnvironment(macCatalyst)
        guard let uiImage = UIImage(data: data) else { return data }
        let size = uiImage.size
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        guard scale < 1.0 else { return data }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in uiImage.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.8) ?? data
#else
        guard let nsImage = NSImage(data: data) else { return data }
        let size = nsImage.size
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        guard scale < 1.0 else { return data }
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        nsImage.draw(in: NSRect(origin: .zero, size: newSize))
        resized.unlockFocus()
        guard let tiffData = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: 0.8)]) else {
            return data
        }
        return jpegData
#endif
    }
}
