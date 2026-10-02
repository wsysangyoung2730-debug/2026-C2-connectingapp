import SwiftUI

struct InterestPaperShape: Shape {
    func path(in rect: CGRect) -> Path {
        let archHeight = min(86, rect.height * 0.3)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: archHeight))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: archHeight),
            control: CGPoint(x: rect.midX, y: -archHeight)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct InterestEnvelopePocket: View {
    private let kraft = Color(red: 0.84, green: 0.74, blue: 0.62)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: width / 2, y: height * 0.64))
                    path.addLine(to: CGPoint(x: width, y: 0))
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [kraft.opacity(0.82), kraft], startPoint: .top, endPoint: .bottom))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    path.addLine(to: CGPoint(x: width * 0.47, y: height * 0.45))
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.53, y: height * 0.45),
                        control: CGPoint(x: width * 0.5, y: height * 0.36)
                    )
                    path.addLine(to: CGPoint(x: width, y: height))
                }
                .stroke(Color(red: 0.63, green: 0.49, blue: 0.35).opacity(0.48), lineWidth: 0.8)
            }
        }
    }
}

struct PaperInterestChip: View {
    let title: String
    var selected = false
    var selectionMark = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fixedSize(horizontal: true, vertical: false)
                if selected {
                    Image(systemName: selectionMark ? "checkmark" : "xmark")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .foregroundStyle(selected ? Color.naldamAccent : Color.naldamInk)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(selected ? Color.naldamAccent.opacity(0.10) : Color.appBackground, in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.naldamAccent.opacity(0.28) : Color.naldamLine.opacity(0.5), lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }
}

/// Wraps chips at their natural widths instead of truncating Korean labels.
struct InterestFlowLayout: Layout {
    var spacing: CGFloat = 8
    var centered = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let rows = rows(width: width, subviews: subviews)
        return CGSize(width: width, height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX + (centered ? max(0, (bounds.width - row.width) / 2) : 0)
            for element in row.elements {
                subviews[element.index].place(
                    at: CGPoint(x: x, y: y + (row.height - element.size.height) / 2),
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var elements: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var result: [Row] = []
        var row = Row()
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            let gap: CGFloat = row.elements.isEmpty ? 0 : spacing
            if !row.elements.isEmpty && row.width + gap + size.width > width {
                result.append(row)
                row = Row()
            }
            row.width += (row.elements.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.elements.append((index, size))
        }
        if !row.elements.isEmpty { result.append(row) }
        return result
    }
}
