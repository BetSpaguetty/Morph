import Foundation
import Observation

struct SavedMorphFile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var savedAt: Date
}

@MainActor
@Observable
final class SavedFilesStore {
    private(set) var files: [SavedMorphFile]

    private let fileManager = FileManager.default
    private let folderName = "MorphFiles"
    private let indexName = "index.json"

    init() {
        files = []
        loadIndex()
    }

    @discardableResult
    func save(_ text: String, updating id: UUID? = nil) throws -> SavedMorphFile {
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)

        var file: SavedMorphFile
        if let id, let existingIndex = files.firstIndex(where: { $0.id == id }) {
            file = files[existingIndex]
            file.savedAt = .now
            try text.write(to: fileURL(named: file.name), atomically: true, encoding: .utf8)
            files[existingIndex] = file
        } else {
            file = SavedMorphFile(id: UUID(), name: nextFileName(), savedAt: .now)
            try text.write(to: fileURL(named: file.name), atomically: true, encoding: .utf8)
            files.append(file)
        }

        files.sort { $0.savedAt > $1.savedAt }
        try persistIndex()
        return file
    }

    func content(for id: UUID) throws -> String {
        guard let file = files.first(where: { $0.id == id }) else {
            throw SavedFilesError.fileNotFound
        }
        return try String(contentsOf: fileURL(named: file.name), encoding: .utf8)
    }

    private var folderURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
    }

    private var indexURL: URL {
        folderURL.appendingPathComponent(indexName)
    }

    private func fileURL(named name: String) -> URL {
        folderURL.appendingPathComponent(name)
    }

    private func nextFileName() -> String {
        var number = 1
        while files.contains(where: { $0.name == "morph\(number).txt" }) {
            number += 1
        }
        return "morph\(number).txt"
    }

    private func loadIndex() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? decoder.decode([SavedMorphFile].self, from: data) else {
            return
        }
        files = decoded.sorted { $0.savedAt > $1.savedAt }
    }

    private func persistIndex() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(files)
        try data.write(to: indexURL, options: .atomic)
    }
}

private enum SavedFilesError: LocalizedError {
    case fileNotFound

    var errorDescription: String? {
        "Este arquivo não está mais disponível."
    }
}
