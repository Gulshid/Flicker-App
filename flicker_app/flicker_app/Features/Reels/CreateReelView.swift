import SwiftUI
import PhotosUI

/// Sheet for posting a new reel, reached from the camera icon in
/// ReelsView's toolbar. Single video picker + caption — deliberately
/// much simpler than CreatePostView since a reel is always exactly one
/// clip.
struct CreateReelView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CreateReelViewModel()
    @State private var videoSelection: PhotosPickerItem?

    var onPosted: (Post) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    picker
                }

                Section("Caption") {
                    TextField("Write a caption…", text: $viewModel.caption, axis: .vertical)
                        .lineLimit(3...8)
                }

                if case .failed(let message) = viewModel.state {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Reel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            if let post = await viewModel.submit() {
                                onPosted(post)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canPost || viewModel.isPosting)
                }
            }
            .onChange(of: videoSelection) { _, newItem in
                guard let newItem else { return }
                Task { await viewModel.pickedVideo(newItem) }
            }
        }
    }

    @ViewBuilder
    private var picker: some View {
        switch viewModel.state {
        case .idle:
            PhotosPicker(selection: $videoSelection, matching: .videos) {
                HStack {
                    Image(systemName: "video.badge.plus")
                    Text("Choose a video")
                }
            }
        case .loading:
            HStack {
                ProgressView()
                Text("Loading video…")
                    .foregroundStyle(.secondary)
            }
        case .uploading(let progress):
            VStack(alignment: .leading, spacing: 6) {
                Text("Uploading…")
                    .foregroundStyle(.secondary)
                ProgressView(value: progress)
            }
        case .uploaded:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Video ready")
                Spacer()
                PhotosPicker(selection: $videoSelection, matching: .videos) {
                    Text("Change")
                        .font(.footnote)
                }
            }
        case .failed:
            PhotosPicker(selection: $videoSelection, matching: .videos) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try a different video")
                }
            }
        }
    }
}
