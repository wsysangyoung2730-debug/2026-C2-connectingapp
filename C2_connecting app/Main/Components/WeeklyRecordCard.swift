//
//  WeeklyRecordCard.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

// 추가 기능 : 날짜갯수 count해서 연속기록일 표시, 실제 주간 데이터값 표시

import SwiftUI

struct WeeklyRecordCard: View {
    private let days: [WeekDayItem] = [
        .init(day: "월", isChecked: true, isHighlighted: false),
        .init(day: "화", isChecked: false, isHighlighted: false),
        .init(day: "수", isChecked: true, isHighlighted: true),
        .init(day: "목", isChecked: false, isHighlighted: false),
        .init(day: "금", isChecked: false, isHighlighted: false),
        .init(day: "토", isChecked: false, isHighlighted: false),
        .init(day: "일", isChecked: false, isHighlighted: false)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이번 주")
                .font(.system(size: 21, weight: .medium))
                .foregroundColor(Color(red: 0.37, green: 0.27, blue: 0.20))

            Text("2일 연속 기록중")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0.43, green: 0.42, blue: 0.40))

            HStack(spacing: 0) {
                ForEach(days) { item in
                    WeekDayStatusView(item: item)

                    if item.id != days.last?.id {
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(.leading, 16)
        .padding(.trailing, 18)
        .padding(.top, 17)
        .padding(.bottom, 21)
        .frame(maxWidth: .infinity, minHeight: 159, maxHeight: 159, alignment: .topLeading)
        .background(Color(red: 1.0, green: 0.99, blue: 0.99))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color(red: 0.85, green: 0.80, blue: 0.72), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

struct WeekDayItem: Identifiable {
    let id = UUID()
    let day: String
    let isChecked: Bool
    let isHighlighted: Bool
}

struct WeekDayStatusView: View {
    let item: WeekDayItem

    var body: some View {
        VStack(spacing: 2.8) {
            Text(item.day)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.black)
                .frame(width: 19.28889, height: 22.04445, alignment: .center)

            ZStack {
                Circle()
                    .stroke(
                        item.isChecked ? Color.clear : Color.primaryBrown,
                        lineWidth: 1
                    )
                    .background(
                        Circle()
                            .fill(item.isChecked ? Color.primaryBrown : Color.clear)
                    )
                    .frame(width: 18, height: 18)

                if item.isChecked {
                    Image("check")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(0)
        .frame(width: 44.1, height: 62, alignment: .center)
        .background(
            item.isHighlighted
            ? Color(red: 0.94, green: 0.92, blue: 0.89)
            : Color.white
        )
        .clipShape(RoundedRectangle(cornerRadius: 41.3, style: .continuous))
    }
}

#Preview {
    WeeklyRecordCard()
        .padding()
        .background(Color(red: 0.96, green: 0.95, blue: 0.92))
}
