import SwiftUI

struct SocialStorageWarning: View {
    let message: String?
    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.footnote).foregroundStyle(Color.naldamInk)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityElement(children: .combine)
        }
    }
}

struct SocialInterestTags: View {
    let tags: [String]
    var body: some View {
        InterestFlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text("#\(tag)").font(.caption.weight(.medium))
                    .foregroundStyle(Color.naldamAccent)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.naldamSoft, in: Capsule())
            }
        }
    }
}

struct ChatPersonPortrait: View {
    let person: ChatProfile
    var size: CGFloat = 56
    var body: some View {
        Text(String(person.name.prefix(1)))
            .font(.system(size: size * 0.40, weight: .medium, design: .rounded))
            .foregroundStyle(Color.naldamAccent)
            .frame(width: size, height: size * 1.08)
            .background(Color.naldamSoft, in: RoundedRectangle(cornerRadius: size * 0.32))
            .accessibilityHidden(true)
    }
}

struct SocialPersonHeading: View {
    let person: ChatProfile
    var subtitle: String? = nil
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ChatPersonPortrait(person: person, size: 52)
            VStack(alignment: .leading, spacing: 6) {
                Text(person.name).font(.title3.weight(.bold))
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(Color.naldamSecondary)
                } else {
                    SocialInterestTags(tags: person.interests)
                }
            }
        }.foregroundStyle(Color.naldamInk)
    }
}
