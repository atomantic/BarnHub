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

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit

struct ContractPDFService {
    private static let headerColor = UIColor(red: 74/255, green: 124/255, blue: 63/255, alpha: 1)

    static func generatePDF(
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
        monthlyRate: Double
    ) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            y = drawHeader(context: context, type: type, y: y, margin: margin, contentWidth: contentWidth)
            y = drawPartyInfo(context: context, clientName: clientName, clientPhone: clientPhone, clientEmail: clientEmail, emergencyContact: emergencyContact, emergencyPhone: emergencyPhone, horseName: horseName, horseBreed: horseBreed, stallNumber: stallNumber, y: y, margin: margin, contentWidth: contentWidth)

            switch type {
            case .boardingAgreement:
                y = drawBoardingTerms(context: context, startDate: startDate, monthlyRate: monthlyRate, y: y, margin: margin, contentWidth: contentWidth, pageHeight: pageHeight)
            case .liabilityWaiver:
                y = drawLiabilityTerms(context: context, y: y, margin: margin, contentWidth: contentWidth, pageHeight: pageHeight)
            case .careAgreement:
                y = drawCareTerms(context: context, horseName: horseName, y: y, margin: margin, contentWidth: contentWidth, pageHeight: pageHeight)
            }

            if y > pageHeight - 200 {
                context.beginPage()
                y = margin
            }
            drawSignatureBlock(context: context, clientName: clientName, y: y, margin: margin, contentWidth: contentWidth)
        }
    }

    static func fileName(type: ContractType, clientName: String) -> String {
        let safe = clientName.replacingOccurrences(of: " ", with: "_")
        return "BarnHub_\(type.displayName.replacingOccurrences(of: " ", with: "_"))_\(safe)_\(Date.now.shortFormatted.replacingOccurrences(of: "/", with: "-")).pdf"
    }

    // MARK: - Drawing Helpers

    private static func drawHeader(context: UIGraphicsPDFRendererContext, type: ContractType, y: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = y
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: headerColor
        ]
        ("BarnHub \(type.displayName)" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
        y += 32

        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        ("\(appLocalized("Generated", comment: "PDF contract header label")): \(Date.now.shortFormatted)" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: dateAttrs)
        y += 20

        drawLine(context: context.cgContext, y: y, margin: margin, width: contentWidth)
        y += 16
        return y
    }

    private static func drawPartyInfo(context: UIGraphicsPDFRendererContext, clientName: String, clientPhone: String, clientEmail: String, emergencyContact: String, emergencyPhone: String, horseName: String, horseBreed: String, stallNumber: String, y: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = y
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]

        let na = appLocalized("N/A", comment: "Not available placeholder in contract PDF")
        let rows: [(String, String)] = [
            ("\(appLocalized("Client", comment: "Contract PDF label")):", clientName),
            ("\(appLocalized("Phone", comment: "Contract PDF label")):", clientPhone.isEmpty ? na : clientPhone),
            ("\(appLocalized("Email", comment: "Contract PDF label")):", clientEmail.isEmpty ? na : clientEmail),
            ("\(appLocalized("Emergency Contact", comment: "Contract PDF label")):", emergencyContact.isEmpty ? na : "\(emergencyContact) \(emergencyPhone)"),
            ("\(appLocalized("Horse", comment: "Contract PDF label")):", "\(horseName) (\(horseBreed.isEmpty ? appLocalized("Breed not specified", comment: "Fallback when horse breed is empty") : horseBreed))"),
            ("\(appLocalized("Stall", comment: "Contract PDF label")):", stallNumber.isEmpty ? appLocalized("TBD", comment: "To be determined placeholder") : stallNumber),
        ]

        for (label, value) in rows {
            (label as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
            (value as NSString).draw(at: CGPoint(x: margin + 130, y: y), withAttributes: valueAttrs)
            y += 18
        }
        y += 10
        drawLine(context: context.cgContext, y: y, margin: margin, width: contentWidth)
        y += 16
        return y
    }

    private static func drawBoardingTerms(context: UIGraphicsPDFRendererContext, startDate: Date, monthlyRate: Double, y: CGFloat, margin: CGFloat, contentWidth: CGFloat, pageHeight: CGFloat) -> CGFloat {
        let terms = [
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
        return drawTermsList(context: context, terms: terms, y: y, margin: margin, contentWidth: contentWidth, pageHeight: pageHeight)
    }

    private static func drawLiabilityTerms(context: UIGraphicsPDFRendererContext, y: CGFloat, margin: CGFloat, contentWidth: CGFloat, pageHeight: CGFloat) -> CGFloat {
        let terms = [
            appLocalized("1. ASSUMPTION OF RISK: The undersigned acknowledges that equine activities involve inherent risks including but not limited to: bodily injury, property damage, and death. These risks cannot be eliminated regardless of the care taken.", comment: "Liability waiver term 1"),
            appLocalized("2. RELEASE: The undersigned hereby releases, waives, and discharges the Barn, its owners, employees, agents, and volunteers from any and all liability for injury, illness, death, or property damage arising from equine activities on the premises.", comment: "Liability waiver term 2"),
            appLocalized("3. INDEMNIFICATION: The undersigned agrees to indemnify and hold harmless the Barn from any claims, suits, or actions arising from the undersigned's participation in equine activities.", comment: "Liability waiver term 3"),
            appLocalized("4. EQUINE ACTIVITY LIABILITY: This release is governed by the applicable state's Equine Activity Liability Act, which provides that an equine activity sponsor is not liable for injuries resulting from the inherent risks of equine activities.", comment: "Liability waiver term 4"),
            appLocalized("5. MEDICAL AUTHORIZATION: In case of emergency, the undersigned authorizes the Barn to arrange for emergency medical treatment. The undersigned is responsible for all medical costs.", comment: "Liability waiver term 5"),
            appLocalized("6. PHOTO RELEASE: The undersigned grants permission for photographs taken during equine activities to be used for the Barn's promotional purposes.", comment: "Liability waiver term 6"),
            appLocalized("7. SEVERABILITY: If any provision of this waiver is held invalid, the remaining provisions shall continue in full force and effect.", comment: "Liability waiver term 7"),
            appLocalized("8. ACKNOWLEDGMENT: The undersigned has read this waiver, understands its terms, and signs it voluntarily.", comment: "Liability waiver term 8"),
        ]
        return drawTermsList(context: context, terms: terms, y: y, margin: margin, contentWidth: contentWidth, pageHeight: pageHeight)
    }

    private static func drawCareTerms(context: UIGraphicsPDFRendererContext, horseName: String, y: CGFloat, margin: CGFloat, contentWidth: CGFloat, pageHeight: CGFloat) -> CGFloat {
        let terms = [
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
        return drawTermsList(context: context, terms: terms, y: y, margin: margin, contentWidth: contentWidth, pageHeight: pageHeight)
    }

    private static func drawTermsList(context: UIGraphicsPDFRendererContext, terms: [String], y: CGFloat, margin: CGFloat, contentWidth: CGFloat, pageHeight: CGFloat) -> CGFloat {
        var y = y
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        (appLocalized("Terms and Conditions", comment: "Contract PDF section header") as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttrs)
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

    private static func drawSignatureBlock(context: UIGraphicsPDFRendererContext, clientName: String, y: CGFloat, margin: CGFloat, contentWidth: CGFloat) {
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
        ("\(appLocalized("Owner / Client", comment: "Contract PDF signature label")): \(clientName)" as NSString).draw(at: CGPoint(x: margin, y: y + 34), withAttributes: labelAttrs)

        ("\(appLocalized("Date", comment: "Contract PDF date label")): _______________" as NSString).draw(at: CGPoint(x: margin, y: y + 54), withAttributes: labelAttrs)

        // Barn Manager signature
        ctx.move(to: CGPoint(x: margin + halfWidth + 40, y: y + 30))
        ctx.addLine(to: CGPoint(x: margin + contentWidth, y: y + 30))
        ctx.strokePath()
        (appLocalized("Barn Manager", comment: "Contract PDF signature label") as NSString).draw(at: CGPoint(x: margin + halfWidth + 40, y: y + 34), withAttributes: labelAttrs)

        ("\(appLocalized("Date", comment: "Contract PDF date label")): _______________" as NSString).draw(at: CGPoint(x: margin + halfWidth + 40, y: y + 54), withAttributes: labelAttrs)
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

struct ContractPDFService {
    static func generatePDF(
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
        monthlyRate: Double
    ) -> Data { Data() }

    static func fileName(type: ContractType, clientName: String) -> String {
        let safe = clientName.replacingOccurrences(of: " ", with: "_")
        return "BarnHub_\(type.displayName.replacingOccurrences(of: " ", with: "_"))_\(safe).pdf"
    }
}

#endif
