import SwiftUI

/// A folded sheet: the PAPER brand mark stays crisp at every size.
struct NaldamLogo: View {
    var size: CGFloat = 32
    var body: some View {
        ZStack {
            UnevenRoundedRectangle(topLeadingRadius: 7, bottomLeadingRadius: 7,
                                   bottomTrailingRadius: 7, topTrailingRadius: 16)
                .fill(Color.naldamAccent)
            FoldShape()
                .fill(Color.appBackground)
                .frame(width: size * 0.44, height: size * 0.44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: size * 0.84, height: size)
        .accessibilityHidden(true)
    }

    private struct FoldShape: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY * 0.75),
                                  control: CGPoint(x: 0, y: rect.maxY * 1.05))
                path.closeSubpath()
            }
        }
    }
}

struct NaldamAvatar: View {
    let name: String
    var size: CGFloat = 44
    var body: some View {
        Text(String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).isEmpty
             ? "나" : String(name.prefix(1)))
            .font(.system(size: size * 0.4, weight: .medium, design: .rounded))
            .foregroundStyle(Color.naldamInk)
            .frame(width: size, height: size)
            .background(Color.naldamLine.opacity(0.7), in: Circle())
            .accessibilityHidden(true)
    }
}

struct NaldamPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .foregroundStyle(.white)
            .background(Color.naldamAccent.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45),
                        in: RoundedRectangle(cornerRadius: 17))
            .contentShape(RoundedRectangle(cornerRadius: 17))
    }
}

struct NaldamCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.naldamLine, lineWidth: 0.8))
    }
}

extension View {
    func naldamCard() -> some View { modifier(NaldamCard()) }
}

struct NaldamSectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.weight(.bold)).foregroundStyle(Color.naldamInk)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Color.naldamSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NaldamEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.naldamAccent).padding(.bottom, 4)
            Text(title).font(.headline).foregroundStyle(Color.naldamInk)
            Text(message).font(.subheadline).foregroundStyle(Color.naldamSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 32).padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}
