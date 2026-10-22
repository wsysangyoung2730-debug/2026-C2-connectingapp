//
//  InterestTagCatalog.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/23/26.
//

import Foundation

enum InterestTagCatalog {
    static let defaultSuggestions = ["러닝", "건강", "기록", "독서", "음악", "산책", "사진", "디자인", "여행", "영화", "요리", "개발"]
    static let recommendedTags: [String] = [
        "러닝", "건강", "기록", "휴식", "독서", "한식",
        "마라톤", "헬스", "산책", "등산", "수영",
        "글쓰기", "영화", "음악", "사진", "전시",
        "여행", "카페", "맛집", "브랜딩", "디자인", "개발",
        "창업", "마케팅", "AI", "콘텐츠", "영상편집", "커뮤니티"
    ]

    static let maximumCount = 6
    static let maximumCustomLength = 5

    nonisolated static func cleaned(_ value: String) -> String {
        value.replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
    }

    static func uniqueTags(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.map(cleaned).filter {
            !$0.isEmpty && seen.insert($0.lowercased()).inserted
        }
    }

    static func selection(from values: [String]) -> [String] {
        Array(uniqueTags(values).prefix(maximumCount))
    }

    static func customTag(from value: String) -> String? {
        let tag = cleaned(value)
        guard !tag.isEmpty, tag.count <= maximumCustomLength,
              !tag.unicodeScalars.contains(where: {
                  $0.value < 0x20 || (0x7F...0x9F).contains($0.value) || CharacterSet.newlines.contains($0)
              }) else { return nil }
        return tag
    }

    static func filteredTags(query: String, additionalTags: [String] = []) -> [String] {
        let trimmed = cleaned(query)
        if trimmed.isEmpty { return uniqueTags(defaultSuggestions + additionalTags) }
        let tags = uniqueTags(defaultSuggestions + recommendedTags + additionalTags)
        return tags.filter {
            $0.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
