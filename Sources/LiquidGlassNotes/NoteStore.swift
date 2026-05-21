import Foundation
import SwiftUI

struct Note: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var updatedAt: Date = Date()

    init(id: UUID = UUID(),
         title: String = "",
         body: String = "",
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, body, updatedAt, blocks
    }

    private struct LegacyBlock: Decodable {
        var x: Double
        var y: Double
        var text: String
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        if let body = try c.decodeIfPresent(String.self, forKey: .body) {
            self.body = body
        } else if let blocks = try c.decodeIfPresent([LegacyBlock].self, forKey: .blocks) {
            self.body = blocks
                .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
                .map(\.text)
                .joined(separator: "\n\n")
        } else {
            self.body = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(body, forKey: .body)
        try c.encode(updatedAt, forKey: .updatedAt)
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body
            .split(whereSeparator: \.isNewline)
            .first.map(String.init) ?? ""
        let trim = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return trim.isEmpty ? "New Note" : trim
    }

    var snippet: String {
        let titleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let lines = body
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.dropFirst(titleEmpty ? 1 : 0).first ?? ""
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
                body: """
                A simple, glassy place for thoughts.

                ⌘N for a new note  ·  ⌘0 to toggle the sidebar

                Start typing here, or hit ⌘N to begin.
                """
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
