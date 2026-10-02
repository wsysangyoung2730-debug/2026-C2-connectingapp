//
//  QuizPageView.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

import SwiftUI
import SwiftData

struct QuizPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var entries: [QuizEntry] //SwiftData에 저장한 QuizEntry 읽어옴

    @State private var selectedDate: Date = QuizDateHelper.startOfDay(Date()) //사용자가 보고 있는 날짜 결정
    @State private var showingExpandedCalendar = false
    @State private var draftAnswer: String = "" //사용자 편집중인 텍스트
    @State private var isEditing = false //읽기 모드 vs 편집 모드
    @State private var showDeleteAlert = false // 삭제 확인창

    private var selectedEntry: QuizEntry? {
        entries.first {
            QuizDateHelper.isSameDay($0.date, selectedDate)
        }
    }

    private var selectedQuestion: String {
        DailyQuestionProvider.question(for: selectedDate)
    }

    private var isFutureDate: Bool {
        QuizDateHelper.isFuture(selectedDate)
    }

    private var hasSavedAnswer: Bool {
        guard let entry = selectedEntry else { return false }
        return !entry.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Group {
                        if showingExpandedCalendar {
                            VStack {
                                ExpandedCalendarView(selectedDate: $selectedDate)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                                        removal: .opacity
                                    ))
                                Button {
                                    withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
                                        showingExpandedCalendar = false
                                    }
                                } label: {
                                    Text("캘린더 접기 ▲")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(red: 0.55, green: 0.42, blue: 0.29))
                                        .frame(maxWidth: .infinity)
                                }
                                .padding(.top, 6)
                            }
                        } else {
                            CompactWeekCalendarCard(
                                selectedDate: $selectedDate,
                                onTapDetail: {
                                    withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
                                        showingExpandedCalendar = true
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                            ))
                        }
                    }
                    .animation(.snappy(duration: 0.18, extraBounce: 0), value: showingExpandedCalendar)

                    QuestionEditorCard(
                        selectedDate: selectedDate,
                        question: selectedQuestion,
                        answerText: $draftAnswer,
                        isFutureDate: isFutureDate,
                        hasSavedAnswer: hasSavedAnswer,
                        isEditing: $isEditing,
                        onSave: saveEntry,
                        onEdit: beginEditing,
                        onDelete: { showDeleteAlert = true }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            QuizHeaderView(
                title: "오늘의 경험",
                onBack: { dismiss() }
            )
            .background(Color.appBackground)
        }
        .navigationBarBackButtonHidden(true)
        .alert("답변을 삭제하시겠습니까?", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("삭제된 내용은 복구할 수 없습니다. \n정말 삭제하시겠습니까?")
        }
        .onAppear {
            syncDraftFromSelectedDate()
        }
        .onChange(of: selectedDate) { _, _ in
            syncDraftFromSelectedDate()
        }
    }

    private func syncDraftFromSelectedDate() {
        if let entry = selectedEntry {
            draftAnswer = entry.answer
            isEditing = false
        } else {
            draftAnswer = ""
            isEditing = !isFutureDate
        }
    }

    private func beginEditing() {
        if !isFutureDate {
            isEditing = true
        }
    }

    private func saveEntry() {
        guard !isFutureDate else { return }

        let trimmed = draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let entry = selectedEntry {
            entry.answer = trimmed
            entry.question = selectedQuestion
            entry.updatedAt = Date()
        } else {
            let newEntry = QuizEntry(
                date: QuizDateHelper.startOfDay(selectedDate),
                question: selectedQuestion,
                answer: trimmed
            )
            modelContext.insert(newEntry)
        }

        isEditing = false
    }

    private func deleteEntry() {
        guard let entry = selectedEntry else { return }
        modelContext.delete(entry)
        draftAnswer = ""
        isEditing = true
    }
}

#Preview {
    QuizPageView()
}
