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

    func reload() {
        loadIndex()
    }

    private var folderURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
    }

    private var indexURL: URL {
        folderURL.appendingPathComponent(indexName)
    }

    private func fileURL(named name: String) -> URL {
        let managedURL = folderURL.appendingPathComponent(name)
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        if fileManager.fileExists(atPath: managedURL.path) || !fileManager.fileExists(atPath: documentsURL.path) {
            return managedURL
        }
        return documentsURL
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
        let decoded: [SavedMorphFile]
        if let data = try? Data(contentsOf: indexURL),
           let savedFiles = try? decoder.decode([SavedMorphFile].self, from: data) {
            decoded = savedFiles
        } else {
            decoded = []
        }

        // Rebuild missing index entries from text files that are still on disk.
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let urls = [folderURL, documentsURL].flatMap { directory in
            (try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
        }
        let knownByName = Dictionary(decoded.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        files = Dictionary(urls.filter { $0.pathExtension.lowercased() == "txt" }.map { ($0.lastPathComponent, $0) }, uniquingKeysWith: { first, _ in first })
            .values
            .compactMap { url in
                if let known = knownByName[url.lastPathComponent] {
                    return known
                }
                guard let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                    return nil
                }
                return SavedMorphFile(id: UUID(), name: url.lastPathComponent, savedAt: modifiedAt)
            }.sorted { $0.savedAt > $1.savedAt }

        if Set(files.map(\.name)) != Set(decoded.map(\.name)) {
            try? persistIndex()
        }
    }

    private func persistIndex() throws {
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
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
