//
//  ExpandedCalendarView.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

import SwiftUI

struct ExpandedCalendarView: View {
    @Binding var selectedDate: Date

    @State private var visibleMonth: Date = Date()

    // Per-row fixed height for day cells + vertical spacing
    private let dayCellSize: CGFloat = 36.1188
    private let rowSpacing: CGFloat = 10
    private let weekdayHeaderHeight: CGFloat = 18

    private var numberOfRows: Int {
        // Calculate rows: leading blanks + days count divided by 7, rounded up, min 5, max 6
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: visibleMonth)
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return 6 }
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        let totalSlots = firstWeekday + range.count
        let rows = Int(ceil(Double(totalSlots) / 7.0))
        return max(5, min(6, rows))
    }

    private var extraHeightForSixRowMonth: CGFloat {
        max(0, CGFloat(numberOfRows - 5)) * (dayCellSize + rowSpacing)
    }

    // Use a constant max height so parent layouts (e.g., header/back button) don't shift when month rows change.
    private var cardHeight: CGFloat {
        // 5-row base (430) + one extra row height to match 6-row months
        430 + (dayCellSize + rowSpacing)
    }

    private var gridHeight: CGFloat {
        // weekday header + rows * cellHeight + (rows-1)*spacing
        let rows = CGFloat(numberOfRows)
        return weekdayHeaderHeight + (rows * dayCellSize) + ((rows - 1) * rowSpacing)
    }

    var body: some View {
        // Card container (expanding box)
        VStack(alignment: .leading, spacing: 13.04839) {
            // Top header: icon, title, fold button
            HStack(alignment: .center, spacing: 0) {
                Image("calendar")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color(red: 0.37, green: 0.27, blue: 0.2))
                    .frame(width: 16.31048, height: 16.31048)

                Text("Calendar")
                    .font(Font.custom("Inter", size: 14.67944).weight(.medium))
                    .foregroundColor(Color(red: 0.37, green: 0.27, blue: 0.2))
                    .padding(.leading, 8)

                Spacer(minLength: 0)


            }
            .padding(.horizontal, 1)
            .padding(.vertical, 0)
            .frame(maxWidth: .infinity, alignment: .top)
            
            Rectangle()
                .fill(Color(red: 0.85, green: 0.8, blue: 0.72).opacity(0.6))
                .frame(height: 0.81552)

            // Subtitle spacing placeholder
            Color.clear
                .frame(height: 16)
                .padding(.horizontal, 19.57258)
            
            Rectangle()
                .fill(Color(red: 0.85, green: 0.8, blue: 0.72).opacity(0.6))
                .frame(height: 0.81552)
                .padding(.horizontal, 19.57258)

            // Month bar: "April 2026" and chevrons
            HStack(alignment: .center, spacing: 0) {
                Button { moveMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 16.31048, height: 16.31048)
                }
                .buttonStyle(.plain)
                .tint(Color(red: 0.37, green: 0.27, blue: 0.2))

                Spacer(minLength: 0)

                Text(monthTitle(visibleMonth))
                    .font(Font.custom("Inter", size: 13.04839).weight(.medium))
                    .foregroundColor(Color(red: 0.37, green: 0.27, blue: 0.2))

                Spacer(minLength: 0)

                Button { moveMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 16.31048, height: 16.31048)
                }
                .buttonStyle(.plain)
                .tint(Color(red: 0.37, green: 0.27, blue: 0.2))
            }
            .padding(.horizontal, 19.57258)
            
            Rectangle()
                .fill(Color(red: 0.85, green: 0.8, blue: 0.72).opacity(0.6))
                .frame(height: 0.81552)
                .padding(.horizontal, 19.57258)

            // Calendar grid
            VStack(spacing: rowSpacing) {
                // Weekday symbols row (SUN ... SAT)
                let weekdaySymbols = ["SUN","MON","TUE","WED","THU","FRI","SAT"]
                HStack { ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }}
                .frame(height: weekdayHeaderHeight)

                // Days grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: rowSpacing) {
                    ForEach(daysForMonth(), id: \.self) { date in
                        if let date {
                            let isSelected = QuizDateHelper.isSameDay(date, selectedDate)
                            let isFuture = QuizDateHelper.isFuture(date)
                            let isToday = QuizDateHelper.isSameDay(date, QuizDateHelper.startOfDay(Date()))

                            Button {
                                selectedDate = date
                            } label: {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor({
                                        if isFuture { return Color.gray }
                                        if isSelected {
                                            // Selected text color should be dark on gray bg (non-today) and white on brown bg (today)
                                            return isToday ? Color.white : Color(red: 0.37, green: 0.27, blue: 0.2)
                                        }
                                        return Color(red: 0.37, green: 0.27, blue: 0.2)
                                    }())
                                    .frame(width: dayCellSize, height: dayCellSize)
                                    .background({
                                        if isSelected {
                                            return isToday ? Color(red: 0.55, green: 0.42, blue: 0.29) : Color(red: 0.89, green: 0.87, blue: 0.86)
                                        } else {
                                            return Color.clear
                                        }
                                    }())
                                    .cornerRadius(11.41734)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        } else {
                            Color.clear
                                .frame(height: dayCellSize)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: gridHeight)
            .padding(.horizontal, 19.57258)
        }
        .padding(.horizontal, 17.12601) //캘린더 내부 좌우 패딩
        .padding(.top, 17.12601)
        .padding(.bottom, 0.81552)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .background(Color(red: 1, green: 0.99, blue: 0.99))
        .cornerRadius(11.41734)
        .shadow(color: Color.black.opacity(0.06), radius: 3.2621, x: 0, y: 1.63105)
        .overlay(
            RoundedRectangle(cornerRadius: 11.41734)
                .inset(by: 0.41)
                .stroke(Color(red: 0.85, green: 0.8, blue: 0.72), lineWidth: 0.81552)
        )
        .onAppear { visibleMonth = selectedDate }
        .onChange(of: selectedDate) { _, newValue in
            // Keep visibleMonth synced if selectedDate jumps months externally
            if !Calendar.current.isDate(newValue, equalTo: visibleMonth, toGranularity: .month) {
                visibleMonth = newValue
            }
        }
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: date)
    }

    private func moveMonth(by value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: visibleMonth) {
            visibleMonth = next
        }
    }

    private func daysForMonth() -> [Date?] {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: visibleMonth)
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        var result: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in range {
            result.append(calendar.date(from: DateComponents(
                year: comps.year,
                month: comps.month,
                day: day
            )))
        }

        return result
    }
}
#Preview {
    struct PreviewHost: View {
        @State private var date: Date = Date()
        var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ExpandedCalendarView(selectedDate: $date)
                    .padding(20)
            }
        }
    }
    return PreviewHost()
}

