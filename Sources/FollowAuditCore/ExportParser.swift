import Foundation

/// Parses the `followers_*.json` / `following.json` files from Instagram's
/// "Download Your Information" export.
///
/// Instagram has shipped a few shapes of these files over the years, so this is
/// deliberately lenient:
///
/// - The top level is either an array of entries (`followers_1.json`) or an
///   object wrapping one (`{"relationships_following": [...]}`).
/// - Each entry has a `string_list_data` array whose first item has `href`,
///   `timestamp` and usually `value` (the username). Newer `following.json`
///   files drop `value` and put the username in the entry's `title` instead,
///   with an `href` like `https://www.instagram.com/_u/username`.
public enum ExportParser {
    public static func parseAccounts(from data: Data) throws -> [Account] {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw AuditError.invalidJSON
        }

        guard let entries = entries(in: json) else {
            throw AuditError.unrecognizedFormat
        }
        return entries.compactMap(account(from:))
    }

    private static func entries(in json: Any) -> [[String: Any]]? {
        if let array = json as? [[String: Any]] {
            return array
        }
        if let object = json as? [String: Any] {
            // e.g. "relationships_following" / "relationships_followers".
            for key in object.keys.sorted() where key.hasPrefix("relationships_") {
                if let array = object[key] as? [[String: Any]] {
                    return array
                }
            }
        }
        return nil
    }

    private static func account(from entry: [String: Any]) -> Account? {
        let item = (entry["string_list_data"] as? [[String: Any]])?.first ?? [:]

        let candidates = [
            item["value"] as? String,
            entry["title"] as? String,
            (item["href"] as? String).flatMap(username(fromHref:)),
        ]
        guard let username = candidates.compactMap({ $0 }).first(where: isValidUsername) else {
            return nil
        }

        let date = (item["timestamp"] as? NSNumber).map {
            Date(timeIntervalSince1970: $0.doubleValue)
        }
        return Account(username: username, date: date)
    }

    /// `https://www.instagram.com/_u/name` or `https://www.instagram.com/name/` → `name`.
    static func username(fromHref href: String) -> String? {
        guard let url = URL(string: href) else { return nil }
        return url.pathComponents.last { $0 != "/" && $0 != "_u" }
    }

    /// Instagram usernames: letters, digits, `.` and `_`, up to 30 characters.
    static func isValidUsername(_ name: String) -> Bool {
        guard (1...30).contains(name.count) else { return false }
        return name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "_") }
    }
}
