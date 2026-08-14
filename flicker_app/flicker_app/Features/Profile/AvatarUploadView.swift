import SwiftUI
import PhotosUI

/// Reusable avatar picker + upload progress + retry-on-failure UI.
/// Wraps a `MediaUploadService` instance so any screen that needs an
/// image upload (profile avatar here, post media in Phase 5) gets the
/// same picker → compressing → uploading → success/retry behavior for free.
struct AvatarUploadView: View {
    let currentAvatarURL: String?
    var onUploaded: (String) -> Void

    @State private var uploader = MediaUploadService()
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                avatarPreview
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.separator, lineWidth: 1))

                if case .compressing = uploader.state {
                    ProgressView()
                } else if case .uploading = uploader.state {
                    ProgressView(value: uploader.progress)
                        .progressViewStyle(.circular)
                }
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text(currentAvatarURL == nil ? "Add Photo" : "Change Photo")
                    .font(.footnote.weight(.semibold))
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    await uploader.upload(item: newItem)
                }
            }

            if case .uploading = uploader.state {
                Text("Uploading… \(Int(uploader.progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if case .failed(let message) = uploader.state {
                VStack(spacing: 4) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("Retry") {
                        Task { await uploader.retry() }
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .onChange(of: uploader.state) { _, newState in
            if case .success(let url) = newState {
                onUploaded(url)
            }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let urlString = currentAvatarURL.map({ CloudinaryTransformation.avatar($0) }),
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(.secondary.opacity(0.15))
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
            )
    }
}
