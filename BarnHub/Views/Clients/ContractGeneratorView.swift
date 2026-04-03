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
    @State private var toast = ToastState()

    private var client: Client? {
        modelContext.model(for: clientID) as? Client
    }

    private var assignedHorses: [Horse] {
        (client?.horses ?? []).sorted { $0.name < $1.name }
    }

    private var selectedHorse: Horse? {
        guard let id = selectedHorseID else { return nil }
        return modelContext.model(for: id) as? Horse
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
                            Label("Generate & Share", systemImage: "doc.text.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(selectedHorseID == nil)
                }
            }
            .navigationTitle("Generate Contract")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
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
        guard let client, let horse = selectedHorse else { return }

        let pdfData = ContractPDFService.generatePDF(
            type: contractType,
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

        let fileName = ContractPDFService.fileName(type: contractType, clientName: client.fullName)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pdfData.write(to: tempURL)
        } catch {
            BarnHubLogger.error("Failed to write contract PDF error=\(error.localizedDescription)")
            toast.show(String(localized: "Failed to save contract"), isError: true)
            return
        }
        generatedPDFURL = tempURL
        showShareSheet = true

        BarnHubLogger.success("Contract generated type=\(contractType.displayName) client=\(client.fullName) horse=\(horse.name)")
    }
}
