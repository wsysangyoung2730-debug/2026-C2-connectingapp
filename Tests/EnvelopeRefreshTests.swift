import Foundation
import SwiftData
import Testing
import UIKit
@testable import C2_connecting_app

@Suite("봉투 개편과 최근 기록")
@MainActor
struct EnvelopeRefreshTests {
    @Test("해시·공백·대소문자 중복은 제거하고 서로 다른 6개를 보존한다")
    func sixUniqueInterests() {
        let tags = InterestTagCatalog.selection(from: [" #러닝 ", "러닝", "기록", "음악", "산책", "독서", "사진", "여행"])
        #expect(tags == ["러닝", "기록", "음악", "산책", "독서", "사진"])
        #expect(InterestTagCatalog.selection(from: ["AI", "ai", "#AI"]) == ["AI"])
    }

    @Test("직접 입력은 한글과 사용자 표시 문자 기준 5글자 이내로 검증한다")
    func validatesCustomInterest() {
        #expect(InterestTagCatalog.customTag(from: " #한글다섯자 ") == "한글다섯자")
        #expect(InterestTagCatalog.customTag(from: "여섯글자초과") == nil)
        #expect(InterestTagCatalog.customTag(from: "##  ") == nil)
        #expect(InterestTagCatalog.customTag(from: "나\n너") == nil)
        #expect(InterestTagCatalog.customTag(from: "🏃🏽‍♀️") == "🏃🏽‍♀️")
        #expect(InterestTagCatalog.filteredTags(query: "뜨개", additionalTags: ["뜨개질", "#뜨개질"]) == ["뜨개질"])
    }

    @Test("최근 기록은 빈 답변·미래·같은 날짜 중복을 제외하고 최신 5개만 선택한다")
    func recentFiveSavedDays() throws {
        let calendar = QuizDateHelper.calendar, today = calendar.startOfDay(for: .now)
        let dates = try (0..<8).map { offset in try #require(calendar.date(byAdding: .day, value: -offset, to: today)) }
        var entries = dates.enumerated().map { index, date in
            QuizEntry(date: date, question: "질문", answer: "기록 \(index)", updatedAt: today)
        }
        let future = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        entries.append(QuizEntry(date: future, question: "미래", answer: "표시하면 안 됨"))
        entries.append(QuizEntry(date: today, question: "빈 답변", answer: " \n "))
        entries.append(QuizEntry(date: dates[1], question: "질문", answer: "수정한 기록", updatedAt: today.addingTimeInterval(1)))
        let recent = RecentJournalEntries.select(from: entries.shuffled(), today: today)
        #expect(recent.map(\.answer) == ["기록 0", "수정한 기록", "기록 2", "기록 3", "기록 4"])
        #expect(RecentJournalEntries.select(from: [], today: today).isEmpty)
    }

    @Test("프로필 이미지는 비율을 유지한 작은 JPEG로 저장하고 잘못된 이미지는 거부한다")
    func photoEncoding() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 800)).image { context in
            UIColor.brown.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
        }
        let source = try #require(image.pngData())
        let data = try #require(ProfilePhotoEncoder.jpeg(from: source))
        let restored = try #require(UIImage(data: data))
        #expect(restored.size == CGSize(width: 600, height: 400))
        #expect(data.count < 100_000)
        #expect(ProfilePhotoEncoder.jpeg(from: Data("not an image".utf8)) == nil)
    }
}
