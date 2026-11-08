import Foundation

enum ContractType: String, CaseIterable, Identifiable {
    case boardingAgreement = "boarding"
    case liabilityWaiver = "liability"
    case careAgreement = "care"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .boardingAgreement: return appLocalized("Boarding Agreement", comment: "Contract type")
        case .liabilityWaiver:   return appLocalized("Liability Waiver",   comment: "Contract type")
        case .careAgreement:     return appLocalized("Care Agreement",     comment: "Contract type")
        }
    }

    var icon: String {
        switch self {
        case .boardingAgreement: return "house.fill"
        case .liabilityWaiver: return "shield.fill"
        case .careAgreement: return "heart.text.clipboard.fill"
        }
    }
}

/// Builds a contract PDF in two steps, so the slow part can run off the main
/// actor (#41): `document(…)` resolves every localized and formatted string on
/// the main actor, then `render(_:)` draws those plain values on any thread.
struct ContractPDFService {
    /// Everything the contract prints, already localized and formatted.
    struct Document: Sendable {
        struct PartyRow: Sendable {
            let label: String
            let value: String
        }

        let title: String
        let generatedLine: String
        let partyRows: [PartyRow]
        let termsHeader: String
        let terms: [String]
        let ownerSignatureLabel: String
        let managerSignatureLabel: String
        let dateLine: String
    }

    /// Resolves the contract's text. Main actor because currency formatting uses
    /// a shared formatter.
    @MainActor
    static func document(
        type: ContractType,
        clientName: String,
        clientPhone: String,
        clientEmail: String,
        emergencyContact: String,
        emergencyPhone: String,
        horseName: String,
        horseBreed: String,
        stallNumber: String,
        startDate: Date,
        monthlyRate: Double,
        generatedAt: Date = .now
    ) -> Document {
        let na = appLocalized("N/A", comment: "Not available placeholder in contract PDF")
        let partyRows: [Document.PartyRow] = [
            .init(label: "\(appLocalized("Client", comment: "Contract PDF label")):", value: clientName),
            .init(label: "\(appLocalized("Phone", comment: "Contract PDF label")):", value: clientPhone.isEmpty ? na : clientPhone),
            .init(label: "\(appLocalized("Email", comment: "Contract PDF label")):", value: clientEmail.isEmpty ? na : clientEmail),
            .init(label: "\(appLocalized("Emergency Contact", comment: "Contract PDF label")):", value: emergencyContact.isEmpty ? na : "\(emergencyContact) \(emergencyPhone)"),
            .init(label: "\(appLocalized("Horse", comment: "Contract PDF label")):", value: "\(horseName) (\(horseBreed.isEmpty ? appLocalized("Breed not specified", comment: "Fallback when horse breed is empty") : horseBreed))"),
            .init(label: "\(appLocalized("Stall", comment: "Contract PDF label")):", value: stallNumber.isEmpty ? appLocalized("TBD", comment: "To be determined placeholder") : stallNumber),
        ]

        let terms: [String]
        switch type {
        case .boardingAgreement:
            terms = boardingTerms(startDate: startDate, monthlyRate: monthlyRate)
        case .liabilityWaiver:
            terms = liabilityTerms()
        case .careAgreement:
            terms = careTerms(horseName: horseName)
        }

        return Document(
            title: "BarnHub \(type.displayName)",
            generatedLine: "\(appLocalized("Generated", comment: "PDF contract header label")): \(generatedAt.shortFormatted)",
            partyRows: partyRows,
            termsHeader: appLocalized("Terms and Conditions", comment: "Contract PDF section header"),
            terms: terms,
            ownerSignatureLabel: "\(appLocalized("Owner / Client", comment: "Contract PDF signature label")): \(clientName)",
            managerSignatureLabel: appLocalized("Barn Manager", comment: "Contract PDF signature label"),
            dateLine: "\(appLocalized("Date", comment: "Contract PDF date label")): _______________"
        )
    }

    // MARK: - Terms

    @MainActor
    private static func boardingTerms(startDate: Date, monthlyRate: Double) -> [String] {
        [
            appLocalized("1. TERM: This boarding agreement begins on %@ and continues on a month-to-month basis until terminated by either party with 30 days written notice.", comment: "Boarding contract term 1").replacingOccurrences(of: "%@", with: startDate.shortFormatted),
            appLocalized("2. BOARDING FEE: The monthly boarding fee is %@, due on the 1st of each month. Late payments are subject to a $25 late fee after the 10th.", comment: "Boarding contract term 2").replacingOccurrences(of: "%@", with: monthlyRate.asCurrency),
            appLocalized("3. SERVICES: Boarding includes daily feeding (grain and hay), fresh water, stall cleaning, turnout as weather permits, and basic monitoring of the horse's health.", comment: "Boarding contract term 3"),
            appLocalized("4. VETERINARY CARE: The Barn Manager may authorize emergency veterinary care if the Owner cannot be reached. The Owner is responsible for all veterinary costs.", comment: "Boarding contract term 4"),
            appLocalized("5. FARRIER: The Owner is responsible for scheduling and paying for farrier services. The Barn Manager may schedule farrier visits if the horse's hooves are neglected.", comment: "Boarding contract term 5"),
            appLocalized("6. DENTAL CARE: The Owner is responsible for scheduling and paying for equine dental services. The Barn Manager may schedule dentist visits if dental care appears overdue.", comment: "Boarding contract term 6"),
            appLocalized("7. INSURANCE: The Owner is strongly encouraged to maintain equine mortality and liability insurance. The Barn is not responsible for injury, illness, or death of the horse.", comment: "Boarding contract term 7"),
            appLocalized("8. TERMINATION: Either party may terminate with 30 days written notice. All outstanding fees must be settled before the horse is removed from the premises.", comment: "Boarding contract term 8"),
            appLocalized("9. GOVERNING LAW: This agreement is governed by the laws of the state in which the barn is located.", comment: "Boarding contract term 9"),
        ]
    }

    private static func liabilityTerms() -> [String] {
        [
            appLocalized("1. ASSUMPTION OF RISK: The undersigned acknowledges that equine activities involve inherent risks including but not limited to: bodily injury, property damage, and death. These risks cannot be eliminated regardless of the care taken.", comment: "Liability waiver term 1"),
            appLocalized("2. RELEASE: The undersigned hereby releases, waives, and discharges the Barn, its owners, employees, agents, and volunteers from any and all liability for injury, illness, death, or property damage arising from equine activities on the premises.", comment: "Liability waiver term 2"),
            appLocalized("3. INDEMNIFICATION: The undersigned agrees to indemnify and hold harmless the Barn from any claims, suits, or actions arising from the undersigned's participation in equine activities.", comment: "Liability waiver term 3"),
            appLocalized("4. EQUINE ACTIVITY LIABILITY: This release is governed by the applicable state's Equine Activity Liability Act, which provides that an equine activity sponsor is not liable for injuries resulting from the inherent risks of equine activities.", comment: "Liability waiver term 4"),
            appLocalized("5. MEDICAL AUTHORIZATION: In case of emergency, the undersigned authorizes the Barn to arrange for emergency medical treatment. The undersigned is responsible for all medical costs.", comment: "Liability waiver term 5"),
            appLocalized("6. PHOTO RELEASE: The undersigned grants permission for photographs taken during equine activities to be used for the Barn's promotional purposes.", comment: "Liability waiver term 6"),
            appLocalized("7. SEVERABILITY: If any provision of this waiver is held invalid, the remaining provisions shall continue in full force and effect.", comment: "Liability waiver term 7"),
            appLocalized("8. ACKNOWLEDGMENT: The undersigned has read this waiver, understands its terms, and signs it voluntarily.", comment: "Liability waiver term 8"),
        ]
    }

    private static func careTerms(horseName: String) -> [String] {
        [
            appLocalized("1. FEEDING: %@ shall receive grain and hay according to the feeding schedule specified by the Owner. Any dietary changes must be approved by the Owner in writing.", comment: "Care agreement term 1").replacingOccurrences(of: "%@", with: horseName),
            appLocalized("2. TURNOUT: %@ shall have daily turnout as weather and conditions permit. The Barn Manager will use best judgment regarding turnout during inclement weather.", comment: "Care agreement term 2").replacingOccurrences(of: "%@", with: horseName),
            appLocalized("3. VETERINARY CARE: Routine veterinary care (vaccinations, dental, deworming) is the Owner's responsibility to schedule. The Barn Manager will provide access and assist as needed.", comment: "Care agreement term 3"),
            appLocalized("4. FARRIER: Regular farrier visits shall be maintained on a schedule agreed upon by the Owner. The Barn Manager will notify the Owner if hoof care appears overdue.", comment: "Care agreement term 4"),
            appLocalized("5. DENTAL: Regular equine dental visits shall be maintained on a schedule agreed upon by the Owner. The Barn Manager will notify the Owner if dental care appears overdue.", comment: "Care agreement term 5"),
            appLocalized("6. MEDICATIONS: Any medications must be provided by the Owner with written instructions. The Barn Manager will administer as directed and log all medications given.", comment: "Care agreement term 6"),
            appLocalized("7. EXERCISE: Unless otherwise arranged, the Owner is responsible for the horse's exercise program. The Barn Manager provides basic daily monitoring only.", comment: "Care agreement term 7"),
            appLocalized("8. EMERGENCY PROCEDURES: In case of injury or illness, the Barn Manager will contact the Owner immediately. If the Owner cannot be reached, the emergency contact will be notified and emergency veterinary care may be authorized.", comment: "Care agreement term 8"),
            appLocalized("9. SPECIAL INSTRUCTIONS: Any special care requirements (supplements, blanketing, restricted turnout, etc.) must be provided in writing and updated as needed.", comment: "Care agreement term 9"),
        ]
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit

extension ContractPDFService {
    private static let headerColor = UIColor(red: 74/255, green: 124/255, blue: 63/255, alpha: 1)

    /// Draws `document` as PDF data. Reads nothing but its argument, so it's safe
    /// to call from a background task.
    static func render(_ document: Document) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            y = drawHeader(context: context, document: document, y: y, margin: margin, contentWidth: contentWidth)
            y = drawPartyInfo(context: context, rows: document.partyRows, y: y, margin: margin, contentWidth: contentWidth)
            y = drawTermsList(context: context, header: document.termsHeader, terms: document.terms, y: y, margin: margin, contentWidth: contentWidth, pageHeight: pageHeight)

            if y > pageHeight - 200 {
                context.beginPage()
                y = margin
            }
            drawSignatureBlock(context: context, document: document, y: y, margin: margin, contentWidth: contentWidth)
        }
    }

    static func fileName(type: ContractType, clientName: String) -> String {
        let safe = clientName.replacingOccurrences(of: " ", with: "_")
        return "BarnHub_\(type.displayName.replacingOccurrences(of: " ", with: "_"))_\(safe)_\(Date.now.shortFormatted.replacingOccurrences(of: "/", with: "-")).pdf"
    }

    // MARK: - Drawing Helpers

    private static func drawHeader(context: UIGraphicsPDFRendererContext, document: Document, y: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = y
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: headerColor
        ]
        (document.title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
        y += 32

        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        (document.generatedLine as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: dateAttrs)
        y += 20

        drawLine(context: context.cgContext, y: y, margin: margin, width: contentWidth)
        y += 16
        return y
    }

    private static func drawPartyInfo(context: UIGraphicsPDFRendererContext, rows: [Document.PartyRow], y: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = y
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]

        for row in rows {
            (row.label as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
            (row.value as NSString).draw(at: CGPoint(x: margin + 130, y: y), withAttributes: valueAttrs)
            y += 18
        }
        y += 10
        drawLine(context: context.cgContext, y: y, margin: margin, width: contentWidth)
        y += 16
        return y
    }

    private static func drawTermsList(context: UIGraphicsPDFRendererContext, header: String, terms: [String], y: CGFloat, margin: CGFloat, contentWidth: CGFloat, pageHeight: CGFloat) -> CGFloat {
        var y = y
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        (header as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttrs)
        y += 22

        let termAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.5),
            .foregroundColor: UIColor.darkGray
        ]

        for term in terms {
            let termStr = term as NSString
            let boundingRect = termStr.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: termAttrs,
                context: nil
            )
            let blockHeight = ceil(boundingRect.height) + 8

            if y + blockHeight > pageHeight - 80 {
                context.beginPage()
                y = margin
            }

            termStr.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: blockHeight), withAttributes: termAttrs)
            y += blockHeight
        }
        y += 10
        return y
    }

    private static func drawSignatureBlock(context: UIGraphicsPDFRendererContext, document: Document, y: CGFloat, margin: CGFloat, contentWidth: CGFloat) {
        let y = y + 20
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray
        ]
        let lineColor = UIColor.black.cgColor
        let ctx = context.cgContext
        let halfWidth = contentWidth / 2 - 20

        // Owner signature
        ctx.setStrokeColor(lineColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: y + 30))
        ctx.addLine(to: CGPoint(x: margin + halfWidth, y: y + 30))
        ctx.strokePath()
        (document.ownerSignatureLabel as NSString).draw(at: CGPoint(x: margin, y: y + 34), withAttributes: labelAttrs)

        (document.dateLine as NSString).draw(at: CGPoint(x: margin, y: y + 54), withAttributes: labelAttrs)

        // Barn Manager signature
        ctx.move(to: CGPoint(x: margin + halfWidth + 40, y: y + 30))
        ctx.addLine(to: CGPoint(x: margin + contentWidth, y: y + 30))
        ctx.strokePath()
        (document.managerSignatureLabel as NSString).draw(at: CGPoint(x: margin + halfWidth + 40, y: y + 34), withAttributes: labelAttrs)

        (document.dateLine as NSString).draw(at: CGPoint(x: margin + halfWidth + 40, y: y + 54), withAttributes: labelAttrs)
    }

    private static func drawLine(context: CGContext, y: CGFloat, margin: CGFloat, width: CGFloat) {
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: margin + width, y: y))
        context.strokePath()
    }
}

#else

extension ContractPDFService {
    static func render(_ document: Document) -> Data { Data() }

    static func fileName(type: ContractType, clientName: String) -> String {
        let safe = clientName.replacingOccurrences(of: " ", with: "_")
        return "BarnHub_\(type.displayName.replacingOccurrences(of: " ", with: "_"))_\(safe).pdf"
    }
}

#endif
