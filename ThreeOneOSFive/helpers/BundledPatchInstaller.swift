import Foundation

@MainActor
extension PatchProjectStore {
    func importBundledPatchesIfNeeded() {
        guard !isBusy else { return }
        guard let urls = Bundle.main.urls(
            forResourcesWithExtension: "3105",
            subdirectory: "BundledPatches"
        ), !urls.isEmpty else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            var knownPackageIDs = Set(items.map(\.id))
            for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                while isBusy {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                guard let data = try? Data(contentsOf: url) else { continue }
                guard let summary = try? PatchPackageCodec.inspect(data),
                      knownPackageIDs.insert(summary.packageID).inserted else {
                    continue
                }
                _ = importPackage(data: data, allowTargetOverlap: true)
            }
            while isBusy {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
}
