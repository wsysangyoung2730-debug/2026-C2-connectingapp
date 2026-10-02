import SwiftUI

struct TodayPromptCard: View {
    let question: String
    let buttonTitle: String
    var hasSavedEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(hasSavedEntry ? "오늘 담은 기록" : "오늘의 질문", systemImage: hasSavedEntry ? "checkmark.circle" : "sparkle")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.naldamAccent).padding(.trailing, 28)
            Text(question).font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Color.naldamInk).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
            Text(hasSavedEntry ? "다시 읽으며 오늘의 마음을 돌아보세요." : "짧은 한 줄도 괜찮아요.")
                .font(.subheadline).foregroundStyle(Color.naldamSecondary)
            Label("나만 보기 · 이 기기에 저장", systemImage: "lock.fill")
                .font(.caption).foregroundStyle(Color.naldamSecondary)
            HStack {
                Spacer()
                Text(buttonTitle).font(.body.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(.white).padding(16)
            .background(Color.naldamAccent, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(22)
        .background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 25))
        .overlay(alignment: .topTrailing) {
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 17,
                                   bottomTrailingRadius: 0, topTrailingRadius: 25)
                .fill(.linearGradient(colors: [.naldamLine, .appBackground], startPoint: .bottomLeading, endPoint: .topTrailing))
                .frame(width: 40, height: 40).accessibilityHidden(true)
        }
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.naldamLine.opacity(0.6), lineWidth: 0.8))
        .shadow(color: Color.naldamInk.opacity(0.035), radius: 12, y: 5)
    }
}
