import SwiftUI
import SwiftData

struct ContractGeneratorView: View {
    let clientID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var contractType: ContractType = .boardingAgreement
    @State private var selectedHorseID: PersistentIdentifier?
    @State private var startDate = Date.now
    @State private var monthlyRate: Double = 0
    @State private var showShareSheet = false
    @State private var generatedPDFURL: URL?
    /// A PDF is being drawn in the background; the button stays disabled until it's ready.
    @State private var isGenerating = false
    @State private var toast = ToastState()

    private var client: Client? {
        modelContext.existingModel(for: clientID)
    }

    private var assignedHorses: [Horse] {
        (client?.horses ?? []).sorted { $0.name < $1.name }
    }

    private var selectedHorse: Horse? {
        guard let id = selectedHorseID else { return nil }
        return modelContext.existingModel(for: id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contract Type") {
                    Picker("Type", selection: $contractType) {
                        ForEach(ContractType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                }

                Section("Horse") {
                    if assignedHorses.isEmpty {
                        Text("No horses assigned to this client")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Horse", selection: $selectedHorseID) {
                            Text("Select a horse").tag(nil as PersistentIdentifier?)
                            ForEach(assignedHorses, id: \.persistentModelID) { horse in
                                Text(horse.name).tag(horse.persistentModelID as PersistentIdentifier?)
                            }
                        }
                    }
                }

                if contractType == .boardingAgreement {
                    Section("Boarding Terms") {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        CurrencyField(label: "Monthly Rate", value: $monthlyRate)
                    }
                }

                Section {
                    Button {
                        generateAndShare()
                    } label: {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Label("Generate & Share", systemImage: "doc.text.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(selectedHorseID == nil || isGenerating)
                }
            }
            .navigationTitle("Generate Contract")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet, onDismiss: {
                ShareTempFiles.cleanUp(generatedPDFURL)
                generatedPDFURL = nil
            }) {
                if let url = generatedPDFURL {
                    ShareSheet(items: [url])
                }
            }
            .toast(toast)
            .task {
                if selectedHorseID == nil, let first = assignedHorses.first {
                    selectedHorseID = first.persistentModelID
                }
            }
        }
    }

    private func generateAndShare() {
        guard let client, let horse = selectedHorse, !isGenerating else { return }
        let type = contractType
        let document = ContractPDFService.document(
            type: type,
            clientName: client.fullName,
            clientPhone: client.phone,
            clientEmail: client.email,
            emergencyContact: client.emergencyContact,
            emergencyPhone: client.emergencyPhone,
            horseName: horse.name,
            horseBreed: horse.breed,
            stallNumber: horse.stallNumber,
            startDate: startDate,
            monthlyRate: monthlyRate
        )
        let fileName = ContractPDFService.fileName(type: type, clientName: client.fullName)

        isGenerating = true
        Task {
            defer { isGenerating = false }
            // Drawing the PDF and writing the share file stay off the main actor.
            let written = await Task.detached(priority: .userInitiated) {
                Result { try ShareTempFiles.write(ContractPDFService.render(document), fileName: fileName, fileExtension: "pdf") }
            }.value

            switch written {
            case .success(let tempURL):
                generatedPDFURL = tempURL
                showShareSheet = true
                BarnHubLogger.success("Contract generated type=\(type.rawValue)")
            case .failure(let error):
                BarnHubLogger.error("Failed to write contract PDF error=\(error.localizedDescription)")
                toast.show(appLocalized("Failed to save contract"), isError: true)
            }
        }
    }
}
