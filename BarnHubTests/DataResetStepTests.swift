import XCTest
@testable import BarnHub

/// The Delete All Data and Restore All Data dialog steps (#76).
final class DataResetStepTests: XCTestCase {
    private let folder = URL(fileURLWithPath: "/tmp/BarnHub Export", isDirectory: true)

    func test_deleteAllData_asksScopeThenFinalConfirmation() {
        let first = DataResetStep.chooseScope(.delete)
        XCTAssertEqual(first.choices, [.deleteEverything, .keepDocuments])
        XCTAssertEqual(first.action(for: .deleteEverything), .next(.finalConfirmation(.delete, keepDocuments: false)))
        XCTAssertEqual(first.action(for: .keepDocuments), .next(.finalConfirmation(.delete, keepDocuments: true)))

        for keep in [false, true] {
            let final = DataResetStep.finalConfirmation(.delete, keepDocuments: keep)
            XCTAssertEqual(final.choices, [.confirm])
            XCTAssertEqual(final.action(for: .confirm), .delete(keepDocuments: keep))
        }
    }

    func test_restore_offersKeepOrDeleteFirst() {
        let choice = DataResetStep.restoreChoice(folder)
        XCTAssertEqual(choice.choices, [.restoreAndKeep, .deleteThenRestore])
        XCTAssertEqual(choice.action(for: .restoreAndKeep), .restore(folder))
        XCTAssertEqual(choice.action(for: .deleteThenRestore), .next(.chooseScope(.replace(folder))))
        XCTAssertTrue(DataResetStep.Choice.restoreAndKeep.isDefault)
        XCTAssertFalse(DataResetStep.Choice.restoreAndKeep.isDestructive)
        XCTAssertTrue(DataResetStep.Choice.deleteThenRestore.isDestructive)
    }

    func test_deleteThenRestore_reusesTheDeleteStepsThenRestores() {
        let scope = DataResetStep.chooseScope(.replace(folder))
        XCTAssertEqual(scope.choices, [.deleteEverything, .keepDocuments])
        XCTAssertEqual(scope.action(for: .deleteEverything), .next(.finalConfirmation(.replace(folder), keepDocuments: false)))
        XCTAssertEqual(scope.action(for: .keepDocuments), .next(.finalConfirmation(.replace(folder), keepDocuments: true)))

        for keep in [false, true] {
            let final = DataResetStep.finalConfirmation(.replace(folder), keepDocuments: keep)
            XCTAssertEqual(final.choices, [.deleteThenRestore])
            XCTAssertEqual(final.action(for: .deleteThenRestore), .deleteThenRestore(folder, keepDocuments: keep))
        }
    }

    func test_everyStepMovesOnToADifferentStep() {
        // The dialog binding is tied to its step, so each button must change the step
        // (or end the flow) for the next dialog to show.
        let steps: [DataResetStep] = [
            .restoreChoice(folder), .chooseScope(.delete), .chooseScope(.replace(folder)),
            .finalConfirmation(.delete, keepDocuments: false), .finalConfirmation(.replace(folder), keepDocuments: true),
        ]
        for step in steps {
            for choice in step.choices {
                if case .next(let next) = step.action(for: choice) { XCTAssertNotEqual(next, step) }
            }
        }
    }

    func test_restoreFailure_afterDelete_saysTheDataWasAlreadyDeleted() {
        let cancelled = DataResetStep.restoreFailure(CancellationError(), afterDelete: true)
        XCTAssertEqual(cancelled.message, "Restore cancelled. Your data was already deleted, and nothing from the folder was added.")
        XCTAssertTrue(cancelled.isError)

        let failed = DataResetStep.restoreFailure(CocoaError(.fileReadCorruptFile), afterDelete: true)
        XCTAssertEqual(failed.message, "Restore failed. Your data was already deleted, and nothing from the folder was added.")
        XCTAssertTrue(failed.isError)
    }

    func test_restoreFailure_withoutDelete_saysNothingWasAdded() {
        let cancelled = DataResetStep.restoreFailure(CancellationError(), afterDelete: false)
        XCTAssertEqual(cancelled.message, "Restore cancelled. Nothing was added.")
        XCTAssertFalse(cancelled.isError)
        XCTAssertEqual(DataResetStep.restoreFailure(CocoaError(.fileReadCorruptFile), afterDelete: false).message,
                       "Restore failed. Nothing was added.")
        XCTAssertEqual(DataResetStep.restoreFailure(DataRestoreService.RestoreError.notAnExport, afterDelete: false).message,
                       DataRestoreService.RestoreError.notAnExport.localizedDescription)
    }
}
