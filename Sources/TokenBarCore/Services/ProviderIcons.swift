import AppKit

public enum ProviderIcons {
    private struct CacheKey: Hashable {
        let providerID: String
        let size: CGFloat
        let template: Bool
    }

    private static var cache: [CacheKey: NSImage] = [:]

    public static func icon(for providerID: String, size: CGFloat = 16, template: Bool = false) -> NSImage? {
        let key = CacheKey(providerID: providerID, size: size, template: template)
        if let cached = cache[key] { return cached }

        let resourceName = "ProviderIcon-\(providerID)"
        #if SWIFT_PACKAGE
        let moduleUrl = Bundle.module.url(forResource: resourceName, withExtension: "svg")
        #else
        let moduleUrl: URL? = nil
        #endif

        let url = moduleUrl ?? Bundle.main.url(forResource: resourceName, withExtension: "svg")

        guard let url,
              let data = try? Data(contentsOf: url),
              let source = NSImage(data: data) else { return nil }

        let resized = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            source.draw(in: rect)
            return true
        }
        resized.isTemplate = template
        cache[key] = resized
        return resized
    }
}
