import Foundation

/// Builds Cloudinary delivery URLs with transformation parameters baked
/// into the path, so a single stored `secure_url` can serve a small
/// feed thumbnail in one place and a full-resolution view in another —
/// no extra upload or server round trip needed.
enum CloudinaryTransformation {

    /// Feed / grid thumbnail: fixed square crop, auto format + quality.
    static func thumbnail(_ url: String, size: Int = 400) -> String {
        insert("w_\(size),h_\(size),c_fill,g_auto,q_auto,f_auto", into: url)
    }

    /// Small round avatar crop.
    static func avatar(_ url: String, size: Int = 200) -> String {
        insert("w_\(size),h_\(size),c_fill,g_face,q_auto,f_auto,r_max", into: url)
    }

    /// Full-resolution display, still capped and auto-optimized so a
    /// post detail view doesn't pull down an untouched original.
    static func fullResolution(_ url: String, maxWidth: Int = 1600) -> String {
        insert("w_\(maxWidth),c_limit,q_auto,f_auto", into: url)
    }

    /// Still-frame thumbnail extracted from a video delivery URL. Cloudinary
    /// serves this off the same `/video/upload/...` path a video secure_url
    /// already has — swapping the file extension to `.jpg` on an
    /// otherwise-untouched video URL returns a JPEG frame instead of the
    /// video itself, no separate upload or transcode needed.
    static func videoThumbnail(_ url: String, size: Int = 400) -> String {
        let transformed = insert("w_\(size),h_\(size),c_fill,g_auto,q_auto,f_jpg", into: url)
        guard let dotRange = transformed.range(of: ".", options: .backwards) else { return transformed }
        return transformed.replacingCharacters(in: dotRange.lowerBound..<transformed.endIndex, with: ".jpg")
    }

    /// Inserts a transformation segment right after `/upload/` in a
    /// standard Cloudinary delivery URL. If the URL doesn't look like a
    /// Cloudinary URL (e.g. in unit tests, or a placeholder), returns it
    /// unchanged rather than producing a broken link.
    private static func insert(_ transformation: String, into url: String) -> String {
        guard let range = url.range(of: "/upload/") else { return url }
        var result = url
        result.replaceSubrange(range, with: "/upload/\(transformation)/")
        return result
    }
}
