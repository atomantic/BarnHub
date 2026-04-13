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
    @State private var gender: HorseGender = .mare
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

    // MARK: - Shared Form Sections

    private var photoSection: some View {
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
    }

    private var basicInfoSection: some View {
        Section("Basic Info") {
            TextField("Name", text: $name)
            TextField("Breed", text: $breed)
            DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
            Picker("Gender", selection: $gender) {
                ForEach(HorseGender.allCases) { g in
                    Text(g.displayName).tag(g)
                }
            }
            TextField("Color/Markings", text: $colorMarkings)
        }
    }

    private var detailsSection: some View {
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
    }

    private var medicalNotesSection: some View {
        Section("Medical Notes") {
            TextEditor(text: $medicalNotes)
                .frame(minHeight: 80)
        }
    }

    private var feedingScheduleSection: some View {
        Section("Feeding Schedule") {
            TextEditor(text: $feedingSchedule)
                .frame(minHeight: 80)
        }
    }

    private var saveSection: some View {
        Section {
            Button(saveButtonLabel) {
                save()
            }
            .frame(maxWidth: .infinity)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Body

    var body: some View {
        formContent
            .toast(toast)
            .task { loadExisting() }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                photoLoadTask?.cancel()
                photoLoadTask = Task {
                    do {
                        if let data = try await newItem.loadTransferable(type: Data.self) {
                            await MainActor.run {
                                photoData = data.downsampledImage(maxDimension: 800)
                                selectedPhoto = nil
                            }
                        }
                    } catch is CancellationError {
                        // Cancelled by a newer selection
                    } catch {
                        await MainActor.run {
                            toast.show(appLocalized("Failed to load photo"), isError: true)
                        }
                    }
                }
            }
    }

    @ViewBuilder
    private var formContent: some View {
        #if os(macOS)
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                Form {
                    photoSection
                    basicInfoSection
                    detailsSection
                }
                .formStyle(.grouped)
                .frame(maxWidth: .infinity)

                Form {
                    medicalNotesSection
                    feedingScheduleSection
                    saveSection
                }
                .formStyle(.grouped)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle(navigationTitleKey)
        #else
        Form {
            photoSection
            basicInfoSection
            detailsSection
            medicalNotesSection
            feedingScheduleSection
            saveSection
        }
        .navigationTitle(navigationTitleKey)
        .inlineNavTitle()
        #endif
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
        gender = horse.gender
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
            horse.gender = gender
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
                gender: gender,
                isActive: isActive,
                photoData: photoData
            )
            modelContext.insert(horse)
            BarnHubLogger.info("Creating horse name=\(trimmedName)")
        }

        modelContext.saveWithLogging()
        toast.showAndDismiss(isNew ? appLocalized("Horse added") : appLocalized("Horse updated"), dismiss: dismiss)
    }

}
