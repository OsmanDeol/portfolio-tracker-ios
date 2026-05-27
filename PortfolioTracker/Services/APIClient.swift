import Foundation
import Combine

// MARK: - Network error

enum APIError: LocalizedError {
    case badURL
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .badURL:                return "Invalid server URL. Check Settings."
        case .httpError(let code):   return "Server error \(code)."
        case .decodingError(let e):  return "Data parse error: \(e.localizedDescription)"
        case .networkError(let e):   return "Network error: \(e.localizedDescription)"
        case .serverError(let msg):  return msg
        }
    }
}

// MARK: - APIClient

private let kBaseURL = "serverBaseURL"

final class APIClient: ObservableObject {

    @Published var baseURL: String

    init() {
        self.baseURL = UserDefaults.standard.string(forKey: kBaseURL) ?? "http://localhost:5050"
    }

    /// Persists the current baseURL to UserDefaults immediately.
    func saveURL() {
        UserDefaults.standard.set(baseURL, forKey: kBaseURL)
        UserDefaults.standard.synchronize()
    }

    // MARK: - Core request helpers

    private func url(_ path: String, query: [String: String] = [:]) throws -> URL {
        var components = URLComponents(string: baseURL + path)
            ?? { fatalError("bad base URL") }()
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.badURL }
        return url
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        let request = URLRequest(url: try url(path, query: query), timeoutInterval: 15)
        return try await perform(request)
    }

    private func post<Body: Encodable, Response: Decodable>(
        _ path: String, body: Body
    ) async throws -> Response {
        var request = URLRequest(url: try url(path), timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: try url(path), timeoutInterval: 15)
        request.httpMethod = "DELETE"
        return try await perform(request)
    }

    private func put<Body: Encodable, Response: Decodable>(
        _ path: String, body: Body
    ) async throws -> Response {
        var request = URLRequest(url: try url(path), timeoutInterval: 15)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                // Try to extract a server-side error message
                if let json = try? JSONDecoder().decode([String: String].self, from: data),
                   let msg = json["error"] {
                    throw APIError.serverError(msg)
                }
                throw APIError.httpError(http.statusCode)
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        } catch let err as APIError {
            throw err
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Portfolio

    func fetchPortfolio() async throws -> [Position] {
        try await get("/api/portfolio")
    }

    func fetchPrices(tickers: [String]) async throws -> [String: StockPrice] {
        let joined = tickers.joined(separator: ",")
        return try await get("/api/prices", query: ["tickers": joined])
    }

    func fetchStockDetail(ticker: String) async throws -> StockPrice {
        try await get("/api/stock/\(ticker)")
    }

    func fetchSparkline(ticker: String) async throws -> SparklineResponse {
        try await get("/api/sparkline/\(ticker)")
    }

    func buy(_ req: BuyRequest) async throws -> APIResponse {
        try await post("/api/portfolio/buy", body: req)
    }

    func sell(_ req: SellRequest) async throws -> APIResponse {
        try await post("/api/portfolio/sell", body: req)
    }

    func removePosition(ticker: String) async throws -> APIResponse {
        try await delete("/api/portfolio/\(ticker)")
    }

    // MARK: - Market Status

    func fetchMarketStatus() async throws -> MarketStatus {
        try await get("/api/market-status")
    }

    // MARK: - Watchlists

    func fetchWatchlists() async throws -> [Watchlist] {
        try await get("/api/watchlists")
    }

    func createWatchlist(name: String) async throws -> APIResponse {
        try await post("/api/watchlists", body: ["name": name])
    }

    func renameWatchlist(id: Int, name: String) async throws -> APIResponse {
        try await put("/api/watchlists/\(id)", body: ["name": name])
    }

    func addToWatchlist(watchlistId: Int, ticker: String) async throws -> APIResponse {
        try await post("/api/watchlists/\(watchlistId)/items", body: ["ticker": ticker])
    }

    func removeFromWatchlist(watchlistId: Int, ticker: String) async throws -> APIResponse {
        try await delete("/api/watchlists/\(watchlistId)/items/\(ticker)")
    }

    func fetchWatchlistPrices(watchlistId: Int) async throws -> [WatchlistPriceRow] {
        try await get("/api/watchlists/\(watchlistId)/prices")
    }

    // MARK: - Transactions & History

    func fetchTransactions() async throws -> [Transaction] {
        try await get("/api/transactions")
    }

    func fetchRealizedPnL() async throws -> [RealizedPnL] {
        try await get("/api/realized-pnl")
    }

    func deleteTransaction(id: Int) async throws -> APIResponse {
        try await delete("/api/transactions/\(id)")
    }

    // MARK: - AI Analyst

    func analyzeStock(ticker: String) async throws -> AIAnalysisResponse {
        try await post("/api/ai/analyze", body: AIAnalysisRequest(ticker: ticker))
    }

    // MARK: - Connection test

    func testConnection() async -> Bool {
        guard let _ = try? await fetchMarketStatus() else { return false }
        return true
    }
}
