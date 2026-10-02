import SwiftUI

struct SocialSampleBanner: View {
    var compact = false

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("샘플 체험").font(.caption.weight(.semibold))
                Text(compact ? "실제 상대에게 전송되지 않아요. 이 기기에만 저장돼요." : "아래 사람과 이야기는 가상의 예시예요. 대화 요청과 메시지는 이 기기에만 저장되며, 실제 사용자에게 전달되지 않아요.")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: "flask").foregroundStyle(Color.naldamAccent)
        }
        .foregroundStyle(Color.naldamSecondary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.naldamAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

struct SocialStorageWarning: View {
    let message: String?
    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(Color.naldamInk)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("저장 오류. \(message)")
        }
    }
}

struct SocialInterestTags: View {
    let tags: [String]
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { labels }
            VStack(alignment: .leading, spacing: 6) { labels }
        }
    }
    private var labels: some View {
        ForEach(tags, id: \.self) { tag in
            Text(tag)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.naldamInk)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.naldamLine.opacity(0.6), in: Capsule())
        }
    }
}

struct SocialPersonHeading: View {
    let person: SamplePerson
    var subtitle: String? = nil
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NaldamAvatar(name: person.name, size: 56)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(person.name).font(.title3.weight(.bold))
                    Text("샘플").font(.caption2.weight(.medium)).foregroundStyle(Color.naldamSecondary)
                }
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(Color.naldamSecondary)
                } else {
                    SocialInterestTags(tags: person.interests)
                }
            }
        }
        .foregroundStyle(Color.naldamInk)
    }
}
