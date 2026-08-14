import UIKit

/// Client-side resize + compress before anything goes over the network.
/// This is the piece that keeps uploads fast on cellular and keeps
/// Cloudinary free-tier storage/bandwidth under control — there is no
/// server to do this for us on the Spark plan.
enum ImageCompressor {

    /// Resizes so the longest edge is at most `maxDimension`, then
    /// re-encodes as JPEG at `quality`. Returns nil if the image can't
    /// be decoded or re-encoded.
    static func compress(
        _ image: UIImage,
        maxDimension: CGFloat = 1600,
        quality: CGFloat = 0.75
    ) -> Data? {
        let resized = resize(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }

    /// Convenience overload for raw picker `Data` (e.g. from PhotosPicker's
    /// `Data.self` transferable) — decodes, resizes, re-encodes.
    static func compress(
        data: Data,
        maxDimension: CGFloat = 1600,
        quality: CGFloat = 0.75
    ) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return compress(image, maxDimension: maxDimension, quality: quality)
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longestEdge = max(image.size.width, image.size.height)
        guard longestEdge > maxDimension else { return image }

        let scale = maxDimension / longestEdge
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // we already computed the target pixel size
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
