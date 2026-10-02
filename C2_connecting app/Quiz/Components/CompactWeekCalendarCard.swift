//
//  CompactWeekCalendarCard.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

import SwiftUI

struct CompactWeekCalendarCard: View {
    @Binding var selectedDate: Date
    var onTapDetail: () -> Void

    private var weekDates: [Date] {
        QuizDateHelper.weekDates(containing: selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image("calendar")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color(red: 0.37, green: 0.27, blue: 0.2))
                    .frame(width: 16.31048, height: 16.31048)

                Text("Calendar")
                    .font(Font.custom("Inter", size: 14.67944).weight(.medium))
                    .foregroundColor(Color(red: 0.37, green: 0.27, blue: 0.2))

                Spacer()

                Button(action: onTapDetail) {
                    Text("전체 보기 ▼")
                        .font(Font.custom("SF Pro Text", size: 11))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(red: 0.73, green: 0.65, blue: 0.57))
                }
                .buttonStyle(.plain)
            }

            // Divider line under header
            Rectangle()
                .fill(Color(red: 0.85, green: 0.8, blue: 0.72))
                .frame(height: 1)

            // Week days row
            HStack(spacing: 6) {
                ForEach(weekDates, id: \.self) { date in
                    let isSelected = QuizDateHelper.isSameDay(date, selectedDate)
                    let isFuture = QuizDateHelper.isFuture(date)
                    let isToday = QuizDateHelper.isSameDay(date, QuizDateHelper.startOfDay(Date()))

                    Button {
                        selectedDate = date
                    } label: {
                        VStack(alignment: .center, spacing: 6) {
                            Text(QuizDateHelper.weekdaySymbol(for: date))
                                .font(Font.custom("Inter", size: 11).weight(.medium))

                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(Font.custom("Inter", size: 14).weight(.medium))
                        }
                        .foregroundColor({
                            if isFuture { return Color.gray }
                            if isSelected {
                                // today -> white on brown, non-today -> brown on gray
                                return isToday ? Color.white : Color(red: 0.37, green: 0.27, blue: 0.2)
                            }
                            return Color(red: 0.37, green: 0.27, blue: 0.2)
                        }())
                        .padding(10)
                        .frame(width: 36, height: 63, alignment: .top)
                        .background({
                            if isSelected {
                                return isToday
                                    ? Color(red: 0.55, green: 0.42, blue: 0.29) // brown for today
                                    : Color(red: 0.89, green: 0.87, blue: 0.86) // gray for non-today
                            } else {
                                return (isFuture
                                        ? Color.gray.opacity(0.12)
                                        : Color(red: 0.94, green: 0.92, blue: 0.89))
                            }
                        }())
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    // Vertical separator between cells
                    if date != weekDates.last {
                        Rectangle()
                            .fill(Color(red: 0.85, green: 0.8, blue: 0.72).opacity(0.6))
                            .frame(width: 4, height: 36)
                            .opacity(0.0) // keep layout note; remove if you want visible thicker separators
                    }
                }
            }
        }
        .padding(.horizontal, 17.12601)
        .padding(.top, 17.12601)
        .padding(.bottom, 0.81552)
        .frame(maxWidth: .infinity, minHeight: 145.5, maxHeight: 145.5, alignment: .topLeading)
        .background(Color(red: 1, green: 0.99, blue: 0.99))
        .cornerRadius(11.41734)
        .shadow(color: Color.black.opacity(0.06), radius: 3.2621, x: 0, y: 1.63105)
        .overlay(
            RoundedRectangle(cornerRadius: 11.41734)
                .inset(by: 0.41)
                .stroke(Color(red: 0.85, green: 0.8, blue: 0.72), lineWidth: 0.81552)
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedDate: Date = Date()
        var body: some View {
            CompactWeekCalendarCard(selectedDate: $selectedDate) {
                // preview action
                print("전체 보기")
            }
            .padding()
            .background(Color.appBackground)
        }
    }
    return PreviewWrapper()
}
