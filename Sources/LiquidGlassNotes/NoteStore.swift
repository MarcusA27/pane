import Foundation
import SwiftUI

struct TextBlock: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var x: Double
    var y: Double
    var text: String = ""
}

struct Note: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var blocks: [TextBlock] = []
    var updatedAt: Date = Date()

    init(id: UUID = UUID(),
         title: String = "",
         blocks: [TextBlock] = [],
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.blocks = blocks
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, blocks, updatedAt, body
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
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
        try c.encode(updatedAt, forKey: .updatedAt)
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

@MainActor
final class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selection: Note.ID?

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let fm = FileManager.default
        let support = (try? fm.url(for: .applicationSupportDirectory,
                                   in: .userDomainMask,
                                   appropriateFor: nil,
                                   create: true)) ?? fm.homeDirectoryForCurrentUser
        let dir = support.appendingPathComponent("LiquidGlassNotes", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("notes.json")

        load()
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
        notes.sorted { $0.updatedAt > $1.updatedAt }
    }

    func addNote() {
        let note = Note()
        notes.insert(note, at: 0)
        selection = note.id
        persistNow()
    }

    func delete(_ id: Note.ID) {
        notes.removeAll { $0.id == id }
        if selection == id { selection = sortedNotes.first?.id }
        persistNow()
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
