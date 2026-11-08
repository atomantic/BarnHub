import SwiftUI

extension View {
    /// Registers the screen for every route type, for a tab's stack or a form sheet.
    func withRouteDestinations() -> some View {
        self
            .navigationDestination(for: HomeRoute.self) { $0.destination }
            .navigationDestination(for: HorseRoute.self) { $0.destination }
            .navigationDestination(for: ClientRoute.self) { $0.destination }
            .navigationDestination(for: AccountingRoute.self) { $0.destination }
            .navigationDestination(for: BarnRoute.self) { $0.destination }
            .navigationDestination(for: SubscriptionRoute.self) { $0.destination }
    }
}

// MARK: - Route destinations

extension HomeRoute {
    /// The screen this route shows, whether pushed or presented as a form sheet,
    /// behind the upgrade view when it needs Pro.
    @MainActor @ViewBuilder
    var destination: some View {
        ProGated(feature: requiredProFeature) {
            switch self {
            case .horses: HorseListView()
            case .clients: ClientListView()
            case .schedule: BarnDashboardView()
            case .supplies: SupplyListView()
            case .accounting: AccountingDashboardView()
            case .reports: ReportsView()
            case .barnNotes: BarnNoteListView()
            case .settings: SettingsView()
            case .dataManagement: DataManagementView()
            }
        }
    }
}

extension HorseRoute {
    /// The screen this route shows, whether pushed or presented as a form sheet,
    /// behind the upgrade view when it needs Pro.
    @MainActor @ViewBuilder
    var destination: some View {
        ProGated(feature: requiredProFeature) {
            switch self {
            case .list: HorseListView()
            case .detail(let id): HorseDetailView(horseID: id)
            case .edit(let id): HorseEditView(horseID: id)
            case .addVetRecord(let id): VetRecordEditView(horseID: id)
            case .addFarrierVisit(let id): FarrierVisitEditView(horseID: id)
            case .addDentistVisit(let id): DentistVisitEditView(horseID: id)
            case .editVetRecord(let id): VetRecordEditView(horseID: nil, recordID: id)
            case .editFarrierVisit(let id): FarrierVisitEditView(horseID: nil, visitID: id)
            case .editDentistVisit(let id): DentistVisitEditView(horseID: nil, visitID: id)
            case .healthTimeline(let id): HealthTimelineView(horseID: id)
            case .weightChart(let id): WeightChartView(horseID: id)
            case .documents(let id): HorseDocumentsView(horseID: id)
            case .feedPlan(let id): HorseFeedPlanView(horseID: id)
            case .editFeedEntry(let horseID, let entryID): FeedPlanEntryEditView(horseID: horseID, entryID: entryID)
            }
        }
    }
}

extension ClientRoute {
    /// The screen this route shows, whether pushed or presented as a form sheet,
    /// behind the upgrade view when it needs Pro.
    @MainActor @ViewBuilder
    var destination: some View {
        ProGated(feature: requiredProFeature) {
            switch self {
            case .list: ClientListView()
            case .detail(let id): ClientDetailView(clientID: id)
            case .edit(let id): ClientEditView(clientID: id)
            case .manageHorses(let id): ClientHorsesView(clientID: id)
            case .invoiceHistory(let id): InvoiceHistoryView(clientID: id)
            case .paymentHistory(let id): ClientPaymentHistoryView(clientID: id)
            case .documents(let id): ClientDocumentsView(clientID: id)
            }
        }
    }
}

extension AccountingRoute {
    /// The screen this route shows, whether pushed or presented as a form sheet,
    /// behind the upgrade view when it needs Pro.
    @MainActor @ViewBuilder
    var destination: some View {
        ProGated(feature: requiredProFeature) {
            switch self {
            case .list: TransactionListView()
            case .edit(let id): TransactionEditView(transactionID: id)
            }
        }
    }
}

extension BarnRoute {
    /// The screen this route shows, whether pushed or presented as a form sheet,
    /// behind the upgrade view when it needs Pro.
    @MainActor @ViewBuilder
    var destination: some View {
        ProGated(feature: requiredProFeature) {
            switch self {
            case .supplies: SupplyListView()
            case .supplyEdit(let id): SupplyEditView(supplyItemID: id)
            case .reminders: ReminderListView()
            case .reminderEdit(let id): ReminderEditView(reminderID: id)
            case .barnNotes: BarnNoteListView()
            case .barnNoteEdit(let id): BarnNoteEditView(noteID: id)
            case .vetSchedule: VetScheduleView()
            case .addVetRecord: VetRecordEditView(horseID: nil)
            case .farrierSchedule: FarrierScheduleView()
            case .addFarrierVisit: FarrierVisitEditView(horseID: nil)
            case .dentistSchedule: DentistScheduleView()
            case .addDentistVisit: DentistVisitEditView(horseID: nil)
            case .lessons: LessonListView()
            case .lessonEdit(let id): LessonEditView(lessonID: id)
            case .feedProducts: FeedProductListView()
            case .feedProductEdit(let id): FeedProductEditView(productID: id)
            }
        }
    }
}

extension SubscriptionRoute {
    /// The screen this route shows, whether pushed or presented as a form sheet,
    /// behind the upgrade view when it needs Pro.
    @MainActor @ViewBuilder
    var destination: some View {
        ProGated(feature: requiredProFeature) {
            switch self {
            case .paywall: PaywallView()
            }
        }
    }
}
