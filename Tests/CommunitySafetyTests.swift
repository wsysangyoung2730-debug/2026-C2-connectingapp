import Testing
@testable import C2_connecting_app

@Suite("공개 콘텐츠의 기본 안전 필터")
struct CommunitySafetyTests {
    @Test("일반적인 기록과 관심사는 허용한다")
    func permitsOrdinaryConversation() {
        for text in ["오늘 산책해서 좋았어요", "러닝", "사진 📷", "함께 이야기해요!", "밝은 하루"] {
            #expect(CommunitySafety.permits(text))
        }
    }
    @Test("공백·구두점·대소문자·문자 폭을 이용한 기본 우회를 막는다")
    func normalizesBeforeChecking() {
        for text in ["씨 발", "씨.발", "ＦＵＣＫ", "F.u.C.k", "죽여버리겠다"] {
            #expect(!CommunitySafety.permits(text))
        }
    }
}
