import SwiftUI
import SwiftData

struct HorsePickerSection: View {
    @Binding var selectedHorseID: PersistentIdentifier?
    var placeholder: String = "None"

    @Query(sort: \Horse.name) private var horses: [Horse]

    var body: some View {
        Section("Horse") {
            Picker("Assign Horse", selection: $selectedHorseID) {
                Text(placeholder).tag(nil as PersistentIdentifier?)
                ForEach(horses) { horse in
                    Text(horse.name).tag(horse.persistentModelID as PersistentIdentifier?)
                }
            }
        }
    }
}
