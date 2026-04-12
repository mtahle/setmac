import Foundation
import os.log

private let log = Logger(subsystem: "com.v0id.setmac", category: "ManifestLoader")

private let supportedSchemaVersion = 1

enum ManifestLoadError: Error, CustomStringConvertible {
    case notFound
    case schemaVersionMismatch(found: Int, required: Int)
    case decodingFailed(String)

    var description: String {
        switch self {
        case .notFound:
            return "tools.json not found in app bundle or project directory."
        case let .schemaVersionMismatch(found, required):
            return "tools.json schema version \(found) is not supported (requires \(required)). Please update the app."
        case let .decodingFailed(detail):
            return "tools.json is malformed: \(detail)"
        }
    }
}

enum ManifestLoader {
    static func load() -> Result<ToolManifest, ManifestLoadError> {
        let urls = manifestCandidateURLs()
        guard !urls.isEmpty else {
            log.error("No manifest candidate paths found")
            return .failure(.notFound)
        }

        for url in urls {
            log.info("Loading manifest from: \(url.path, privacy: .public)")
            switch decode(from: url) {
            case let .success(manifest):
                guard manifest.schemaVersion == supportedSchemaVersion else {
                    log.error("Schema version mismatch: found \(manifest.schemaVersion), need \(supportedSchemaVersion)")
                    return .failure(.schemaVersionMismatch(
                        found: manifest.schemaVersion,
                        required: supportedSchemaVersion
                    ))
                }
                log.info("Loaded \(manifest.tools.count) tools from manifest")
                return .success(manifest)
            case let .failure(err):
                log.error("Failed to decode manifest from \(url.path, privacy: .public): \(err)")
            }
        }

        log.error("No manifest found in app bundle or dev path")
        return .failure(.notFound)
    }

    private static func manifestCandidateURLs() -> [URL] {
        var urls: [URL] = []

        if let bundledManifest = Bundle.main.url(forResource: "tools", withExtension: "json") {
            urls.append(bundledManifest)
        }

        let devManifest = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources")
            .appendingPathComponent("tools.json")
        if FileManager.default.fileExists(atPath: devManifest.path) {
            urls.append(devManifest)
        }

        return urls
    }

    private static func decode(from url: URL) -> Result<ToolManifest, ManifestLoadError> {
        guard let data = try? Data(contentsOf: url) else {
            return .failure(.decodingFailed("could not read file"))
        }
        do {
            let manifest = try JSONDecoder().decode(ToolManifest.self, from: data)
            return .success(manifest)
        } catch {
            return .failure(.decodingFailed(error.localizedDescription))
        }
    }
}
