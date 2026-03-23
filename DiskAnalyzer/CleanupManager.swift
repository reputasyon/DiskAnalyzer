import Foundation
import SwiftUI
import AppKit

struct CleanupItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let color: Color
    let url: URL
    var size: Int64 = 0
    var isSelected: Bool = true

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    enum CleanAction {
        case deleteContents  // Delete contents of folder
        case deleteFolder    // Delete the folder itself
        case eraseSimulators // xcrun simctl erase all
        case npmCacheClean   // npm cache clean --force
    }

    let action: CleanAction
}

@MainActor
class CleanupManager: ObservableObject {
    @Published var items: [CleanupItem] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var statusMessage: String = ""
    @Published var totalCleanable: Int64 = 0

    private static let home = FileManager.default.homeDirectoryForCurrentUser

    static let cleanupTargets: [(String, String, String, Color, URL, CleanupItem.CleanAction)] = {
        let h = FileManager.default.homeDirectoryForCurrentUser
        return [
            ("Xcode DerivedData", "Derleme onbellegi — her build'de yeniden olusur", "hammer.fill", .orange,
             h.appendingPathComponent("Library/Developer/Xcode/DerivedData"), .deleteContents),

            ("Xcode Archives", "Eski build arsivleri (.ipa)", "archivebox.fill", .orange,
             h.appendingPathComponent("Library/Developer/Xcode/Archives"), .deleteFolder),

            ("iOS DeviceSupport", "Fiziksel cihaz debug dosyalari — cihaz baglayinca yeniden indirilir", "iphone.gen3", .orange,
             h.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"), .deleteFolder),

            ("Simulator Data", "Simulatorlerdeki uygulama verileri — simulatorler kalir, icindekiler silinir", "ipad.and.iphone", .purple,
             h.appendingPathComponent("Library/Developer/CoreSimulator/Devices"), .eraseSimulators),

            ("npm Cache", "npm paket indirme onbellegi — npm install yapinca tekrar indirilir", "shippingbox.fill", .green,
             h.appendingPathComponent(".npm"), .deleteContents),

            ("Homebrew Cache", "Homebrew paket indirme onbellegi", "mug.fill", .brown,
             h.appendingPathComponent("Library/Caches/Homebrew"), .deleteContents),

            ("Xcode Previews", "SwiftUI Preview onbellegi", "eye.fill", .blue,
             h.appendingPathComponent("Library/Developer/Xcode/UserData/Previews"), .deleteContents),

            ("CocoaPods Cache", "CocoaPods paket onbellegi", "cube.fill", .red,
             h.appendingPathComponent("Library/Caches/CocoaPods"), .deleteContents),

            ("Carthage Cache", "Carthage build onbellegi", "cart.fill", .indigo,
             h.appendingPathComponent("Library/Caches/org.carthage.CarthageKit"), .deleteContents),

            ("Swift Package Cache", "SPM paket onbellegi", "swift", .orange,
             h.appendingPathComponent("Library/Caches/org.swift.swiftpm"), .deleteContents),

            ("Gradle Cache", "Gradle/Android derleme onbellegi", "gearshape.2.fill", .green,
             h.appendingPathComponent(".gradle/caches"), .deleteContents),

            ("System Logs", "Sistem ve uygulama loglari", "doc.text.fill", .gray,
             h.appendingPathComponent("Library/Logs"), .deleteContents),

            ("System Caches", "Uygulama onbellekleri — uygulamalar ihtiyac duyunca yeniden olusturur", "tray.full.fill", .gray,
             h.appendingPathComponent("Library/Caches"), .deleteContents),
        ]
    }()

    func scan() {
        isScanning = true
        items = []
        statusMessage = "Temizlenebilir alanlar taranıyor..."

        Task {
            var found: [CleanupItem] = []

            for (name, desc, icon, color, url, action) in Self.cleanupTargets {
                statusMessage = "Taraniyor: \(name)..."

                let exists = FileManager.default.fileExists(atPath: url.path)
                guard exists else { continue }

                let size = await Task.detached {
                    DiskScanner.calculateDirectorySize(url).0
                }.value

                guard size > 1_000_000 else { continue } // Skip < 1 MB

                found.append(CleanupItem(
                    name: name,
                    description: desc,
                    icon: icon,
                    color: color,
                    url: url,
                    size: size,
                    action: action
                ))
            }

            items = found.sorted { $0.size > $1.size }
            totalCleanable = items.filter(\.isSelected).reduce(0) { $0 + $1.size }
            statusMessage = "\(items.count) temizlenebilir alan bulundu"
            isScanning = false
        }
    }

    func recalculateTotal() {
        totalCleanable = items.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    func cleanSelected() {
        isCleaning = true
        var cleaned = 0
        var freedSize: Int64 = 0

        for item in items where item.isSelected {
            statusMessage = "Temizleniyor: \(item.name)..."

            do {
                switch item.action {
                case .deleteContents:
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: item.url,
                        includingPropertiesForKeys: nil
                    )
                    for file in contents {
                        try? FileManager.default.removeItem(at: file)
                    }
                    cleaned += 1
                    freedSize += item.size

                case .deleteFolder:
                    try FileManager.default.removeItem(at: item.url)
                    cleaned += 1
                    freedSize += item.size

                case .eraseSimulators:
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                    process.arguments = ["simctl", "erase", "all"]
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        cleaned += 1
                        freedSize += item.size
                    }

                case .npmCacheClean:
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/npm")
                    process.arguments = ["cache", "clean", "--force"]
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        cleaned += 1
                        freedSize += item.size
                    }
                }
            } catch {
                continue
            }
        }

        let formattedFreed = ByteCountFormatter.string(fromByteCount: freedSize, countStyle: .file)
        statusMessage = "\(cleaned) alan temizlendi · \(formattedFreed) kazanildi"
        isCleaning = false

        // Rescan to update
        scan()
    }
}
