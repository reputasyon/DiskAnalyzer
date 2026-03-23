import Foundation
import SwiftUI

struct FileItem: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let url: URL
    let size: Int64
    let isDirectory: Bool
    let itemCount: Int
    let modificationDate: Date?
    var percentage: Double = 0
    var customIcon: String? = nil
    var customColor: Color? = nil
    var isCloudDownloaded: Bool = false

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var iconName: String {
        if let custom = customIcon { return custom }
        if isDirectory { return "folder.fill" }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift", "h", "m", "c", "cpp", "js", "ts", "py", "go", "rs", "java":
            return "chevron.left.forwardslash.chevron.right"
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "bmp", "svg":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv", "wmv", "m4v":
            return "film.fill"
        case "mp3", "wav", "aac", "m4a", "flac":
            return "music.note"
        case "pdf":
            return "doc.richtext.fill"
        case "zip", "tar", "gz", "rar", "7z", "dmg", "iso":
            return "doc.zipper"
        case "app":
            return "macwindow"
        case "txt", "md", "rtf", "log":
            return "doc.text.fill"
        case "json", "xml", "yaml", "yml", "plist":
            return "doc.badge.gearshape.fill"
        case "html", "css":
            return "globe"
        default:
            return "doc.fill"
        }
    }

    var iconColor: Color {
        if let custom = customColor { return custom }
        if isDirectory { return .blue }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "ts": return .yellow
        case "py": return .green
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return .mint
        case "mp4", "mov", "avi", "mkv": return .purple
        case "mp3", "wav", "aac", "m4a": return .pink
        case "pdf": return .red
        case "zip", "tar", "gz", "rar", "7z", "dmg", "iso": return .gray
        case "app": return .indigo
        default: return .secondary
        }
    }

    var sizeColor: Color {
        if size > 1_000_000_000 { return .red }
        if size > 100_000_000 { return .orange }
        if size > 10_000_000 { return .yellow }
        return .blue
    }
}
