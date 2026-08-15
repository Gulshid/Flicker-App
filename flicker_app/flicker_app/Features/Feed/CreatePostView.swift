import SwiftUI
import PhotosUI
import UIKit

/// New-post sheet, presented from FeedView's toolbar button. Photos are
/// picked, compressed, and uploaded to Cloudinary as soon as they're
/// selected (not on submit) — Post is only visible while every item
/// finishes uploading, so tapping Post is just the Firestore write.
struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CreatePostViewModel()
    @State private var pickerSelection: [PhotosPickerItem] = []

    var onPosted: (Post) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    mediaGrid
                }

                Section("Caption") {
                    TextField("Write a caption…", text: $viewModel.caption, axis: .vertical)
                        .lineLimit(3...8)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Post")
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
                    .disabled(!viewModel.canPost)
                }
            }
        }
    }

    private var mediaGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.items) { item in
                    mediaTile(item)
                }

                if viewModel.items.count < viewModel.maxItems {
                    PhotosPicker(
                        selection: $pickerSelection,
                        maxSelectionCount: viewModel.maxItems - viewModel.items.count,
                        matching: .images
                    ) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.secondary.opacity(0.1))
                            .frame(width: 96, height: 96)
                            .overlay(Image(systemName: "plus").font(.title2).foregroundStyle(.secondary))
                    }
                    .onChange(of: pickerSelection) { _, newItems in
                        guard !newItems.isEmpty else { return }
                        Task {
                            await viewModel.addItems(newItems)
                            pickerSelection = []
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets())
        .padding(.horizontal)
    }

    @ViewBuilder
    private func mediaTile(_ item: CreatePostViewModel.MediaItem) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let uiImage = UIImage(data: item.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.secondary.opacity(0.1)
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                viewModel.remove(itemId: item.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(4)

            overlay(for: item)
        }
    }

    @ViewBuilder
    private func overlay(for item: CreatePostViewModel.MediaItem) -> some View {
        switch item.state {
        case .compressing:
            ProgressView()
                .frame(width: 96, height: 96)
                .background(.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        case .uploading(let progress):
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .frame(width: 96, height: 96)
                .background(.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        case .failed:
            VStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Button("Retry") {
                    Task { await viewModel.retry(itemId: item.id) }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
            }
            .frame(width: 96, height: 96)
            .background(.black.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        case .uploaded:
            EmptyView()
        }
    }
}
