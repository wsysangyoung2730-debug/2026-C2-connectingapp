import SwiftUI

enum NaldamLegal {
    static let privacyURL = URL(string: "https://connectingapp-site.vercel.app/")!
    static let supportURL = URL(string: "https://connectingapp-site.vercel.app/#contact")!
    static let termsURL = URL(string: "https://connectingapp-site.vercel.app/#terms")!
}

struct NaldamLegalLinks: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) { links }
            VStack(spacing: 4) { links }
        }
        .font(.footnote)
        .tint(.naldamAccent)
    }

    @ViewBuilder private var links: some View {
        Link("개인정보처리방침", destination: NaldamLegal.privacyURL)
            .frame(minHeight: 44).accessibilityIdentifier("legal.privacy")
        Link("문의 및 신고", destination: NaldamLegal.supportURL)
            .frame(minHeight: 44).accessibilityIdentifier("legal.support")
        Link("이용약관", destination: NaldamLegal.termsURL)
            .frame(minHeight: 44).accessibilityIdentifier("legal.terms")
    }
}
