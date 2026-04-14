import SwiftUI
import UIKit

func processedProfileImageData(from image: UIImage) -> Data? {
    let maxDimension: CGFloat = 1_024
    let sourceSize = image.size
    let scale = min(1, maxDimension / max(sourceSize.width, sourceSize.height))
    let targetSize = CGSize(width: max(1, sourceSize.width * scale), height: max(1, sourceSize.height * scale))
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1

    let renderedImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: targetSize))
    }

    return renderedImage.jpegData(compressionQuality: 0.82)
}

func canUseCamera() -> Bool {
    UIImagePickerController.isSourceTypeAvailable(.camera)
}

struct ProfileAvatarBadge: View {
    let displayName: String?
    let imageData: Data?
    let size: CGFloat

    var body: some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.16))

                if let initials, !initials.isEmpty {
                    Text(initials)
                        .font(.system(size: size * 0.34, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.blue.opacity(0.75))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(Color.blue.opacity(0.75))
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var uiImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }

    private var initials: String? {
        guard let displayName else { return nil }
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let words = trimmedName
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)

        if !words.isEmpty {
            return words.compactMap { $0.first.map(String.init) }.joined().uppercased()
        }

        return String(trimmedName.prefix(2)).uppercased()
    }
}

struct ProfileImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let sourceType: UIImagePickerController.SourceType
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(image: $image, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        if sourceType == .camera {
            picker.cameraCaptureMode = .photo
        }
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding private var image: UIImage?
        private let dismiss: DismissAction

        init(image: Binding<UIImage?>, dismiss: DismissAction) {
            _image = image
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            dismiss()
        }
    }
}
