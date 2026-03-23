import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = DiskScanner()

    var body: some View {
        VStack(spacing: 0) {
            if !scanner.isOverview && scanner.currentURL != nil {
                breadcrumbBar
                Divider()
            }

            if scanner.isScanning && scanner.items.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(scanner.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if scanner.scanProgress.isActive {
                        VStack(spacing: 8) {
                            if !scanner.scanProgress.currentFolder.isEmpty {
                                Text(scanner.scanProgress.currentFolder)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            if scanner.scanProgress.foundSize > 0 {
                                Text(ByteCountFormatter.string(fromByteCount: scanner.scanProgress.foundSize, countStyle: .file))
                                    .font(.title3.bold().monospacedDigit())
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .frame(maxWidth: 400)
                Spacer()
            } else if scanner.isScanning && !scanner.items.isEmpty {
                // Scanning but already showing partial results
                if scanner.isOverview {
                    overviewContent
                } else {
                    fileList
                }
            } else if scanner.isOverview {
                overviewContent
            } else if scanner.items.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Bu klasör boş")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                fileList
            }

            Divider()
            statusBar
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: scanner.navigateBack) {
                    Image(systemName: "chevron.left")
                }
                .disabled(scanner.isOverview || scanner.isScanning)
                .help("Geri")

                Button(action: scanner.goHome) {
                    Image(systemName: "house")
                }
                .disabled(scanner.isOverview || scanner.isScanning)
                .help("Genel Bakış")
            }

            ToolbarItemGroup {
                Button(action: scanner.selectFolder) {
                    Image(systemName: "folder.badge.plus")
                }
                .help("Klasör Seç")

                if !scanner.isOverview {
                    Picker("Sıralama", selection: $scanner.sortOrder) {
                        ForEach(DiskScanner.SortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .onChange(of: scanner.sortOrder) { _, _ in
                        scanner.resort()
                    }

                    Toggle(isOn: $scanner.showHidden) {
                        Image(systemName: scanner.showHidden ? "eye" : "eye.slash")
                    }
                    .help(scanner.showHidden ? "Gizli Dosyaları Gizle" : "Gizli Dosyaları Göster")
                    .onChange(of: scanner.showHidden) { _, _ in
                        scanner.refresh()
                    }
                }

                Button(action: scanner.refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(scanner.isScanning)
                .help("Yenile")
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            scanner.scanOverview()
        }
    }

    // MARK: - Overview

    private var overviewContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Disk usage header
                if let info = scanner.diskInfo {
                    diskUsageCard(info: info)
                }

                // Scanning progress banner
                if scanner.isScanning && scanner.scanProgress.isActive {
                    scanningBanner
                }

                // Location list
                if !scanner.items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Konumlar")
                            .font(.title3.bold())
                            .padding(.horizontal, 4)

                        ForEach(scanner.items) { item in
                            OverviewRowView(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    scanner.navigateInto(item)
                                }
                                .contextMenu {
                                    Button("Finder'da Göster") {
                                        scanner.revealInFinder(item)
                                    }
                                    Button("Detaylı Analiz") {
                                        scanner.navigateInto(item)
                                    }
                                }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var scanningBanner: some View {
        HStack(spacing: 14) {
            ProgressView()
                .scaleEffect(0.8)

            VStack(alignment: .leading, spacing: 3) {
                Text("Taranıyor: \(scanner.scanProgress.currentFolder)")
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                Text("\(scanner.scanProgress.scannedCount)/\(scanner.quickLocations.count) konum · \(ByteCountFormatter.string(fromByteCount: scanner.scanProgress.foundSize, countStyle: .file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue.gradient)
                        .frame(width: geo.size.width * (Double(scanner.scanProgress.scannedCount) / Double(max(scanner.quickLocations.count, 1))))
                }
            }
            .frame(width: 100, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func diskUsageCard(info: DiskInfo) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "internaldrive.fill")
                    .font(.title2)
                    .foregroundStyle(.blue.gradient)
                Text("Macintosh HD")
                    .font(.title2.bold())
                Spacer()
                Text(info.formattedTotal)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Usage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.gray.opacity(0.15))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(usageGradient(percentage: info.usedPercentage))
                        .frame(width: geo.size.width * info.usedPercentage)
                }
            }
            .frame(height: 24)

            // Stats
            HStack(spacing: 32) {
                statBadge(label: "Kullanılan", value: info.formattedUsed, color: .orange)
                statBadge(label: "Boş", value: info.formattedFree, color: .green)
                statBadge(label: "Kullanım", value: "\(Int(info.usedPercentage * 100))%", color: info.usedPercentage > 0.9 ? .red : .blue)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func usageGradient(percentage: Double) -> LinearGradient {
        if percentage > 0.9 {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        } else if percentage > 0.75 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
    }

    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Breadcrumb Bar

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button(action: scanner.goHome) {
                    Image(systemName: "house")
                        .font(.callout)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(scanner.navigationStack.enumerated()), id: \.offset) { index, url in
                    Button(action: { scanner.navigateTo(stackIndex: index) }) {
                        Text(url.lastPathComponent)
                            .font(.callout)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let current = scanner.currentURL {
                    Text(current.lastPathComponent)
                        .font(.callout.bold())
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    // MARK: - File List

    private var iCloudItemCount: Int {
        scanner.items.filter(\.isCloudDownloaded).count
    }

    private var iCloudDownloadedSize: Int64 {
        scanner.items.filter(\.isCloudDownloaded).reduce(0) { $0 + $1.size }
    }

    private var fileList: some View {
        VStack(spacing: 0) {
            if scanner.isScanning && scanner.scanProgress.isActive {
                folderScanBanner
                Divider()
            }
            if iCloudItemCount > 0 {
                iCloudBanner
                Divider()
            }
            innerFileList
        }
    }

    private var iCloudBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "icloud.and.arrow.down.fill")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(iCloudItemCount) iCloud dosyası yerel olarak indirilmiş")
                    .font(.callout.weight(.medium))
                Text("\(ByteCountFormatter.string(fromByteCount: iCloudDownloadedSize, countStyle: .file)) yer kaplıyor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Tümünü Kaldır") {
                scanner.evictAlliCloudFiles()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.blue.opacity(0.06))
    }

    private var folderScanBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.7)

            Text("\(scanner.scanProgress.scannedCount) öğe tarandı")
                .font(.callout.weight(.medium))

            Text("·")
                .foregroundStyle(.secondary)

            Text(scanner.scanProgress.currentFolder)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: scanner.scanProgress.foundSize, countStyle: .file))
                .font(.callout.bold().monospacedDigit())
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var innerFileList: some View {
        List(scanner.items) { item in
            FileRowView(item: item)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if item.isDirectory {
                        scanner.navigateInto(item)
                    }
                }
                .contextMenu {
                    Button("Finder'da Göster") {
                        scanner.revealInFinder(item)
                    }
                    if item.isDirectory {
                        Button("Klasöre Git") {
                            scanner.navigateInto(item)
                        }
                    }
                    if item.isCloudDownloaded {
                        Divider()
                        Button("iCloud Yerel Kopyayı Kaldır") {
                            scanner.evictFromiCloud(item)
                        }
                    }
                    Divider()
                    Button("Çöp Kutusuna Taşı", role: .destructive) {
                        scanner.deleteItem(item)
                    }
                }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Text(scanner.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

// MARK: - Overview Row View

struct OverviewRowView: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.iconName)
                .font(.title2)
                .foregroundStyle(item.iconColor.gradient)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body.weight(.medium))

                if item.itemCount > 0 {
                    Text("\(item.itemCount) öğe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            SizeBar(percentage: item.percentage, color: item.sizeColor)
                .frame(width: 150)

            Text(item.formattedSize)
                .font(.body.bold().monospacedDigit())
                .frame(width: 90, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - File Row View

struct FileRowView: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .font(.title3)
                .foregroundStyle(item.iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)

                if item.isDirectory && item.itemCount > 0 {
                    Text("\(item.itemCount) öğe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            SizeBar(percentage: item.percentage, color: item.sizeColor)
                .frame(width: 120)

            Text(item.formattedSize)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            if item.isCloudDownloaded {
                Image(systemName: "icloud.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .help("iCloud'dan indirilmiş")
            }

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Color.clear.frame(width: 8)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Size Bar

struct SizeBar: View {
    let percentage: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.15))

                RoundedRectangle(cornerRadius: 3)
                    .fill(color.gradient)
                    .frame(width: max(geo.size.width * percentage, percentage > 0 ? 2 : 0))
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    ContentView()
}
