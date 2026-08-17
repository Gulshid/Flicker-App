import SwiftUI
import PhotosUI
import UIKit

/// Sheet for posting a new story, reached from the "+" ring at the start
/// of StoryTrayView. Two separate PhotosPicker buttons (photo vs. video)
/// rather than one mixed picker — keeps the "which kind did they pick"
/// question answered by which button they tapped instead of sniffing
/// content types after the fact.
struct CreateStoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CreateStoryViewModel()
    @State private var photoSelection: PhotosPickerItem?
    @State private var videoSelection: PhotosPickerItem?
    @State private var previewImageData: Data?

    var onPosted: (Story) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                preview

                if case .failed(let message) = viewModel.state {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if case .idle = viewModel.state {
                    pickerButtons
                }
            }
            .padding()
            .navigationTitle("New Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") {
                        Task {
                            if let story = await viewModel.post() {
                                onPosted(story)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canPost || viewModel.isPosting)
                }
            }
            .onChange(of: photoSelection) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        previewImageData = data
                    }
                    await viewModel.pickedPhoto(newItem)
                }
            }
            .onChange(of: videoSelection) { _, newItem in
                guard let newItem else { return }
                previewImageData = nil
                Task { await viewModel.pickedVideo(newItem) }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.85))
                .aspectRatio(9 / 16, contentMode: .fit)

            switch viewModel.state {
            case .idle:
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                    Text("Pick a photo or video below")
                        .font(.footnote)
                }
                .foregroundStyle(.white.opacity(0.6))
            case .loading, .uploading:
                VStack(spacing: 10) {
                    if let previewImageData, let uiImage = UIImage(data: previewImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .opacity(0.5)
                    }
                    ProgressView()
                        .tint(.white)
                }
            case .uploaded:
                if let previewImageData, let uiImage = UIImage(data: previewImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                        Text("Video ready")
                            .font(.footnote)
                    }
                    .foregroundStyle(.white)
                }
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow)
            }
        }
        .frame(maxWidth: 260)
    }

    private var pickerButtons: some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: $photoSelection, matching: .images) {
                Label("Photo", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            PhotosPicker(selection: $videoSelection, matching: .videos) {
                Label("Video", systemImage: "video")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}
