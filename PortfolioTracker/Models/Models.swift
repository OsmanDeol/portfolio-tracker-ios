import Foundation

// MARK: - Portfolio

struct Position: Codable, Identifiable {
    let id: Int
    let ticker: String
    let shares: Double
    let avgBuyPrice: Double
    let totalInvested: Double
    let realizedPnl: Double

    enum CodingKeys: String, CodingKey {
        case id, ticker, shares
        case avgBuyPrice   = "avg_buy_price"
        case totalInvested = "total_invested"
        case realizedPnl   = "realized_pnl"
    }
}

// MARK: - Prices

struct StockPrice: Codable {
    let price: Double
    let prev: Double?
    let changeAmt: Double?
    let changePct: Double?
    let prePrice: Double?
    let preChangePct: Double?
    let postPrice: Double?
    let postChangePct: Double?
    let name: String?
    let marketCap: Double?
    let volume: Int?
    let avgVolume: Int?
    let high52w: Double?
    let low52w: Double?
    let pe: Double?
    let eps: Double?
    let beta: Double?
    let dividendYield: Double?
    let sector: String?
    let exchange: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case price, prev, name, sector, exchange, beta, description
        case changeAmt      = "change_amt"
        case changePct      = "change_pct"
        case prePrice       = "pre_price"
        case preChangePct   = "pre_change_pct"
        case postPrice      = "post_price"
        case postChangePct  = "post_change_pct"
        case marketCap      = "market_cap"
        case volume
        case avgVolume      = "avg_volume"
        case high52w        = "high_52w"
        case low52w         = "low_52w"
        case pe, eps
        case dividendYield  = "dividend_yield"
    }
}

// MARK: - Market Status

struct MarketStatus: Codable {
    let isOpen: Bool
    let session: String   // "pre", "open", "post", "closed"
    let nyTime: String

    enum CodingKeys: String, CodingKey {
        case isOpen  = "is_open"
        case session
        case nyTime  = "ny_time"
    }
}

// MARK: - Watchlist

struct Watchlist: Codable, Identifiable {
    let id: Int
    let name: String
    var items: [WatchlistItem]
}

struct WatchlistItem: Codable, Identifiable {
    let id: Int
    let ticker: String
}

struct WatchlistPriceRow: Codable, Identifiable {
    var id: String { ticker }
    let ticker: String
    let name: String?
    let price: Double
    let changePct: Double?
    let prePrice: Double?
    let preChangePct: Double?
    let postPrice: Double?
    let postChangePct: Double?

    enum CodingKeys: String, CodingKey {
        case ticker, name, price
        case changePct    = "change_pct"
        case prePrice     = "pre_price"
        case preChangePct = "pre_change_pct"
        case postPrice    = "post_price"
        case postChangePct = "post_change_pct"
    }
}

// MARK: - Transactions & History

struct Transaction: Codable, Identifiable {
    let id: Int
    let ticker: String
    let type: String        // "buy" | "sell"
    let shares: Double
    let price: Double
    let commission: Double
    let total: Double
    let tradeDate: String?
    let createdAt: String?
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, ticker, type, shares, price, commission, total
        case tradeDate  = "trade_date"
        case createdAt  = "created_at"
        case deletedAt  = "deleted_at"
    }
}

struct RealizedPnL: Codable, Identifiable {
    let id: Int
    let ticker: String
    let sellDate: String?
    let sharesSold: Double
    let sellPrice: Double
    let costBasis: Double
    let grossProfit: Double
    let commission: Double
    let netProfitLoss: Double
    let plPct: Double

    enum CodingKeys: String, CodingKey {
        case id, ticker
        case sellDate     = "sell_date"
        case sharesSold   = "shares_sold"
        case sellPrice    = "sell_price"
        case costBasis    = "cost_basis"
        case grossProfit  = "gross_profit"
        case commission
        case netProfitLoss = "net_profit_loss"
        case plPct        = "pl_pct"
    }
}

// MARK: - AI

struct AIAnalysisRequest: Codable {
    let ticker: String
}

struct AIAnalysisResponse: Codable {
    let analysis: String
    let ticker: String
    let model: String?
}

// MARK: - Trade Requests

struct BuyRequest: Codable {
    let ticker: String
    let shares: Double
    let price: Double
    let commission: Double
    let tradeDate: String

    enum CodingKeys: String, CodingKey {
        case ticker, shares, price, commission
        case tradeDate = "trade_date"
    }
}

struct SellRequest: Codable {
    let ticker: String
    let shares: Double
    let price: Double
    let commission: Double
    let tradeDate: String

    enum CodingKeys: String, CodingKey {
        case ticker, shares, price, commission
        case tradeDate = "trade_date"
    }
}

// MARK: - Generic API Response

struct APIResponse: Codable {
    let success: Bool
    let error: String?
}

// MARK: - Sparkline

struct SparklineResponse: Codable {
    let ticker: String
    let prices: [Double]
    let timestamps: [Double]
}
