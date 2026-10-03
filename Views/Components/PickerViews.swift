import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

/// 文件选择器包装（用于选择全格式漫画文件）
struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // 全格式支持：CBZ/CBR/CB7/CBT/ZIP/RAR/7z/TAR/ePub/PDF + 图片
        let allExtensions = ["cbz", "zip", "cbr", "rar", "cb7", "7z", "cbt", "tar", "gz", "tgz", "bz2", "tbz", "xz", "txz", "epub", "pdf"]
        var types: [UTType] = []
        for ext in allExtensions {
            if let ut = UTType(filenameExtension: ext) {
                types.append(ut)
            }
        }
        types.append(.image)
        types.append(.pdf)
        types.append(.zip)
        // 去重
        types = Array(Set(types))
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

/// 多图选择器包装
struct ImagePickerView: UIViewControllerRepresentable {
    let onPick: ([URL], String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image])
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !urls.isEmpty else { return }
            // 用第一张图的文件名作为漫画标题
            let title = urls.first?.deletingPathExtension().lastPathComponent ?? "导入的漫画"
            parent.onPick(urls, title)
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

/// 相册选图器（用于更换封面），基于 PHPickerViewController
struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPickerView

        init(_ parent: PhotoLibraryPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                parent.dismiss()
                return
            }
            let itemProvider = result.itemProvider
            guard itemProvider.canLoadObject(ofClass: UIImage.self) else {
                parent.dismiss()
                return
            }
            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                DispatchQueue.main.async {
                    if let uiImage = image as? UIImage {
                        self?.parent.onPick(uiImage)
                    }
                    self?.parent.dismiss()
                }
            }
        }
    }
}
