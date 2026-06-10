import Foundation
import SwiftUI

struct TextBlock: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var x: Double
    var y: Double
    var text: String = ""
}

struct Stroke: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var points: [CGPoint]
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

    init(id: UUID = UUID(),
         title: String = "",
         blocks: [TextBlock] = [],
         annotations: [Stroke] = [],
         history: [EditEvent] = [],
         updatedAt: Date = Date(),
         deletedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.blocks = blocks
        self.annotations = annotations
        self.history = history
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, blocks, annotations, history, updatedAt, body, deletedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.annotations = try c.decodeIfPresent([Stroke].self, forKey: .annotations) ?? []
        self.history = try c.decodeIfPresent([EditEvent].self, forKey: .history) ?? []
        self.deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
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
    }

    var hasPlayback: Bool {
        !history.isEmpty
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
        return orderedLines.first ?? "New Note"
    }

    var snippet: String {
        let titleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return orderedLines.dropFirst(titleEmpty ? 1 : 0).first ?? ""
    }
}

struct Idea: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String
    var createdAt: Date = Date()
}

@MainActor
final class NoteStore: ObservableObject {
    static let shared = NoteStore()

    @Published var notes: [Note] = []
    @Published var selection: Note.ID?
    @Published var ideas: [Idea] = []

    private let fileURL: URL
    private let ideasURL: URL
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
        self.ideasURL = dir.appendingPathComponent("ideas.json")

        // Migrate from the pre-rename location for anyone upgrading from 0.1.0.
        let legacyURL = support
            .appendingPathComponent("LiquidGlassNotes", isDirectory: true)
            .appendingPathComponent("notes.json")
        if !fm.fileExists(atPath: fileURL.path),
           fm.fileExists(atPath: legacyURL.path) {
            try? fm.copyItem(at: legacyURL, to: fileURL)
        }

        load()
        loadIdeas()
        if notes.isEmpty {
            let welcome = Note(
                title: "Welcome",
                blocks: [
                    TextBlock(x: 0, y: 0, text: "Click anywhere on this canvas to start typing."),
                    TextBlock(x: 0, y: 80, text: "⌘N for a new note  ·  ⌘0 to toggle the sidebar"),
                    TextBlock(x: 0, y: 140, text: "Empty blocks vanish when you click away.")
                ]
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

    var deletedSortedNotes: [Note] {
        notes
            .filter { $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    @discardableResult
    func addNote() -> Note.ID {
        let note = Note()
        notes.insert(note, at: 0)
        selection = note.id
        persistNow()
        return note.id
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

    func permanentlyDelete(noteID: Note.ID) {
        notes.removeAll { $0.id == noteID }
        if selection == noteID { selection = sortedNotes.first?.id }
        scheduleSave()
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

    var sortedIdeas: [Idea] {
        ideas.sorted { $0.createdAt < $1.createdAt }
    }

    func addIdea(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        ideas.append(Idea(text: trimmed))
        persistIdeasNow()
    }

    func deleteIdea(ideaID: Idea.ID) {
        ideas.removeAll { $0.id == ideaID }
        persistIdeasNow()
    }

    @discardableResult
    func promoteIdeaToNote(ideaID: Idea.ID) -> Note.ID? {
        guard let idx = ideas.firstIndex(where: { $0.id == ideaID }) else { return nil }
        let note = Note(blocks: [TextBlock(x: 20, y: 20, text: ideas[idx].text)])
        notes.insert(note, at: 0)
        selection = note.id
        ideas.remove(at: idx)
        persistNow()
        persistIdeasNow()
        return note.id
    }

    func fileIdea(ideaID: Idea.ID, into noteID: Note.ID) {
        guard let ideaIdx = ideas.firstIndex(where: { $0.id == ideaID }),
              let noteIdx = notes.firstIndex(where: { $0.id == noteID }) else { return }
        let y = notes[noteIdx].blocks.map(\.y).max().map { $0 + 40 } ?? 20
        notes[noteIdx].blocks.append(TextBlock(x: 20, y: y, text: ideas[ideaIdx].text))
        notes[noteIdx].updatedAt = Date()
        ideas.remove(at: ideaIdx)
        persistNow()
        persistIdeasNow()
    }

    private func loadIdeas() {
        guard let data = try? Data(contentsOf: ideasURL),
              let decoded = try? JSONDecoder().decode([Idea].self, from: data) else { return }
        ideas = decoded
    }

    private func persistIdeasNow() {
        guard let data = try? JSONEncoder().encode(ideas) else { return }
        try? data.write(to: ideasURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Note].self, from: data) else { return }
        notes = decoded
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
        try? data.write(to: fileURL, options: .atomic)
    }
}
