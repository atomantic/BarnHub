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

    @State private var toast = ToastState()

    private var isNew: Bool { horseID == nil }
    private var existingHorse: Horse? { modelContext.existingModel(for: horseID) }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
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
                            Label(photoData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
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
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Purchase Price")
                    Spacer()
                    TextField("$0", value: $purchasePrice, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
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
                Button(isNew ? "Add Horse" : "Save Changes") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle(isNew ? "New Horse" : "Edit Horse")
        .toast(toast)
        .task { loadExisting() }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        photoData = downsampleImageData(data, maxDimension: 800)
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
        toast.showAndDismiss(isNew ? "Horse added" : "Horse updated", dismiss: dismiss)
    }

    private func downsampleImageData(_ data: Data, maxDimension: CGFloat) -> Data {
        guard let uiImage = UIImage(data: data) else { return data }
        let size = uiImage.size
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        guard scale < 1.0 else { return data }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }
}
