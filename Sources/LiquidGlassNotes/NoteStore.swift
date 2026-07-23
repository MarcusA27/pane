import Foundation
import SwiftUI

/// A span of a block's text carrying bold and/or italic. Offsets are UTF-16
/// (NSString) positions, matching how the text view reports ranges.
struct StyleRun: Codable, Hashable {
    var start: Int
    var length: Int
    var bold: Bool = false
    var italic: Bool = false
}

struct TextBlock: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var x: Double
    var y: Double
    var text: String = ""
    var styles: [StyleRun] = []

    init(id: UUID = UUID(), x: Double, y: Double, text: String = "", styles: [StyleRun] = []) {
        self.id = id
        self.x = x
        self.y = y
        self.text = text
        self.styles = styles
    }

    private enum CodingKeys: String, CodingKey {
        case id, x, y, text, styles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.x = try c.decode(Double.self, forKey: .x)
        self.y = try c.decode(Double.self, forKey: .y)
        self.text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.styles = try c.decodeIfPresent([StyleRun].self, forKey: .styles) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
        try c.encode(text, forKey: .text)
        if !styles.isEmpty { try c.encode(styles, forKey: .styles) }
    }
}

struct Stroke: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var points: [CGPoint]
}

/// How a note is edited. `freeform` is the spatial canvas (type anywhere,
/// draw, place blocks); `lined` is a traditional top-to-bottom text column.
enum NoteLayout: String, Codable {
    case freeform
    case lined
}

enum EditEvent: Codable, Hashable {
    case blockCreated(blockID: UUID, x: Double, y: Double, at: Date)
    case blockTextRun(blockID: UUID, text: String, at: Date)
    case blockMoved(blockID: UUID, x: Double, y: Double, at: Date)
    case blockDeleted(blockID: UUID, at: Date)
    case strokeAdded(stroke: Stroke, at: Date)
    case strokeErased(strokeID: UUID, at: Date)

    var timestamp: Date {
        switch self {
        case .blockCreated(_, _, _, let at),
             .blockTextRun(_, _, let at),
             .blockMoved(_, _, _, let at),
             .blockDeleted(_, let at),
             .strokeAdded(_, let at),
             .strokeErased(_, let at):
            return at
        }
    }
}

struct Note: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var blocks: [TextBlock] = []
    var annotations: [Stroke] = []
    var history: [EditEvent] = []
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil
    var layout: NoteLayout = .lined

    init(id: UUID = UUID(),
         title: String = "",
         blocks: [TextBlock] = [],
         annotations: [Stroke] = [],
         history: [EditEvent] = [],
         updatedAt: Date = Date(),
         deletedAt: Date? = nil,
         layout: NoteLayout = .lined) {
        self.id = id
        self.title = title
        self.blocks = blocks
        self.annotations = annotations
        self.history = history
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.layout = layout
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, blocks, annotations, history, updatedAt, body, deletedAt, layout
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.annotations = try c.decodeIfPresent([Stroke].self, forKey: .annotations) ?? []
        self.history = try c.decodeIfPresent([EditEvent].self, forKey: .history) ?? []
        self.deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        // Notes saved before layouts existed were all freeform.
        self.layout = try c.decodeIfPresent(NoteLayout.self, forKey: .layout) ?? .freeform
        if let blocks = try c.decodeIfPresent([TextBlock].self, forKey: .blocks) {
            self.blocks = blocks
        } else if let body = try c.decodeIfPresent(String.self, forKey: .body),
                  !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.blocks = [TextBlock(x: 0, y: 0, text: body)]
        } else {
            self.blocks = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(blocks, forKey: .blocks)
        try c.encode(annotations, forKey: .annotations)
        try c.encode(history, forKey: .history)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try c.encode(layout, forKey: .layout)
    }

    var hasPlayback: Bool {
        // A bare blockCreated (e.g. a fresh lined note's empty body) isn't worth
        // replaying — require some actual typed or drawn content.
        history.contains { event in
            switch event {
            case .blockTextRun, .strokeAdded: return true
            default: return false
            }
        }
    }

    private var orderedLines: [String] {
        blocks
            .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
            .flatMap { $0.text.split(whereSeparator: \.isNewline).map(String.init) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return orderedLines.first ?? "Untitled"
    }

    /// No title, no drawings, and no non-whitespace text in any block.
    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && annotations.isEmpty
            && blocks.allSatisfy { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var snippet: String {
        let titleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return orderedLines.dropFirst(titleEmpty ? 1 : 0).first ?? ""
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return true }
        if title.localizedCaseInsensitiveContains(q) { return true }
        return blocks.contains { $0.text.localizedCaseInsensitiveContains(q) }
    }
}

@MainActor
final class NoteStore: ObservableObject {
    static let shared = NoteStore()

    @Published var notes: [Note] = []
    @Published var selection: Note.ID? {
        didSet {
            if let previous = oldValue, previous != selection {
                discardIfEmpty(previous)
            }
        }
    }

    private let fileURL: URL
    private let backupURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let fm = FileManager.default
        let support = (try? fm.url(for: .applicationSupportDirectory,
                                   in: .userDomainMask,
                                   appropriateFor: nil,
                                   create: true)) ?? fm.homeDirectoryForCurrentUser
        let dir = support.appendingPathComponent("Pane", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("notes.json")
        self.backupURL = dir.appendingPathComponent("notes.backup.json")

        // Migrate from the pre-rename location for anyone upgrading from 0.1.0.
        let legacyURL = support
            .appendingPathComponent("LiquidGlassNotes", isDirectory: true)
            .appendingPathComponent("notes.json")
        if !fm.fileExists(atPath: fileURL.path),
           fm.fileExists(atPath: legacyURL.path) {
            try? fm.copyItem(at: legacyURL, to: fileURL)
        }

        load()
        purgeExpiredDeletes()
        if notes.isEmpty {
            let welcome = Note(
                title: "Welcome",
                blocks: [
                    TextBlock(x: 0, y: 0, text: "Click anywhere on this canvas to start typing."),
                    TextBlock(x: 0, y: 80, text: "⌘N for a new note  ·  ⌘0 to toggle the sidebar"),
                    TextBlock(x: 0, y: 140, text: "Empty blocks vanish when you click away.")
                ],
                layout: .freeform
            )
            notes = [welcome]
            selection = welcome.id
            persistNow()
        } else {
            selection = sortedNotes.first?.id
        }
    }

    var sortedNotes: [Note] {
        notes.filter { $0.deletedAt == nil }.sorted { $0.updatedAt > $1.updatedAt }
    }


    @discardableResult
    func addNote(layout: NoteLayout) -> Note.ID {
        let note: Note
        if layout == .lined {
            // A lined note starts with its single body block anchored top-left.
            let block = TextBlock(x: 0, y: 0)
            note = Note(
                blocks: [block],
                history: [.blockCreated(blockID: block.id, x: 0, y: 0, at: Date())],
                layout: .lined
            )
        } else {
            // A canvas starts empty; blocks appear where you click.
            note = Note(layout: .freeform)
        }
        notes.insert(note, at: 0)
        selection = note.id
        persistNow()
        return note.id
    }

    private static let deletedRetention: TimeInterval = 30 * 24 * 60 * 60

    private func purgeExpiredDeletes() {
        let cutoff = Date().addingTimeInterval(-Self.deletedRetention)
        let before = notes.count
        notes.removeAll { ($0.deletedAt ?? .distantFuture) < cutoff }
        if notes.count != before { scheduleSave() }
    }

    /// A note left completely empty is discarded once it's no longer open, so
    /// abandoned "Untitled" notes don't pile up. Hard delete — there's nothing
    /// to recover.
    private func discardIfEmpty(_ id: Note.ID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }),
              notes[idx].deletedAt == nil,
              notes[idx].isEmpty else { return }
        notes.remove(at: idx)
        scheduleSave()
    }

    func softDelete(noteID: Note.ID) {
        guard let idx = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[idx].deletedAt = Date()
        if selection == noteID { selection = sortedNotes.first?.id }
        scheduleSave()
    }

    func restore(noteID: Note.ID) {
        guard let idx = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[idx].deletedAt = nil
        scheduleSave()
    }

    func softDelete(noteID: Note.ID, undoManager: UndoManager?) {
        softDelete(noteID: noteID)
        undoManager?.registerUndo(withTarget: self) { store in
            store.restore(noteID: noteID, undoManager: undoManager)
        }
        undoManager?.setActionName("Delete Note")
    }

    func restore(noteID: Note.ID, undoManager: UndoManager?) {
        restore(noteID: noteID)
        selection = noteID
        undoManager?.registerUndo(withTarget: self) { store in
            store.softDelete(noteID: noteID, undoManager: undoManager)
        }
        undoManager?.setActionName("Delete Note")
    }

    func setTitle(noteID: Note.ID, title: String) {
        guard let idx = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[idx].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        scheduleSave()
    }

    func binding(for id: Note.ID) -> Binding<Note>? {
        guard notes.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { [weak self] in
                guard let self else { return Note() }
                return self.notes.first(where: { $0.id == id }) ?? Note()
            },
            set: { [weak self] newValue in
                guard let self,
                      let idx = self.notes.firstIndex(where: { $0.id == id }) else { return }
                var updated = newValue
                updated.updatedAt = Date()
                self.notes[idx] = updated
                self.scheduleSave()
            }
        )
    }


    private func load() {
        if let decoded = Self.decodeNotes(at: fileURL) {
            notes = Self.prunedEmptyBlocks(decoded)
            return
        }

        // Decode failed. Move the unreadable file aside so the welcome-note
        // bootstrap can't overwrite it, then fall back to the last backup.
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        let quarantineURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("notes.corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? fm.moveItem(at: fileURL, to: quarantineURL)

        if let recovered = Self.decodeNotes(at: backupURL) {
            notes = Self.prunedEmptyBlocks(recovered)
        }
    }

    private static func decodeNotes(at url: URL) -> [Note]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Note].self, from: data)
    }

    /// Blocks left empty when the app quits are never cleaned up by the
    /// focus-change path, so they accumulate on disk. Drop them at load
    /// without touching updatedAt.
    private static func prunedEmptyBlocks(_ notes: [Note]) -> [Note] {
        notes.map { note in
            var pruned = note
            pruned.blocks.removeAll {
                $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return pruned
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.persistNow() }
        }
    }

    private func persistNow() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            try? fm.removeItem(at: backupURL)
            try? fm.copyItem(at: fileURL, to: backupURL)
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
