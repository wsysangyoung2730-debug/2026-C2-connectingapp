//
//  QuestionEditorCard.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

import SwiftUI
import SwiftData

struct QuestionEditorCard: View {
    let selectedDate: Date
    let question: String
    
    @Binding var answerText: String
    let isFutureDate: Bool
    let hasSavedAnswer: Bool
    @Binding var isEditing: Bool
    
    let onSave: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var cardMinHeight: CGFloat? {
        isFutureDate ? 306.63708 : nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header
            
            Rectangle()
                .fill(Color(red: 0.85, green: 0.8, blue: 0.72))
                .frame(height: 0.81552)
            
            HStack {
                Text("선택 날짜")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(QuizDateHelper.fullDateString(selectedDate))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            if isFutureDate {
                futureStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                questionBody
            }
        }
        .padding(.horizontal, 17.12601)
        .padding(.top, 17.12601)
        .padding(.bottom, 17.12601)
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
        .background(Color(red: 1, green: 0.99, blue: 0.99))
        .cornerRadius(11.41734)
        .shadow(color: Color.black.opacity(0.06), radius: 3.2621, x: 0, y: 1.63105)
        
        .overlay(
            RoundedRectangle(cornerRadius: 11.41734)
                .inset(by: 0.41)
                .stroke(Color(red: 0.85, green: 0.8, blue: 0.72), lineWidth: 0.81552)
        )
    }
    
    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Image("question")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(Color(red: 0.37, green: 0.27, blue: 0.2))
                .scaledToFit()
                .frame(width: 16.31048, height: 16.31048)
            
            Text("Question")
                .font(
                    Font.custom("Inter", size: 14.67944)
                        .weight(.medium)
                )
                .foregroundColor(Color(red: 0.37, green: 0.27, blue: 0.2))
            
            Spacer()
            
            if hasSavedAnswer && !isEditing {
                HStack(spacing: 10) {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                    }
                    
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundColor(.primaryBrown)
                    }
                }
                .font(.system(size: 16, weight: .medium))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 4, alignment: .leading)
    }
    
    private var futureStateView: some View {
        VStack {
            Spacer()

            VStack(alignment: .center, spacing: 18) {
                Image("calendar_error")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)

                VStack(alignment: .center, spacing: 8) {
                    Text("아직 준비되지 않은 질문입니다.")
                        .font(Font.custom("Inter", size: 13.04839).weight(.bold))
                        .foregroundColor(Color(red: 0.37, green: 0.27, blue: 0.2))
                        .multilineTextAlignment(.center)

                    Text("오늘과 지난 날짜의 질문만 답변할 수 있어요.")
                        .font(Font.custom("Inter", size: 13.04839))
                        .foregroundColor(Color(red: 0.37, green: 0.27, blue: 0.2))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
    }
    
    private var questionBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Q. \(question)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primaryBrown)
                .padding(.top, 0)
            
            ZStack(alignment: .topLeading) {
                if answerText.isEmpty && isEditing {
                    Text("오늘의 경험을 자유롭게 남겨보세요.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.top, 14)
                        .padding(.leading, 12)
                }
                
                TextEditor(text: $answerText)
                    .font(.system(size: 15))
                    .foregroundColor(.primaryBrown)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 180)
                    .disabled(!isEditing)
                    .background(Color.appBackground.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            if isEditing {
                Button(action: onSave) {
                    Text("저장하기")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.primaryBrown)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
    
}

@MainActor
private var previewContainer: ModelContainer {
    let schema = Schema([
        QuizEntry.self
    ])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

    do {
        return try ModelContainer(for: schema, configurations: [configuration])
    } catch {
        fatalError("Preview ModelContainer 생성 실패: \(error)")
    }
}

#Preview("편집 상태") {
    struct PreviewWrapper: View {
        @State private var answerText: String = ""
        @State private var isEditing: Bool = true

        var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                QuestionEditorCard(
                    selectedDate: Date(),
                    question: "오늘 가장 인상 깊었던 순간은 무엇이었나요?",
                    answerText: $answerText,
                    isFutureDate: false,
                    hasSavedAnswer: false,
                    isEditing: $isEditing,
                    onSave: {},
                    onEdit: {},
                    onDelete: {}
                )
                .padding(20)
            }
            .modelContainer(previewContainer)
        }
    }

    return PreviewWrapper()
}

#Preview("저장 완료 상태") {
    struct PreviewWrapper: View {
        @State private var answerText: String = "오늘은 러닝 후에 친구와 대화했던 시간이 가장 기억에 남았어요."
        @State private var isEditing: Bool = false

        var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                QuestionEditorCard(
                    selectedDate: Date(),
                    question: "오늘 가장 인상 깊었던 순간은 무엇이었나요?",
                    answerText: $answerText,
                    isFutureDate: false,
                    hasSavedAnswer: true,
                    isEditing: $isEditing,
                    onSave: {},
                    onEdit: { isEditing = true },
                    onDelete: {}
                )
                .padding(20)
            }
            .modelContainer(previewContainer)
        }
    }

    return PreviewWrapper()
}

#Preview("미래 날짜 상태") {
    struct PreviewWrapper: View {
        @State private var answerText: String = ""
        @State private var isEditing: Bool = false

        var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                QuestionEditorCard(
                    selectedDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
                    question: "",
                    answerText: $answerText,
                    isFutureDate: true,
                    hasSavedAnswer: false,
                    isEditing: $isEditing,
                    onSave: {},
                    onEdit: {},
                    onDelete: {}
                )
                .padding(20)
            }
            .modelContainer(previewContainer)
        }
    }

    return PreviewWrapper()
}
