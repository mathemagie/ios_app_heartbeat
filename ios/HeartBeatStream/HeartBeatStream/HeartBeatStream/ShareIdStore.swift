import Foundation

final class ShareIdStore {
    private let key = "publicShareId"
    func loadOrCreate() -> String {
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let newId = String(UUID().uuidString.prefix(8)).lowercased()
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
