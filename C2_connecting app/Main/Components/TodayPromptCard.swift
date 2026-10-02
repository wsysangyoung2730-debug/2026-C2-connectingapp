//
//  TodayPromptCard.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

import SwiftUI

struct VariableRoundedRectangle: Shape {
    var tl: CGFloat = 0
    var tr: CGFloat = 0
    var bl: CGFloat = 0
    var br: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.size.width
        let h = rect.size.height
        let tr = min(min(self.tr, h/2), w/2)
        let tl = min(min(self.tl, h/2), w/2)
        let bl = min(min(self.bl, h/2), w/2)
        let br = min(min(self.br, h/2), w/2)

        path.move(to: CGPoint(x: w / 2.0, y: 0))
        path.addLine(to: CGPoint(x: w - tr, y: 0))
        path.addArc(center: CGPoint(x: w - tr, y: tr), radius: tr, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addArc(center: CGPoint(x: w - br, y: h - br), radius: br, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: bl, y: h))
        path.addArc(center: CGPoint(x: bl, y: h - bl), radius: bl, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: tl))
        path.addArc(center: CGPoint(x: tl, y: tl), radius: tl, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        path.closeSubpath()

        return path
    }
}

struct TodayPromptCard: View {
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 17) {
                Text("상영님의\n오늘 하루는 어땠어요?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                
                Text("다른 러너들과 이야기를 나누고\n서로의 순간에 연결될 수 있어요")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Text("작성하러 가기")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 17)
            .padding(.top, 20)
            .padding(.bottom, 15)
            .frame(width: 368, alignment: .center)
        }
        .background(Color.primaryBrown)
        .clipShape(VariableRoundedRectangle(tl: 30, tr: 80, bl: 30, br: 30))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

#Preview {
    TodayPromptCard()
        .padding()
        .background(Color.appBackground)
}
