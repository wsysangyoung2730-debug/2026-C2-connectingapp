import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentStep = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let pages: [(String, String, String)] = [
        ("오늘의 나를 담다.", "하루 하나의 질문에 답하며\n나를 알아가는 작은 기록을 쌓아요.", "square.and.pencil"),
        ("좋아하는 것에서\n시작하는 연결", "관심사를 종이에 담아보세요.\n나와 닮은 이야기를 발견할 수 있어요.", "envelope.open"),
        ("기록은 나만,\n연결은 천천히", "내 기록은 이 기기에만 저장돼요.\n발견과 대화는 아직 샘플 체험이며\n메시지는 실제 상대에게 전송되지 않아요.", "lock.open")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                NaldamLogo(size: 28)
                Text("날담").font(.title2.weight(.bold))
                Spacer()
                if currentStep < 2 {
                    Button("건너뛰기") { changeStep(2) }
                        .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                }
            }.padding(24)
            ScrollView {
                VStack(spacing: 28) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 32).fill(Color.naldamPaper)
                            .rotationEffect(.degrees(-7)).frame(width: 172, height: 208)
                            .shadow(color: Color.naldamInk.opacity(0.05), radius: 16, y: 8)
                        Image(systemName: pages[currentStep].2)
                            .font(.system(size: 64, weight: .ultraLight)).foregroundStyle(Color.naldamAccent)
                    }.frame(height: 230).padding(.top, 28).accessibilityHidden(true)
                    Text(pages[currentStep].0)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    Text(pages[currentStep].1).font(.body).lineSpacing(6)
                        .foregroundStyle(Color.naldamSecondary).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if currentStep == 2 {
                        Text("앱 삭제 시 기록이 사라질 수 있어요.\n계정 동기화와 복원은 아직 제공하지 않아요.")
                            .font(.caption).foregroundStyle(Color.naldamSecondary)
                            .multilineTextAlignment(.center).padding(16)
                            .background(Color.naldamLine.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                    }
                }.padding(.horizontal, 24).padding(.bottom, 24)
            }
            VStack(spacing: 24) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Capsule().fill(index == currentStep ? Color.naldamAccent : Color.naldamLine)
                            .frame(width: index == currentStep ? 24 : 7, height: 7)
                    }
                }.accessibilityLabel("소개 \(currentStep + 1)/3")
                Button(currentStep == 2 ? "나의 첫 장 시작하기" : "다음") {
                    if currentStep == 2 { hasCompletedOnboarding = true }
                    else { changeStep(currentStep + 1) }
                }
                .buttonStyle(NaldamPrimaryButtonStyle()).accessibilityIdentifier("onboarding.next")
            }.padding(24)
        }
        .foregroundStyle(Color.naldamInk).background(Color.appBackground)
    }
    private func changeStep(_ step: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { currentStep = step }
    }
}
