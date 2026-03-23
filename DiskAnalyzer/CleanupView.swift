import SwiftUI

struct CleanupView: View {
    @StateObject private var manager = CleanupManager()

    var body: some View {
        VStack(spacing: 0) {
            if manager.isScanning && manager.items.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(manager.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if manager.items.isEmpty && !manager.isScanning {
                welcomeView
            } else {
                cleanupContent
            }

            Divider()
            statusBar
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: manager.scan) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(manager.isScanning || manager.isCleaning)
                .help("Yeniden Tara")
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            if manager.items.isEmpty {
                manager.scan()
            }
        }
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(.purple.gradient)

            Text("Akilli Temizlik")
                .font(.largeTitle.bold())

            Text("Gelistirici cache, log ve gecici dosyalari otomatik tespit edip temizleyin")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 450)

            Button(action: manager.scan) {
                Label("Tara", systemImage: "magnifyingglass")
                    .font(.title3)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }

    // MARK: - Content

    private var cleanupContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary card
                summaryCard

                // Cleanup items
                VStack(spacing: 8) {
                    HStack {
                        Text("Temizlenebilir Alanlar")
                            .font(.title3.bold())
                        Spacer()
                        Button(action: toggleAll) {
                            Text(allSelected ? "Hicbirini Secme" : "Tumunu Sec")
                                .font(.callout)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)

                    ForEach(Array(manager.items.enumerated()), id: \.element.id) { index, item in
                        CleanupRowView(item: item) {
                            manager.items[index].isSelected.toggle()
                            manager.recalculateTotal()
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var allSelected: Bool {
        manager.items.allSatisfy(\.isSelected)
    }

    private func toggleAll() {
        let newState = !allSelected
        for i in manager.items.indices {
            manager.items[i].isSelected = newState
        }
        manager.recalculateTotal()
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Temizlenebilir Alan", systemImage: "sparkles")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(ByteCountFormatter.string(fromByteCount: manager.totalCleanable, countStyle: .file))
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.purple)

                Text("\(manager.items.filter(\.isSelected).count)/\(manager.items.count) alan secili")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: manager.cleanSelected) {
                    HStack(spacing: 8) {
                        if manager.isCleaning {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text(manager.isCleaning ? "Temizleniyor..." : "Secilenleri Temizle")
                            .font(.body.bold())
                    }
                    .frame(minWidth: 180)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)
                .disabled(manager.totalCleanable == 0 || manager.isCleaning || manager.isScanning)

                Text("Dosyalar kalici olarak silinir")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Text(manager.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

// MARK: - Cleanup Row

struct CleanupRowView: View {
    let item: CleanupItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isSelected ? .purple : .secondary)
            }
            .buttonStyle(.plain)

            // Icon
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundStyle(item.color.gradient)
                .frame(width: 32, height: 32)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.body.weight(.medium))

                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Size
            Text(item.formattedSize)
                .font(.body.bold().monospacedDigit())
                .foregroundStyle(item.size > 1_000_000_000 ? .red : item.size > 100_000_000 ? .orange : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .opacity(item.isSelected ? 1 : 0.6)
    }
}
