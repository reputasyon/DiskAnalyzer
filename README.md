# Disk Analiz

A native macOS disk space analyzer built with SwiftUI. See exactly what's eating your storage — no vague "System Data" categories, just real files and folders with actual sizes.

macOS's built-in storage view groups everything into unhelpful buckets like "System Data" without showing what's actually taking space. Disk Analiz shows you the truth.

## Features

- **Instant Overview** — Launches with a full disk summary: total/used/free space with visual usage bar
- **9 Quick Locations** — Home, Applications, Library, Developer, Downloads, Desktop, Documents, iCloud Drive, System
- **Live Scanning** — Files and folders appear in real-time as they're scanned, with progress indicators
- **Size Bars** — Color-coded relative size visualization (red >1GB, orange >100MB, yellow >10MB)
- **Smart Cache** — Previously scanned folders load instantly (5-minute cache), refresh button for fresh data
- **iCloud Management** — Detect locally downloaded iCloud files, evict individual files or bulk-remove all local copies
- **Navigation** — Double-click to drill into folders, breadcrumb bar, back button, home button
- **Context Menu** — Reveal in Finder, navigate into folder, move to Trash, remove iCloud local copy
- **Sorting** — Sort by size (default), name, or date
- **Hidden Files** — Toggle to show/hide hidden files
- **File Type Icons** — Distinct icons and colors for Swift, JS, images, videos, audio, archives, apps, and more

## Requirements

- macOS 14.0+
- Xcode 16.0+

## Build & Run

```bash
# Clone
git clone https://github.com/abdullahcadirci/DiskAnalyzer.git
cd DiskAnalyzer

# Generate Xcode project (requires xcodegen)
xcodegen generate

# Open in Xcode
open DiskAnalyzer.xcodeproj
```

Then press `Cmd+R` to build and run.

## Tech Stack

- **SwiftUI** — Native macOS UI
- **FileManager** — Directory enumeration and size calculation
- **Async/Await** — Background scanning with live UI updates
- **XcodeGen** — Project file generation

## How It Works

1. On launch, scans 9 key locations and shows disk usage overview
2. Click any location to see its contents sorted by size
3. Double-click folders to drill deeper
4. Right-click for actions: Reveal in Finder, Move to Trash, Remove iCloud copy
5. Results are cached for 5 minutes — navigation is instant after first scan

---

# Disk Analiz (TR)

macOS için SwiftUI ile yazilmis yerel disk alan analizcisi. "Sistem Verisi" gibi belirsiz kategoriler yerine, gercek dosya ve klasorleri boyutlariyla gorun.

## Ozellikler

- **Anlik Genel Bakis** — Disk ozeti: toplam/kullanilan/bos alan, gorsel kullanim cubugu
- **9 Hizli Konum** — Ana Klasor, Uygulamalar, Library, Developer, Indirilenler, Masaustu, Belgeler, iCloud Drive, Sistem
- **Canli Tarama** — Dosya ve klasorler tarандикча aninda listede gorunur, ilerleme gostergeleri
- **Boyut Cubuklari** — Renk kodlu goreceli boyut gorsellestirme (kirmizi >1GB, turuncu >100MB, sari >10MB)
- **Akilli Cache** — Taranan klasorler aninda yuklenir (5 dk cache), yenile butonu ile taze tarama
- **iCloud Yonetimi** — Yerel indirilen iCloud dosyalarini tespit et, tekli veya toplu kaldir
- **Navigasyon** — Cift tikla klasore gir, breadcrumb, geri butonu, ana sayfa butonu
- **Sag Tik Menusu** — Finder'da goster, klasore git, cop kutusuna tasi, iCloud kopyayi kaldir
- **Siralama** — Boyut (varsayilan), isim veya tarih
- **Gizli Dosyalar** — Gizli dosyalari goster/gizle toggle'i
- **Dosya Tipi Ikonlari** — Swift, JS, resim, video, ses, arsiv, uygulama icin farkli ikon ve renkler

## Gereksinimler

- macOS 14.0+
- Xcode 16.0+

## Derleme ve Calistirma

```bash
git clone https://github.com/abdullahcadirci/DiskAnalyzer.git
cd DiskAnalyzer
xcodegen generate
open DiskAnalyzer.xcodeproj
```

Xcode'da `Cmd+R` ile derle ve calistir.

---

Built with SwiftUI + Claude Code
