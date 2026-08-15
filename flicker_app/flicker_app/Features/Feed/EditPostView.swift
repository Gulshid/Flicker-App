import SwiftUI

/// Caption-only edit sheet. Media is treated as immutable once posted —
/// re-uploading/reordering media on an existing post is a much bigger
/// surface (Cloudinary has no delete-on-unsigned-preset story either) and
/// isn't part of the Phase 5/6 scope, so a post owner who wants different
/// media deletes and re-posts instead.
struct EditPostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var caption: String
    var onSave: (String?) -> Void

    init(caption: String?, onSave: @escaping (String?) -> Void) {
        _caption = State(initialValue: caption ?? "")
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Caption") {
                    TextField("Write a caption…", text: $caption, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Edit Caption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmed.isEmpty ? nil : trimmed)
                        dismiss()
                    }
                }
            }
        }
    }
}
