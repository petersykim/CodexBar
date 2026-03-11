import Foundation

/// HTTP response cache with ETag/Last-Modified support (#7)
public actor ResponseCache {
    public init() {}
    
    public struct CachedResponse: Sendable {
        let data: Data
        let etag: String?
        let lastModified: Date?
        let cachedAt: Date
        
        public var isExpired: Bool {
            Date().timeIntervalSince(cachedAt) > 300  // 5 min TTL
        }
    }
    
    private var cache: [String: CachedResponse] = [:]
    
    public func get(_ key: String) -> CachedResponse? {
        guard let response = cache[key], !response.isExpired else { return nil }
        return response
    }
    
    public func set(_ key: String, data: Data, etag: String?, lastModified: Date?) {
        cache[key] = CachedResponse(
            data: data,
            etag: etag,
            lastModified: lastModified,
            cachedAt: Date())
    }
    
    public func remove(_ key: String) {
        cache.removeValue(forKey: key)
    }
    
    public func clear() {
        cache.removeAll()
    }
}

extension URLSession {
    /// Fetch with cache support - checks ETag/If-Modified-Since (#7)
    func dataWithCache(from url: URL, cache: ResponseCache?) async throws -> (Data, URLResponse) {
        let cacheKey = url.absoluteString
        
        // Check cache first
        if let cached = await cache?.get(cacheKey) {
            var request = URLRequest(url: url)
            if let etag = cached.etag {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            if let lastMod = cached.lastModified {
                request.setValue(lastMod.httpHeaderValue, forHTTPHeaderField: "If-Modified-Since")
            }
            
            let (data, response) = try await self.data(for: request)
            if let httpResp = response as? HTTPURLResponse {
                if httpResp.statusCode == 304 {
                    // Not modified - return cached data
                    return (cached.data, response)
                }
                // Updated - cache new response
                let newEtag = httpResp.allHeaderFields["Etag"] as? String
                let newLastMod = httpResp.lastModified
                await cache?.set(cacheKey, data: data, etag: newEtag, lastModified: newLastMod)
            }
            return (data, response)
        }
        
        // No cache - fetch and store
        let (data, response) = try await self.data(from: url)
        if let httpResp = response as? HTTPURLResponse {
            let etag = httpResp.allHeaderFields["Etag"] as? String
            let lastMod = httpResp.lastModified
            await cache?.set(cacheKey, data: data, etag: etag, lastModified: lastMod)
        }
        return (data, response)
    }
}

private extension Date {
    var httpHeaderValue: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: self)
    }
}

private extension HTTPURLResponse {
    var lastModified: Date? {
        guard let value = allHeaderFields["Last-Modified"] as? String else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)
    }
}
