import Foundation

final class CustomAppNameManager {
    static let shared = CustomAppNameManager()

    private let defaultsKey = "customAppDisplayNamesByPath"
    private let defaults = UserDefaults.standard

    private init() {}

    func displayName(forAppURL url: URL, fallbackName: String) -> String {
        customName(forAppPath: url.path) ?? fallbackName
    }

    func customName(forAppPath appPath: String) -> String? {
        let trimmedPath = normalizedPath(appPath)
        guard !trimmedPath.isEmpty else { return nil }
        return storedNames[trimmedPath]
    }

    func setCustomName(_ name: String, forAppPath appPath: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = normalizedPath(appPath)
        guard !trimmedPath.isEmpty else { return }

        var names = storedNames
        if trimmedName.isEmpty {
            names.removeValue(forKey: trimmedPath)
        } else {
            names[trimmedPath] = trimmedName
        }
        storedNames = names
    }

    func resetCustomName(forAppPath appPath: String) {
        let trimmedPath = normalizedPath(appPath)
        guard !trimmedPath.isEmpty else { return }

        var names = storedNames
        names.removeValue(forKey: trimmedPath)
        storedNames = names
    }

    func hasCustomName(forAppPath appPath: String) -> Bool {
        customName(forAppPath: appPath) != nil
    }

    func resetAll() {
        defaults.removeObject(forKey: defaultsKey)
    }

    private var storedNames: [String: String] {
        get { defaults.dictionary(forKey: defaultsKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: defaultsKey) }
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }
}
