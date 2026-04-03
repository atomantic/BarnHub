import SwiftUI

// MARK: - Shared helpers

private func isAllDay(_ date: Date) -> Bool {
    let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    return (comps.hour ?? 0) == 0 && (comps.minute ?? 0) == 0 && (comps.second ?? 0) == 0
}

private func hourLabel(_ hour: Int) -> String {
    guard hour > 0 else { return "" }
    var comps = DateComponents()
    comps.hour = hour
    comps.minute = 0
    guard let date = Calendar.current.date(from: comps) else { return "\(hour)" }
    return date.formatted(.dateTime.hour())
}

private func eventYOffset(_ date: Date, hourHeight: CGFloat) -> CGFloat {
    let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
    return CGFloat(comps.hour ?? 0) * hourHeight + CGFloat(comps.minute ?? 0) / 60.0 * hourHeight
}

// MARK: - Shared Event Row

struct ScheduleEventRow: View {
    let event: ScheduleEvent
    let onTap: () -> Void
    var showTime: Bool = true
    var verticalPadding: CGFloat = 8

    var body: some View {
        Button { onTap() } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.type.color)
                    .frame(width: 4, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    if let sub = event.subtitle {
                        Text(sub).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if showTime && !isAllDay(event.date) {
                        Text(event.date, format: .dateTime.hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Image(systemName: event.type.icon).font(.caption).foregroundStyle(event.type.color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, verticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar Month View

struct CalendarMonthView: View {
    let eventsByDay: [Date: [ScheduleEvent]]
    let monthStart: Date
    let selectedDate: Date
    let onDateSelected: (Date) -> Void
    let onEventTapped: (ScheduleEvent) -> Void
    var showEventsList: Bool = true

    @Environment(\.locale) private var locale
    private let cal = Calendar.current

    private var dayLabels: [String] {
        var c = Calendar(identifier: .gregorian)
        c.locale = locale
        return c.shortWeekdaySymbols
    }

    private var monthWeeks: [[Date?]] {
        guard let range = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = cal.component(.weekday, from: monthStart)
        var weeks: [[Date?]] = []
        var week: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for day in range {
            guard let date = cal.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            week.append(date)
            if week.count == 7 { weeks.append(week); week = [] }
        }
        if !week.isEmpty {
            while week.count < 7 { week.append(nil) }
            weeks.append(week)
        }
        return weeks
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }

            Divider()

            ForEach(Array(monthWeeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day {
                            monthDayCell(day)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 52)
                        }
                    }
                }
                Divider().opacity(0.3)
            }

            if showEventsList {
                Divider()
                selectedDayList
            } else {
                Spacer()
            }
        }
    }

    private func monthDayCell(_ date: Date) -> some View {
        let today = cal.startOfDay(for: .now)
        let day = cal.startOfDay(for: date)
        let isToday = day == today
        let isSelected = day == cal.startOfDay(for: selectedDate)
        let dayEvents = eventsByDay[day] ?? []
        let uniqueTypes = Array(Set(dayEvents.map(\.type))).sorted { $0.rawValue < $1.rawValue }

        return Button { onDateSelected(date) } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: date))")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : isSelected ? Color.barnGreen : .primary)
                    .frame(width: 28, height: 28)
                    .background {
                        Circle().fill(
                            isToday ? Color.barnGreen :
                            isSelected ? Color.barnGreen.opacity(0.15) : .clear
                        )
                    }
                HStack(spacing: 2) {
                    ForEach(uniqueTypes.prefix(3), id: \.self) { type in
                        Circle().fill(type.color).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var selectedDayList: some View {
        let day = cal.startOfDay(for: selectedDate)
        let dayEvents = (eventsByDay[day] ?? []).sorted { $0.date < $1.date }

        return VStack(alignment: .leading, spacing: 0) {
            Text(selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)

            if dayEvents.isEmpty {
                Text("No events")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(dayEvents) { event in
                            ScheduleEventRow(event: event, onTap: { onEventTapped(event) })
                            Divider().padding(.leading, 30)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Calendar Week View

struct CalendarWeekView: View {
    let eventsByDay: [Date: [ScheduleEvent]]
    let weekStart: Date
    let selectedDate: Date
    let onDateSelected: (Date) -> Void
    let onEventTapped: (ScheduleEvent) -> Void

    private let cal = Calendar.current
    private let hourHeight: CGFloat = 52
    private let timeColWidth: CGFloat = 44

    private var weekDays: [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        VStack(spacing: 0) {
            weekDayHeaders
            Divider()
            GeometryReader { geo in
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        weekTimeGrid(width: geo.size.width)
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            let hour = max(0, cal.component(.hour, from: .now) - 1)
                            proxy.scrollTo("whour-\(hour)", anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private var weekDayHeaders: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeColWidth)
            ForEach(weekDays, id: \.self) { day in
                let isToday = cal.isDateInToday(day)
                let isSelected = cal.startOfDay(for: day) == cal.startOfDay(for: selectedDate)
                Button { onDateSelected(day) } label: {
                    VStack(spacing: 2) {
                        Text(day, format: .dateTime.weekday(.short))
                            .font(.caption2)
                            .foregroundStyle(isToday ? Color.barnGreen : .secondary)
                        Text("\(cal.component(.day, from: day))")
                            .font(.caption.weight(isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? .white : isSelected ? Color.barnGreen : .primary)
                            .frame(width: 24, height: 24)
                            .background { Circle().fill(isToday ? Color.barnGreen : .clear) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func weekTimeGrid(width: CGFloat) -> some View {
        let dayWidth = (width - timeColWidth) / 7
        let totalHeight = CGFloat(24) * hourHeight

        return ZStack(alignment: .topLeading) {
            // Hour lines and labels
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 0) {
                        Text(hourLabel(hour))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: timeColWidth, alignment: .trailing)
                            .padding(.trailing, 4)
                            .offset(y: -7)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 0.5)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: hourHeight)
                    .id("whour-\(hour)")
                }
            }
            // Column separators
            ForEach(0..<8, id: \.self) { idx in
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 0.5, height: totalHeight)
                    .offset(x: timeColWidth + CGFloat(idx) * dayWidth)
            }
            // Events
            ForEach(Array(weekDays.enumerated()), id: \.offset) { idx, day in
                let timedEvents = (eventsByDay[cal.startOfDay(for: day)] ?? []).filter { !isAllDay($0.date) }
                ForEach(timedEvents) { event in
                    weekEventChip(
                        event: event,
                        xOffset: timeColWidth + CGFloat(idx) * dayWidth + 2,
                        width: dayWidth - 4
                    )
                    .onTapGesture { onEventTapped(event) }
                }
            }
            // Current time indicator
            if let todayIdx = weekDays.firstIndex(where: { cal.isDateInToday($0) }) {
                let y = eventYOffset(.now, hourHeight: hourHeight)
                HStack(spacing: 0) {
                    Circle().fill(.red).frame(width: 7, height: 7)
                    Rectangle().fill(.red).frame(width: dayWidth, height: 1.5)
                }
                .offset(x: timeColWidth + CGFloat(todayIdx) * dayWidth - 3, y: y)
            }
        }
        .frame(width: width, height: totalHeight)
    }

    private func weekEventChip(event: ScheduleEvent, xOffset: CGFloat, width: CGFloat) -> some View {
        let height = max(20, CGFloat(event.durationMinutes) / 60.0 * hourHeight)
        return RoundedRectangle(cornerRadius: 3)
            .fill(event.type.color.opacity(0.85))
            .frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                Text(event.title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(2)
            }
            .offset(x: xOffset, y: eventYOffset(event.date, hourHeight: hourHeight))
    }
}

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let events: [ScheduleEvent]
    let date: Date
    let onEventTapped: (ScheduleEvent) -> Void

    private let cal = Calendar.current
    private let hourHeight: CGFloat = 60
    private let timeColWidth: CGFloat = 52

    private var timedEvents: [ScheduleEvent] { events.filter { !isAllDay($0.date) } }
    private var allDayEvents: [ScheduleEvent] { events.filter { isAllDay($0.date) } }

    var body: some View {
        VStack(spacing: 0) {
            if !allDayEvents.isEmpty {
                allDayStrip
                Divider()
            }
            GeometryReader { geo in
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        dayTimeGrid(width: geo.size.width)
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            let hour = max(0, cal.component(.hour, from: .now) - 1)
                            proxy.scrollTo("dhour-\(hour)", anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private var allDayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("All-day")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: timeColWidth, alignment: .trailing)
                ForEach(allDayEvents) { event in
                    Button { onEventTapped(event) } label: {
                        Label(event.title, systemImage: event.type.icon)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(event.type.color))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func dayTimeGrid(width: CGFloat) -> some View {
        let contentWidth = width - timeColWidth
        let totalHeight = CGFloat(24) * hourHeight

        return ZStack(alignment: .topLeading) {
            // Hour lines and labels
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 0) {
                        Text(hourLabel(hour))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: timeColWidth, alignment: .trailing)
                            .padding(.trailing, 8)
                            .offset(y: -9)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 0.5)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: hourHeight)
                    .id("dhour-\(hour)")
                }
            }
            // Events
            ForEach(timedEvents) { event in
                dayEventBlock(event: event, contentWidth: contentWidth)
                    .onTapGesture { onEventTapped(event) }
            }
            // Current time indicator
            if cal.isDateInToday(date) {
                let y = eventYOffset(.now, hourHeight: hourHeight)
                HStack(spacing: 0) {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Rectangle().fill(.red).frame(width: contentWidth, height: 2)
                }
                .offset(x: timeColWidth - 5, y: y - 1)
            }
        }
        .frame(width: width, height: totalHeight)
    }

    private func dayEventBlock(event: ScheduleEvent, contentWidth: CGFloat) -> some View {
        let height = max(28, CGFloat(event.durationMinutes) / 60.0 * hourHeight)
        return RoundedRectangle(cornerRadius: 6)
            .fill(event.type.color.opacity(0.85))
            .frame(width: contentWidth - 4, height: height)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let sub = event.subtitle, height > 44 {
                        Text(sub).font(.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
            .offset(x: timeColWidth + 2, y: eventYOffset(event.date, hourHeight: hourHeight))
    }
}
