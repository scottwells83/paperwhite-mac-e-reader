import AppKit
import CryptoKit
import SwiftUI
import WebKit
import UniformTypeIdentifiers

@main
struct PaperwhiteReaderApp: App {
    var body: some Scene {
        WindowGroup {
            ReaderView()
                .frame(minWidth: 820, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 780)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Show EPUB Library in Finder") { LibraryStore.revealBooksFolder() }
            }
        }
    }
}

private struct Chapter: Identifiable {
    let id: Int
    let title: String
    let text: String
}

private struct EPUBBook {
    let title: String
    let author: String
    let chapters: [Chapter]

    static func open(_ source: URL) throws -> EPUBBook {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("paperwhite-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", source.path, folder.path]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ReaderError.archive(detail.isEmpty ? "The EPUB archive could not be opened." : detail)
        }

        let containerURL = folder.appendingPathComponent("META-INF/container.xml")
        let container = try XMLDocument(contentsOf: containerURL, options: [.documentTidyXML])
        guard let packagePath = try container.nodes(forXPath: "//*[local-name()='rootfile']/@full-path").first?.stringValue else {
            throw ReaderError.structure("The EPUB has no package document.")
        }
        let packageURL = folder.appendingPathComponent(packagePath).standardizedFileURL
        guard packageURL.path.hasPrefix(folder.standardizedFileURL.path + "/") else {
            throw ReaderError.structure("The EPUB package path is invalid.")
        }
        let package = try XMLDocument(contentsOf: packageURL, options: [.documentTidyXML])
        let title = try package.nodes(forXPath: "//*[local-name()='metadata']/*[local-name()='title']").first?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = try package.nodes(forXPath: "//*[local-name()='metadata']/*[local-name()='creator']").first?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemNodes = try package.nodes(forXPath: "//*[local-name()='manifest']/*[local-name()='item']")
        var items: [String: String] = [:]
        for node in itemNodes {
            guard let element = node as? XMLElement,
                  let id = element.attribute(forName: "id")?.stringValue,
                  let href = element.attribute(forName: "href")?.stringValue else { continue }
            items[id] = href
        }
        let spine = try package.nodes(forXPath: "//*[local-name()='spine']/*[local-name()='itemref']")
        var chapters: [Chapter] = []
        for (index, node) in spine.enumerated() {
            guard let idref = (node as? XMLElement)?.attribute(forName: "idref")?.stringValue,
                  let href = items[idref] else { continue }
            let chapterURL = packageURL.deletingLastPathComponent().appendingPathComponent(href).standardizedFileURL
            guard chapterURL.path.hasPrefix(folder.standardizedFileURL.path + "/"),
                  let data = try? Data(contentsOf: chapterURL),
                  let text = try? plainText(from: data), !text.isEmpty else { continue }
            chapters.append(Chapter(id: chapters.count, title: "Chapter \(index + 1)", text: text))
        }
        guard !chapters.isEmpty else { throw ReaderError.structure("No readable chapters were found in this EPUB.") }
        return EPUBBook(title: (title?.isEmpty == false ? title! : source.deletingPathExtension().lastPathComponent),
                        author: (author?.isEmpty == false ? author! : "Unknown author"),
                        chapters: chapters)
    }

    private static func plainText(from data: Data) throws -> String {
        let document = try XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever])
        var pieces: [String] = []
        let blockTags: Set<String> = ["p", "div", "section", "article", "h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote", "br", "tr"]
        func visit(_ node: XMLNode) {
            if node.kind == .text {
                if let value = node.stringValue, !value.isEmpty { pieces.append(value) }
                return
            }
            guard let element = node as? XMLElement else {
                for child in node.children ?? [] { visit(child) }
                return
            }
            let tag = (element.name ?? "").lowercased()
            if tag == "script" || tag == "style" { return }
            if blockTags.contains(tag) { pieces.append("\n\n") }
            for child in element.children ?? [] { visit(child) }
            if blockTags.contains(tag) { pieces.append("\n\n") }
        }
        visit(document)
        return pieces.joined()
            .replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " *\\n *", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct LibraryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let author: String
    let fileName: String
    let contentHash: String
    let chapterCount: Int
    var lastChapter: Int
}

private enum LibraryStore {
    private static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Paperwhite Reader", isDirectory: true)
    }
    static var booksFolder: URL { root.appendingPathComponent("Books", isDirectory: true) }
    private static var indexFile: URL { root.appendingPathComponent("library.json") }

    static func load() throws -> [LibraryEntry] {
        try ensureFolders()
        guard FileManager.default.fileExists(atPath: indexFile.path) else { return [] }
        let data = try Data(contentsOf: indexFile)
        let entries = try JSONDecoder().decode([LibraryEntry].self, from: data)
        return entries.filter { FileManager.default.fileExists(atPath: fileURL(for: $0).path) }
    }

    static func add(_ source: URL) throws -> (entry: LibraryEntry, book: EPUBBook, entries: [LibraryEntry]) {
        try ensureFolders()
        let data = try Data(contentsOf: source)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        var entries = try load()
        if let existing = entries.first(where: { $0.contentHash == hash }) {
            return (existing, try open(existing), entries)
        }

        let parsed = try EPUBBook.open(source)
        let id = UUID()
        var fileName = source.lastPathComponent
        if FileManager.default.fileExists(atPath: booksFolder.appendingPathComponent(fileName).path) {
            let stem = source.deletingPathExtension().lastPathComponent
            fileName = "\(stem) (\(id.uuidString.prefix(8))).epub"
        }
        let destination = booksFolder.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: source, to: destination)
        let entry = LibraryEntry(id: id, title: parsed.title, author: parsed.author,
                                 fileName: fileName, contentHash: hash,
                                 chapterCount: parsed.chapters.count, lastChapter: 0)
        entries.append(entry)
        try save(entries)
        return (entry, parsed, entries)
    }

    static func open(_ entry: LibraryEntry) throws -> EPUBBook {
        try EPUBBook.open(fileURL(for: entry))
    }

    static func save(_ entries: [LibraryEntry]) throws {
        try ensureFolders()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries).write(to: indexFile, options: .atomic)
    }

    static func revealBooksFolder() {
        try? ensureFolders()
        NSWorkspace.shared.open(booksFolder)
    }

    private static func fileURL(for entry: LibraryEntry) -> URL {
        booksFolder.appendingPathComponent(entry.fileName)
    }

    private static func ensureFolders() throws {
        try FileManager.default.createDirectory(at: booksFolder, withIntermediateDirectories: true)
    }
}

private enum ReaderError: LocalizedError {
    case archive(String)
    case structure(String)
    var errorDescription: String? {
        switch self {
        case .archive(let message): return "Could not open EPUB: \(message)"
        case .structure(let message): return message
        }
    }
}

private enum PaperTheme: String, CaseIterable, Identifiable {
    case paper = "Paper"
    case ivory = "Ivory"
    case night = "Night"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .paper: return Color(red: 0.94, green: 0.91, blue: 0.84)
        case .ivory: return Color(red: 0.97, green: 0.96, blue: 0.91)
        case .night: return Color(red: 0.13, green: 0.14, blue: 0.15)
        }
    }
    var inkColor: Color { self == .night ? Color(red: 0.91, green: 0.89, blue: 0.85) : Color(red: 0.20, green: 0.18, blue: 0.16) }
    var ink: String { self == .night ? "#E7E2D8" : "#332F29" }
}

private struct ReaderView: View {
    @AppStorage("paperwhite.selectedBookID") private var selectedBookIDText = ""
    @State private var libraryEntries: [LibraryEntry] = []
    @State private var selectedBookID: UUID?
    @State private var book: EPUBBook?
    @State private var chapterIndex = 0
    @State private var fontSize = 19.0
    @State private var theme: PaperTheme = .paper
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var currentChapter: Chapter? {
        guard let book, book.chapters.indices.contains(chapterIndex) else { return nil }
        return book.chapters[chapterIndex]
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                toolbar
                if book != nil, let chapter = currentChapter {
                    readingPage(chapter: chapter)
                } else {
                    welcome
                }
                footer
            }
            .background(Color(red: 0.89, green: 0.88, blue: 0.85))
        }
        .background(Color(red: 0.96, green: 0.95, blue: 0.92))
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data], allowsMultipleSelection: false, onCompletion: importResult)
        .onChange(of: chapterIndex) { _, newValue in persistReadingPosition(newValue) }
        .alert("Couldn’t open this book", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "Please choose a valid EPUB file.") }
        .task { restoreLibrary() }
        .preferredColorScheme(.light)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill").font(.system(size: 18, weight: .medium)).foregroundStyle(Color(red: 0.48, green: 0.38, blue: 0.26))
                Text("PAPERWHITE").font(.system(size: 12, weight: .semibold, design: .rounded)).tracking(2.1).foregroundStyle(Color(red: 0.30, green: 0.28, blue: 0.24))
            }
            Button { isImporting = true } label: {
                Label("Add a book", systemImage: "plus").font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color(red: 0.30, green: 0.28, blue: 0.24))
            }
            .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color(red: 0.91, green: 0.89, blue: 0.84), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR LIBRARY").font(.system(size: 10, weight: .semibold)).tracking(1.7).foregroundStyle(Color(red: 0.48, green: 0.46, blue: 0.42))
                if libraryEntries.isEmpty {
                    Text("Your books will appear here.").font(.system(size: 12)).foregroundStyle(Color(red: 0.48, green: 0.46, blue: 0.42)).fixedSize(horizontal: false, vertical: true)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(libraryEntries) { entry in
                                Button { openBook(entry) } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(entry.title).font(.system(size: 13, weight: .medium)).lineLimit(2)
                                        Text(entry.author).font(.system(size: 11)).foregroundStyle(Color(red: 0.48, green: 0.46, blue: 0.42)).lineLimit(1)
                                        Text("Chapter \(min(entry.lastChapter + 1, entry.chapterCount)) of \(entry.chapterCount)")
                                            .font(.system(size: 10)).foregroundStyle(Color(red: 0.48, green: 0.46, blue: 0.42))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                    .background(selectedBookID == entry.id ? Color.white.opacity(0.80) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(Color(red: 0.54, green: 0.61, blue: 0.49)).frame(width: 7, height: 7)
                Text("Stored on this Mac").font(.system(size: 10)).foregroundStyle(Color(red: 0.48, green: 0.46, blue: 0.42))
            }
        }
        .padding(.horizontal, 18).padding(.top, 25).padding(.bottom, 18)
        .frame(width: 220).background(Color(red: 0.96, green: 0.95, blue: 0.92))
        .overlay(alignment: .trailing) { Rectangle().fill(Color.black.opacity(0.07)).frame(width: 1) }
    }

    private var toolbar: some View {
        HStack {
            if let book {
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Text(book.author).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                Text("Your reading room").font(.system(size: 13, weight: .medium)).foregroundStyle(Color(red: 0.32, green: 0.30, blue: 0.26))
            }
            Spacer()
            HStack(spacing: 13) {
                Menu {
                    Picker("Page tone", selection: $theme) {
                        ForEach(PaperTheme.allCases) { theme in Text(theme.rawValue).tag(theme) }
                    }
                } label: {
                    Label(theme.rawValue, systemImage: "circle.lefthalf.filled").labelStyle(.titleAndIcon).font(.system(size: 12))
                }.menuStyle(.borderlessButton).foregroundStyle(Color(red: 0.38, green: 0.36, blue: 0.32))
                HStack(spacing: 8) {
                    Button { fontSize = max(15, fontSize - 1) } label: { Image(systemName: "textformat.size.smaller") }.help("Smaller text")
                    Text("Aa").font(.system(size: 12, weight: .medium)).frame(width: 24)
                    Button { fontSize = min(27, fontSize + 1) } label: { Image(systemName: "textformat.size.larger") }.help("Larger text")
                }.buttonStyle(.plain).foregroundStyle(Color(red: 0.37, green: 0.35, blue: 0.31))
                Button { isImporting = true } label: { Image(systemName: "plus.square.on.square") }.help("Open an EPUB")
                Button { LibraryStore.revealBooksFolder() } label: { Image(systemName: "folder") }.help("Show saved EPUBs in Finder")
            }
            .buttonStyle(.plain).foregroundStyle(Color(red: 0.38, green: 0.36, blue: 0.32))
        }
        .padding(.horizontal, 28).frame(height: 68)
        .background(Color(red: 0.96, green: 0.95, blue: 0.92))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1) }
    }

    private func readingPage(chapter: Chapter) -> AnyView {
        let heading = Text(chapter.title.uppercased())
            .font(.system(size: 10, weight: .medium)).tracking(1.7)
            .foregroundStyle(theme.inkColor.opacity(0.52))
        let reader = ReaderWebView(chapter: chapter, theme: theme, fontSize: fontSize)
            .background(theme.color).clipShape(RoundedRectangle(cornerRadius: 2))
            .padding(.horizontal, 42).padding(.bottom, 25)
        return AnyView(VStack(spacing: 0) {
            HStack { heading; Spacer() }
                .padding(.horizontal, 54).padding(.top, 26).padding(.bottom, 12)
            reader
        })
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.91, green: 0.87, blue: 0.77)).frame(width: 64, height: 82).rotationEffect(.degrees(-8)).offset(x: -7, y: 3)
                    RoundedRectangle(cornerRadius: 5).fill(theme.color).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.08), lineWidth: 1)).frame(width: 64, height: 82).rotationEffect(.degrees(5)).offset(x: 6, y: -3)
                    Image(systemName: "leaf").font(.system(size: 21, weight: .light)).foregroundStyle(Color(red: 0.50, green: 0.46, blue: 0.36))
                }.frame(height: 100)
                VStack(spacing: 8) {
                    Text("A little more like paper.").font(.system(size: 24, weight: .regular, design: .serif)).foregroundStyle(Color(red: 0.28, green: 0.27, blue: 0.23))
                    Text("Bring a book into your reading room and settle in.").font(.system(size: 13)).foregroundStyle(Color(red: 0.43, green: 0.41, blue: 0.37))
                }
                Button { isImporting = true } label: {
                    Label(isLoading ? "Opening…" : "Choose an EPUB", systemImage: "book.badge.plus")
                        .font(.system(size: 13, weight: .medium)).padding(.horizontal, 17).padding(.vertical, 11)
                }.buttonStyle(.plain).foregroundStyle(.white).background(Color(red: 0.36, green: 0.34, blue: 0.29), in: RoundedRectangle(cornerRadius: 9)).disabled(isLoading)
                Text("Your files stay on this Mac.").font(.system(size: 11)).foregroundStyle(Color(red: 0.48, green: 0.46, blue: 0.42)).padding(.top, 2)
            }
            .padding(40).frame(maxWidth: 580).background(theme.color, in: RoundedRectangle(cornerRadius: 4)).shadow(color: .black.opacity(0.09), radius: 16, y: 7)
            Spacer()
        }.frame(maxWidth: .infinity).padding(40).background(Color(red: 0.89, green: 0.88, blue: 0.85))
    }

    private var footer: some View {
        HStack {
            if let book {
                Button { chapterIndex = max(0, chapterIndex - 1) } label: { Label("Previous", systemImage: "chevron.left").labelStyle(.titleAndIcon) }.disabled(chapterIndex == 0)
                Spacer()
                Text("\(chapterIndex + 1) of \(book.chapters.count)").font(.system(size: 11, design: .rounded)).foregroundStyle(.secondary)
                Spacer()
                Button { chapterIndex = min(book.chapters.count - 1, chapterIndex + 1) } label: { Label("Next", systemImage: "chevron.right").labelStyle(.titleAndIcon) }.disabled(chapterIndex >= book.chapters.count - 1)
            } else {
                Spacer()
                Text("A quiet place for your next chapter").font(.system(size: 11)).foregroundStyle(Color(red: 0.48, green: 0.46, blue: 0.42))
                Spacer()
            }
        }
        .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Color(red: 0.38, green: 0.36, blue: 0.32))
        .padding(.horizontal, 32).frame(height: 50)
        .background(Color(red: 0.96, green: 0.95, blue: 0.92))
        .overlay(alignment: .top) { Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1) }
    }

    private func importResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
            return
        }
        isLoading = true
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let imported = try LibraryStore.add(url)
            libraryEntries = imported.entries
            selectedBookID = imported.entry.id
            selectedBookIDText = imported.entry.id.uuidString
            book = imported.book
            chapterIndex = imported.entry.lastChapter
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    private func restoreLibrary() {
        do {
            libraryEntries = try LibraryStore.load()
            guard let savedID = UUID(uuidString: selectedBookIDText),
                  let entry = libraryEntries.first(where: { $0.id == savedID }) else { return }
            openBook(entry)
        } catch { errorMessage = error.localizedDescription }
    }

    private func openBook(_ entry: LibraryEntry) {
        do {
            book = try LibraryStore.open(entry)
            selectedBookID = entry.id
            selectedBookIDText = entry.id.uuidString
            chapterIndex = min(entry.lastChapter, max(0, entry.chapterCount - 1))
        } catch { errorMessage = error.localizedDescription }
    }

    private func persistReadingPosition(_ chapter: Int) {
        guard let selectedBookID,
              let index = libraryEntries.firstIndex(where: { $0.id == selectedBookID }),
              libraryEntries[index].lastChapter != chapter else { return }
        libraryEntries[index].lastChapter = chapter
        do { try LibraryStore.save(libraryEntries) }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct ReaderWebView: NSViewRepresentable {
    let chapter: Chapter
    let theme: PaperTheme
    let fontSize: Double

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let safeText = chapter.text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline';">
        <style>
        html { background: \(theme.color.hex); color: \(theme.ink); }
        body { max-width: 660px; margin: 0 auto; padding: 28px 28px 72px; font: \(Int(fontSize))px/1.78 Georgia, 'Times New Roman', serif; white-space: pre-wrap; }
        </style></head><body>\(safeText)</body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

private extension Color {
    var hex: String {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? .white
        return String(format: "#%02X%02X%02X", Int(nsColor.redComponent * 255), Int(nsColor.greenComponent * 255), Int(nsColor.blueComponent * 255))
    }
}
