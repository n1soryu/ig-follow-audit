import Foundation

public enum AuditError: LocalizedError, Equatable {
    case invalidJSON
    case unrecognizedFormat
    case htmlExport
    case missingFollowing
    case missingFollowers
    case unsupportedFile
    case invalidZip(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "One of the export files isn't valid JSON."
        case .unrecognizedFormat:
            return "The followers/following files aren't in a format this app recognizes."
        case .htmlExport:
            return "This export is in HTML format. Request a new download from Instagram with Format set to JSON."
        case .missingFollowing:
            return "Couldn't find following.json in this export."
        case .missingFollowers:
            return "Couldn't find any followers_*.json files in this export."
        case .unsupportedFile:
            return "Choose the .zip file from Instagram, or the folder you extracted it to."
        case .invalidZip(let reason):
            return "Couldn't read the .zip file (\(reason)). Try extracting it in Finder and opening the folder instead."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .missingFollowing, .missingFollowers:
            return "When requesting your data, make sure \"Followers and following\" is selected and Format is JSON."
        default:
            return nil
        }
    }
}
