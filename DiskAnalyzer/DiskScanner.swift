import SwiftUI
import AppKit

struct DiskInfo {
    let totalSize: Int64
    let freeSize: Int64
    var usedSize: Int64 { totalSize - freeSize }
    var usedPercentage: Double { totalSize > 0 ? Double(usedSize) / Double(totalSize) : 0 }

    var formattedTotal: String { ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file) }
    var formattedUsed: String { ByteCountFormatter.string(fromByteCount: usedSize, countStyle: .file) }
    var formattedFree: String { ByteCountFormatter.string(fromByteCount: freeSize, countStyle: .file) }
}

struct QuickLocation: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let url: URL
}

@MainActor
class DiskScanner: ObservableObject {
    @Published var items: [FileItem] = []
    @Published var isScanning = false
    @Published var currentURL: URL?
    @Published var navigationStack: [URL] = []
    @Published var statusMessage: String = ""
    @Published var totalSize: Int64 = 0
    @Published var sortOrder: SortOrder = .size
    @Published var showHidden: Bool = false
    @Published var diskInfo: DiskInfo?
    @Published var isOverview: Bool = true
    @Published var scanProgress: ScanProgress = ScanProgress()

    struct ScanProgress {
        var scannedCount: Int = 0
        var currentFolder: String = ""
        var foundSize: Int64 = 0
        var isActive: Bool = false
    }

    // MARK: - Cache
    private var cache: [URL: CacheEntry] = [:]
    private var overviewCache: CacheEntry?

    private struct CacheEntry {
        let items: [FileItem]
        let totalSize: Int64
        let timestamp: Date

        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < 300 // 5 dakika
        }
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case size = "Boyut"
        case name = "İsim"
        case date = "Tarih"
        var id: String { rawValue }
    }

    var quickLocations: [QuickLocation] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            QuickLocation(name: "Ana Klasör", icon: "house.fill", color: .blue, url: home),
            QuickLocation(name: "Uygulamalar", icon: "macwindow", color: .indigo, url: URL(fileURLWithPath: "/Applications")),
            QuickLocation(name: "Library", icon: "books.vertical.fill", color: .purple, url: home.appendingPathComponent("Library")),
            QuickLocation(name: "Developer", icon: "hammer.fill", color: .orange, url: home.appendingPathComponent("Library/Developer")),
            QuickLocation(name: "İndirilenler", icon: "arrow.down.circle.fill", color: .green, url: home.appendingPathComponent("Downloads")),
            QuickLocation(name: "Masaüstü", icon: "menubar.dock.rectangle", color: .cyan, url: home.appendingPathComponent("Desktop")),
            QuickLocation(name: "Belgeler", icon: "doc.fill", color: .yellow, url: home.appendingPathComponent("Documents")),
            QuickLocation(name: "iCloud Drive", icon: "icloud.fill", color: .blue, url: home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")),
            QuickLocation(name: "Sistem", icon: "gearshape.fill", color: .gray, url: URL(fileURLWithPath: "/System")),
            QuickLocation(name: "Geçici", icon: "clock.fill", color: .red, url: URL(fileURLWithPath: "/private/var")),
        ]
    }

    // MARK: - Init

    func loadDiskInfo() {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = attrs[.systemSize] as? Int64 ?? 0
            let free = attrs[.systemFreeSize] as? Int64 ?? 0
            diskInfo = DiskInfo(totalSize: total, freeSize: free)
        } catch {
            diskInfo = nil
        }
    }

    func scanOverview(forceRefresh: Bool = false) {
        isOverview = true
        navigationStack = []
        currentURL = nil
        loadDiskInfo()

        // Check cache
        if !forceRefresh, let cached = overviewCache, cached.isValid {
            items = cached.items
            totalSize = cached.totalSize
            statusMessage = "\(items.count) konum · Toplam: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))"
            isScanning = false
            return
        }

        let locations = quickLocations
        isScanning = true
        scanProgress = ScanProgress(isActive: true)
        items = []
        statusMessage = "Disk analiz ediliyor..."

        Task {
            for (index, loc) in locations.enumerated() {
                scanProgress.currentFolder = loc.name
                scanProgress.scannedCount = index

                let (size, count) = await Task.detached {
                    Self.calculateDirectorySize(loc.url)
                }.value

                let item = FileItem(
                    name: loc.name,
                    url: loc.url,
                    size: size,
                    isDirectory: true,
                    itemCount: count,
                    modificationDate: nil,
                    customIcon: loc.icon,
                    customColor: loc.color
                )
                items.append(item)
                scanProgress.foundSize += size

                // Recalculate percentages
                let maxSize = items.map(\.size).max() ?? 1
                for i in items.indices {
                    items[i].percentage = maxSize > 0 ? Double(items[i].size) / Double(maxSize) : 0
                }

                statusMessage = "\(index + 1)/\(locations.count) · \(loc.name) tarandı · \(ByteCountFormatter.string(fromByteCount: scanProgress.foundSize, countStyle: .file))"
            }

            totalSize = items.reduce(0) { $0 + $1.size }
            statusMessage = "\(items.count) konum tarandı · Toplam: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))"
            overviewCache = CacheEntry(items: items, totalSize: totalSize, timestamp: Date())
            scanProgress.isActive = false
            isScanning = false
        }
    }

    // MARK: - Folder Selection

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Analiz edilecek klasörü seçin"
        panel.prompt = "Analiz Et"

        if panel.runModal() == .OK, let url = panel.url {
            isOverview = false
            navigationStack = []
            Task { await scan(url: url) }
        }
    }

    // MARK: - Scanning

    func scan(url: URL, forceRefresh: Bool = false) async {
        isOverview = false
        currentURL = url

        // Check cache
        if !forceRefresh, let cached = cache[url], cached.isValid {
            items = cached.items
            totalSize = cached.totalSize
            statusMessage = "\(items.count) öğe · Toplam: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))"
            isScanning = false
            return
        }

        isScanning = true
        scanProgress = ScanProgress(isActive: true)
        items = []

        let showHidden = self.showHidden

        // First, quickly list immediate children (names only, no size calc yet)
        let fm = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        let keys: [URLResourceKey] = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey, .ubiquitousItemDownloadingStatusKey]

        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: options) else {
            statusMessage = "Klasör okunamadı"
            isScanning = false
            return
        }

        statusMessage = "\(contents.count) öğe bulundu, boyutlar hesaplanıyor..."

        // Process each item one by one, showing results as they come
        for (index, itemURL) in contents.enumerated() {
            guard let resources = try? itemURL.resourceValues(forKeys: Set(keys)) else { continue }
            let isDir = resources.isDirectory ?? false

            scanProgress.currentFolder = itemURL.lastPathComponent
            scanProgress.scannedCount = index + 1

            let size: Int64
            let count: Int

            if isDir {
                (size, count) = await Task.detached { Self.calculateDirectorySize(itemURL) }.value
            } else {
                size = Int64(resources.totalFileAllocatedSize ?? resources.fileSize ?? 0)
                count = 0
            }

            let isCloudDownloaded: Bool
            if let status = resources.ubiquitousItemDownloadingStatus {
                isCloudDownloaded = (status == .current)
            } else {
                isCloudDownloaded = false
            }

            let item = FileItem(
                name: itemURL.lastPathComponent,
                url: itemURL,
                size: size,
                isDirectory: isDir,
                itemCount: count,
                modificationDate: resources.contentModificationDate,
                isCloudDownloaded: isCloudDownloaded
            )

            // Insert sorted by size
            let insertIndex = items.firstIndex(where: { $0.size < size }) ?? items.endIndex
            items.insert(item, at: insertIndex)

            scanProgress.foundSize += size
            statusMessage = "\(index + 1)/\(contents.count) · \(itemURL.lastPathComponent)"

            // Recalculate percentages
            let maxSize = items.first?.size ?? 1
            for i in items.indices {
                items[i].percentage = maxSize > 0 ? Double(items[i].size) / Double(maxSize) : 0
            }
        }

        totalSize = items.reduce(0) { $0 + $1.size }
        items = Self.sortItems(items, by: sortOrder)
        let count = items.count
        let formattedTotal = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        statusMessage = "\(count) öğe · Toplam: \(formattedTotal)"
        scanProgress.isActive = false
        cache[url] = CacheEntry(items: items, totalSize: totalSize, timestamp: Date())
        isScanning = false
    }

    nonisolated static func scanDirectory(url: URL, showHidden: Bool) -> [FileItem] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isHiddenKey,
            .ubiquitousItemDownloadingStatusKey
        ]

        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        ) else {
            return []
        }

        var result: [FileItem] = []

        for itemURL in contents {
            guard let resources = try? itemURL.resourceValues(forKeys: Set(keys)) else { continue }
            let isDir = resources.isDirectory ?? false

            let size: Int64
            let count: Int

            if isDir {
                (size, count) = calculateDirectorySize(itemURL)
            } else {
                size = Int64(resources.totalFileAllocatedSize ?? resources.fileSize ?? 0)
                count = 0
            }

            // Check if file is downloaded from iCloud
            let isCloudDownloaded: Bool
            if let status = resources.ubiquitousItemDownloadingStatus {
                isCloudDownloaded = (status == .current)
            } else {
                isCloudDownloaded = false
            }

            result.append(FileItem(
                name: itemURL.lastPathComponent,
                url: itemURL,
                size: size,
                isDirectory: isDir,
                itemCount: count,
                modificationDate: resources.contentModificationDate,
                isCloudDownloaded: isCloudDownloaded
            ))
        }

        return result
    }

    nonisolated static func calculateDirectorySize(_ url: URL) -> (Int64, Int) {
        let fm = FileManager.default
        var total: Int64 = 0
        var count = 0

        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isDirectoryKey]

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0)
        }

        for case let fileURL as URL in enumerator {
            guard let res = try? fileURL.resourceValues(forKeys: keys) else { continue }
            if !(res.isDirectory ?? false) {
                total += Int64(res.totalFileAllocatedSize ?? 0)
            }
            count += 1
        }

        return (total, count)
    }

    // MARK: - Navigation

    func navigateInto(_ item: FileItem) {
        if isOverview {
            isOverview = false
            navigationStack = []
            Task { await scan(url: item.url) }
            return
        }
        guard item.isDirectory, let current = currentURL else { return }
        navigationStack.append(current)
        Task { await scan(url: item.url) }
    }

    func navigateBack() {
        if navigationStack.isEmpty {
            scanOverview()
            return
        }
        guard let previous = navigationStack.popLast() else { return }
        Task { await scan(url: previous) }
    }

    func navigateTo(stackIndex: Int) {
        guard stackIndex < navigationStack.count else { return }
        let target = navigationStack[stackIndex]
        navigationStack = Array(navigationStack.prefix(stackIndex))
        Task { await scan(url: target) }
    }

    func goHome() {
        scanOverview()
    }

    func refresh() {
        if isOverview {
            scanOverview(forceRefresh: true)
            return
        }
        guard let url = currentURL else { return }
        Task { await scan(url: url, forceRefresh: true) }
    }

    func clearCache() {
        cache.removeAll()
        overviewCache = nil
    }

    // MARK: - Sorting

    func resort() {
        items = Self.sortItems(items, by: sortOrder)
    }

    nonisolated static func sortItems(_ items: [FileItem], by order: SortOrder) -> [FileItem] {
        switch order {
        case .size:
            return items.sorted { $0.size > $1.size }
        case .name:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .date:
            return items.sorted { ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast) }
        }
    }

    // MARK: - Actions

    func deleteItem(_ item: FileItem) {
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            items.removeAll { $0.id == item.id }
            totalSize -= item.size
            statusMessage = "\(items.count) öğe · Toplam: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))"
            // Invalidate caches since sizes changed
            clearCache()
        } catch {
            statusMessage = "Silinemedi: \(error.localizedDescription)"
        }
    }

    func revealInFinder(_ item: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func evictFromiCloud(_ item: FileItem) {
        do {
            try FileManager.default.evictUbiquitousItem(at: item.url)
            // Update the item in list
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].isCloudDownloaded = false
                totalSize -= item.size
            }
            statusMessage = "✓ \(item.name) yerel kopyası kaldırıldı"
            // Refresh to update sizes
            refresh()
        } catch {
            statusMessage = "Kaldırılamadı: \(error.localizedDescription)"
        }
    }

    func evictAlliCloudFiles() {
        var evictedCount = 0
        var freedSize: Int64 = 0

        for item in items where item.isCloudDownloaded {
            do {
                try FileManager.default.evictUbiquitousItem(at: item.url)
                evictedCount += 1
                freedSize += item.size
            } catch {
                continue
            }
        }

        statusMessage = "✓ \(evictedCount) dosyanın yerel kopyası kaldırıldı · \(ByteCountFormatter.string(fromByteCount: freedSize, countStyle: .file)) kazanıldı"
        refresh()
    }
}
