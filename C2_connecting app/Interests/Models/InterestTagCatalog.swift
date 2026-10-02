//
//  InterestTagCatalog.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/23/26.
//

import Foundation

enum InterestTagCatalog {
    static let recommendedTags: [String] = [
        "러닝", "마라톤", "헬스", "산책", "등산", "수영",
        "독서", "글쓰기", "영화", "음악", "사진", "전시",
        "여행", "카페", "맛집", "브랜딩", "디자인", "개발",
        "창업", "마케팅", "AI", "콘텐츠", "영상편집", "커뮤니티"
    ]

    static func filteredTags(query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return recommendedTags }

        return recommendedTags.filter {
            $0.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
