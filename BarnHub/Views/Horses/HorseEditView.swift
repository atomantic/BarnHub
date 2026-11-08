import SwiftUI
import SwiftData
import PhotosUI

struct HorseEditView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    let horseID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
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
    @State private var thumbnailData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoLoadTask: Task<Void, Never>?

    @State private var toast = ToastState()

    private var isNew: Bool { horseID == nil }
    private var existingHorse: Horse? { modelContext.existingModel(for: horseID) }
    /// Editing a record that was deleted meanwhile (here or on another device).
    private var wasDeletedElsewhere: Bool { modelContext.isDeletedRecord(horseID, as: Horse.self) }

    private var addPhotoLabel: LocalizedStringKey { photoData == nil ? "Add Photo" : "Change Photo" }
    private var navigationTitleKey: LocalizedStringKey { isNew ? "New Horse" : "Edit Horse" }

    // MARK: - Shared Form Sections

    private var photoSection: some View {
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
            LabeledContent("Weight (lbs)") {
                TextField("0", value: $weight, format: .number)
                    .labelsHidden()
                    .decimalKeyboard()
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Purchase Price") {
                TextField("$0", value: $purchasePrice, format: .currency(code: "USD"))
                    .labelsHidden()
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

    // MARK: - Body

    var body: some View {
        formContent
            .toolbar {
                // In the bar rather than floating at the end of the form, so it's
                // always reachable and sits next to Cancel when shown as a sheet.
                ToolbarItem(placement: .pinnedConfirmation) {
                    Button(isNew ? "Add" : "Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
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
                        guard let processed else {
                            toast.show(appLocalized("Failed to load photo"), isError: true)
                            return
                        }
                        photoData = processed.photo
                        thumbnailData = processed.thumbnail
                        selectedPhoto = nil
                    } catch is CancellationError {
                        // Cancelled by a newer selection
                    } catch {
                        toast.show(appLocalized("Failed to load photo"), isError: true)
                    }
                }
            }
            .onDisappear { photoLoadTask?.cancel() }
    }

    @ViewBuilder
    private var formContent: some View {
        #if os(macOS)
        // One column: the form opens as a sheet, too narrow for two.
        Form {
            photoSection
            basicInfoSection
            detailsSection
            medicalNotesSection
            feedingScheduleSection
        }
        .formStyle(.grouped)
        .navigationTitle(navigationTitleKey)
        #else
        Group {
            if sizeClass == .regular {
                WideColumns {
                    photoSection
                    basicInfoSection
                    detailsSection
                } trailing: {
                    medicalNotesSection
                    feedingScheduleSection
                }
            } else {
                Form {
                    photoSection
                    basicInfoSection
                    detailsSection
                    medicalNotesSection
                    feedingScheduleSection
                }
            }
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
        thumbnailData = horse.thumbnailData
    }

    private func save() {
        // Never insert a replacement for a record deleted while the form was open.
        guard !wasDeletedElsewhere else {
            toast.showAndDismiss(appLocalized("This item was deleted", comment: "Toast when saving a record that was deleted elsewhere"), isError: true, dismiss: dismiss)
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        var newHorse: Horse?

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
            horse.thumbnailData = thumbnailData
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
            horse.thumbnailData = thumbnailData
            modelContext.insert(horse)
            BarnHubLogger.info("Creating horse name=\(trimmedName)")
            newHorse = horse
        }

        modelContext.saveWithLogging()
        // Show the new horse beside the list when the split is up. Read the ID only
        // after saving: before that it's temporary, and a view that resolves a
        // temporary ID traps once SwiftData swaps in the permanent one.
        if let newHorse, router.horsesShowSplit {
            router.selectedHorseID = newHorse.persistentModelID
        }
        toast.showAndDismiss(isNew ? appLocalized("Horse added") : appLocalized("Horse updated"), dismiss: dismiss)
    }

}
