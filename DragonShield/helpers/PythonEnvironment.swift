import Foundation

enum PythonEnvironment {
    static func sitePackagesSearchPaths(anchorFile: StaticString = #file) -> [String] {
        var paths: [String] = []
        let fm = FileManager.default

        if let folderURL = Bundle.main.url(forResource: "python_scripts", withExtension: nil) {
            let sitePackages = folderURL.appendingPathComponent("site-packages")
            if fm.fileExists(atPath: sitePackages.path) {
                paths.append(sitePackages.path)
            }
        }

        let moduleDir = URL(fileURLWithPath: "\(anchorFile)").deletingLastPathComponent()
        let localCandidates = [
            moduleDir.appendingPathComponent("python_scripts/site-packages").path,
            moduleDir.appendingPathComponent("../python_scripts/site-packages").path,
            moduleDir.appendingPathComponent("../../python_scripts/site-packages").path,
        ]

        for path in localCandidates where fm.fileExists(atPath: path) {
            paths.append(path)
        }

        return Array(Set(paths))
    }

    static func enrichedEnvironment(anchorFile: StaticString = #file) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let paths = sitePackagesSearchPaths(anchorFile: anchorFile)
        guard !paths.isEmpty else { return env }
        let joined = paths.joined(separator: ":")
        if let existing = env["PYTHONPATH"], !existing.isEmpty {
            env["PYTHONPATH"] = joined + ":" + existing
        } else {
            env["PYTHONPATH"] = joined
        }
        return env
    }
}
