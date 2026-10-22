import SwiftUI

struct TodayPromptCard: View {
    let question: String
    let buttonTitle: String
    var hasSavedEntry = false
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(hasSavedEntry ? "오늘 담은 기록" : "오늘의 질문").font(.caption).opacity(0.82)
            Text(question).font(.title3.weight(.semibold)).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack { footnote; Spacer(minLength: 8); action }
                VStack(alignment: .leading, spacing: 9) { footnote; action }
            }
        }
        .foregroundStyle(Color.naldamPaper).padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.naldamAccent, in: UnevenRoundedRectangle(
            topLeadingRadius: 21, bottomLeadingRadius: 21,
            bottomTrailingRadius: 21, topTrailingRadius: 55))
        .shadow(color: Color.naldamInk.opacity(0.05), radius: 12, y: 5)
    }
    private var footnote: some View {
        Text(hasSavedEntry ? "오늘의 마음을 다시 펼쳐봐요." : "짧은 한 줄이면 충분해요.")
            .font(.caption).opacity(0.85)
    }
    private var action: some View {
        HStack(spacing: 5) {
            Text(buttonTitle).font(.caption.weight(.semibold))
            Image(systemName: "arrow.up.right").font(.caption)
        }
    }
}
