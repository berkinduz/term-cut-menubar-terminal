import CryptoKit
import Foundation

public enum AppUpdateError: LocalizedError {
    case invalidRelease, downloadMismatch, invalidApplication, notWritable, installerMissing, requestFailed

    public var errorDescription: String? {
        switch self {
        case .invalidRelease: return "The latest release does not contain a verified Peeksh update. Try again later."
        case .downloadMismatch: return "The downloaded update could not be verified. Please try again."
        case .invalidApplication: return "The update does not contain the expected Peeksh application."
        case .notWritable: return "Move Peeksh to a writable Applications folder before updating."
        case .installerMissing: return "The update installer is missing. Please download Peeksh again."
        case .requestFailed: return "The update could not be downloaded. Please try again."
        }
    }
}

public struct AppRelease: Equatable, Sendable {
    public let version: String
    public let downloadURL: URL
    public let sha256: String

    public static func available(in data: Data, installedVersion: String) throws -> AppRelease? {
        struct Release: Decodable {
            struct Asset: Decodable {
                let name: String
                let browser_download_url: String
                let digest: String?
            }
            let tag_name: String
            let assets: [Asset]
        }
        let release = try JSONDecoder().decode(Release.self, from: data)
        let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        func components(_ value: String) -> [UInt]? {
            let parts = value.split(separator: ".", omittingEmptySubsequences: false)
            let numbers = parts.compactMap { UInt($0) }
            return numbers.count == 3 && parts.count == 3 ? numbers : nil
        }
        guard let candidate = components(version), let installed = components(installedVersion) else {
            throw AppUpdateError.invalidRelease
        }
        guard installed.lexicographicallyPrecedes(candidate) else { return nil }
        guard let asset = release.assets.first(where: { $0.name == "Peeksh.dmg" }),
              let url = URL(string: asset.browser_download_url),
              url.scheme == "https", url.host == "github.com",
              url.path == "/berkinduz/peeksh/releases/download/\(release.tag_name)/Peeksh.dmg",
              let digest = asset.digest, digest.hasPrefix("sha256:") else { throw AppUpdateError.invalidRelease }
        let hash = String(digest.dropFirst(7)).lowercased()
        guard hash.count == 64, hash.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw AppUpdateError.invalidRelease
        }
        return AppRelease(version: version, downloadURL: url, sha256: hash)
    }

    public func verifyDownload(at file: URL) throws {
        let digest = SHA256.hash(data: try Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
        guard digest == sha256 else { throw AppUpdateError.downloadMismatch }
    }
}
