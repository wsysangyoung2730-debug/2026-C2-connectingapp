import SwiftUI
import PhotosUI
import UIKit

enum ProfilePhotoEncoder {
    static func jpeg(from data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(1, 600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }
}

struct NaldamProfilePhoto: View {
    @AppStorage("profilePhotoJPEG") private var photoData = Data()
    var width: CGFloat = 76
    var height: CGFloat = 96
    var body: some View {
        Group {
            if let image = UIImage(data: photoData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.rectangle")
                    .font(.system(size: width * 0.40, weight: .ultraLight))
                    .foregroundStyle(Color.naldamAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.linearGradient(colors: [.naldamSoft, .naldamEnvelopeLight], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.24))
        .accessibilityHidden(true)
    }
}

struct ProfilePhotoPicker: View {
    @AppStorage("profilePhotoJPEG") private var photoData = Data()
    @State private var selection: PhotosPickerItem?
    @State private var loading = false
    @State private var errorMessage: String?
    var width: CGFloat = 76
    var height: CGFloat = 96

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            NaldamProfilePhoto(width: width, height: height)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: loading ? "hourglass" : "camera.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.naldamAccent)
                        .frame(width: 24, height: 24)
                        .background(Color.naldamPaper, in: Circle())
                        .offset(x: 4, y: 4)
                }
        }
        .buttonStyle(.plain)
        .disabled(loading)
        .accessibilityLabel(photoData.isEmpty ? "내 프로필 사진 추가" : "내 프로필 사진 변경")
        .accessibilityIdentifier("profile.photo")
        .task(id: selection) {
            guard let selected = selection else { return }
            loading = true
            defer { loading = false }
            do {
                guard let data = try await selected.loadTransferable(type: Data.self), !Task.isCancelled,
                      let jpeg = ProfilePhotoEncoder.jpeg(from: data) else {
                    if !Task.isCancelled { errorMessage = "사진을 불러오지 못했어요. 다른 사진을 선택해 주세요." }
                    return
                }
                guard !Task.isCancelled else { return }
                photoData = jpeg
            } catch {
                if !Task.isCancelled { errorMessage = "사진을 불러오지 못했어요. 다시 선택해 주세요." }
            }
        }
        .alert("사진을 추가하지 못했어요", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}
