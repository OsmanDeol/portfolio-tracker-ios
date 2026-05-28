import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var api: APIClient

    @State private var positions: [Position] = []
    @State private var prices:    [String: StockPrice] = [:]
    @State private var marketStatus: MarketStatus?
    @State private var isLoading  = false
    @State private var errorMsg   = ""
    @State private var showAdd    = false
    @State private var refreshTimer: Timer?

    // ── Computed summary ───────────────────────────────────────
    private var totalValue: Double {
        positions.reduce(0) { sum, p in
            sum + p.shares * (prices[p.ticker]?.price ?? p.avgBuyPrice)
        }
    }

    private var totalCost: Double {
        positions.reduce(0) { $0 + $1.totalInvested }
    }

    private var totalPnL: Double { totalValue - totalCost }

    private var dayPnL: Double {
        positions.reduce(0) { sum, p in
            guard let sp = prices[p.ticker] else { return sum }
            let change = (sp.changeAmt ?? 0) * p.shares
            return sum + change
        }
    }

    // ── Body ──────────────────────────────────────────────────
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if isLoading && positions.isEmpty {
                    ProgressView("Loading portfolio…")
                        .foregroundStyle(.appSubtext)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            summaryCard
                            if !errorMsg.isEmpty { errorBanner }
                            positionsList
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .refreshable { await reload() }
                }
            }
            .navigationTitle("Portfolio")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { marketBadge }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAdd, onDismiss: { Task { await reload() } }) {
                AddPositionSheet()
                    .environmentObject(api)
            }
        }
        .task { await reload() }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Sub-views

    private var summaryCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Value")
                        .font(.caption)
                        .foregroundStyle(.appSubtext)
                    Text(totalValue.currency)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.appText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("All-time P&L")
                        .font(.caption)
                        .foregroundStyle(.appSubtext)
                    Text(totalPnL.currency)
                        .font(.headline)
                        .foregroundStyle(totalPnL.gainColor)
                    let pct = totalCost > 0 ? totalPnL / totalCost * 100 : 0
                    Text(pct.pct)
                        .font(.caption)
                        .foregroundStyle(totalPnL.gainColor)
                }
            }
            .padding()

            Divider().background(Color.appBorder)

            HStack {
                statCell(label: "Day P&L", value: dayPnL.currency, color: dayPnL.gainColor)
                Divider().frame(height: 36).background(Color.appBorder)
                statCell(label: "Positions", value: "\(positions.count)", color: .appText)
                Divider().frame(height: 36).background(Color.appBorder)
                statCell(label: "Cost Basis", value: totalCost.currency, color: .appSubtext)
            }
            .padding(.vertical, 8)
        }
        .cardStyle()
    }

    private func statCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.callout, design: .rounded)).bold().foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.appSubtext)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var marketBadge: some View {
        if let ms = marketStatus {
            HStack(spacing: 4) {
                Circle()
                    .fill(ms.isOpen ? Color.appGain : Color.appLoss)
                    .frame(width: 7, height: 7)
                Text(ms.status.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(ms.isOpen ? .appGain : .appSubtext)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.appSurface.opacity(0.8))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
        }
    }

    private var positionsList: some View {
        LazyVStack(spacing: 10) {
            if positions.isEmpty {
                emptyState
            } else {
                ForEach(positions) { pos in
                    NavigationLink {
                        PositionDetailView(position: pos)
                            .environmentObject(api)
                    } label: {
                        PositionRow(position: pos, price: prices[pos.ticker])
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { await deletePosition(ticker: pos.ticker) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 44))
                .foregroundStyle(.appSubtext)
            Text("No positions yet")
                .font(.headline).foregroundStyle(.appText)
            Text("Tap + to add your first stock")
                .font(.subheadline).foregroundStyle(.appSubtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var errorBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text(errorMsg)
                .font(.caption)
        }
        .foregroundStyle(.appLoss)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appLoss.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appLoss.opacity(0.3)))
    }

    // MARK: - Actions

    private func reload() async {
        isLoading = true
        errorMsg = ""
        defer { isLoading = false }
        do {
            async let p = api.fetchPortfolio()
            async let m = api.fetchMarketStatus()
            let (loaded, ms) = try await (p, m)
            positions     = loaded
            marketStatus  = ms
            if !loaded.isEmpty {
                let tickers = loaded.map(\.ticker)
                prices = try await api.fetchPrices(tickers: tickers)
            }
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func deletePosition(ticker: String) async {
        _ = try? await api.removePosition(ticker: ticker)
        await reload()
    }

    private func startTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { await reload() }
        }
    }

    private func stopTimer() { refreshTimer?.invalidate(); refreshTimer = nil }
}

// MARK: - Position Row

struct PositionRow: View {
    let position: Position
    let price: StockPrice?

    private var currentPrice: Double  { price?.price ?? position.avgBuyPrice }
    private var currentValue: Double  { position.shares * currentPrice }
    private var pnl: Double           { currentValue - position.totalInvested }
    private var pnlPct: Double        { position.totalInvested > 0 ? pnl / position.totalInvested * 100 : 0 }
    private var dayChangePct: Double  { price?.changePct ?? 0 }

    var body: some View {
        HStack(spacing: 12) {
            // Ticker circle
            ZStack {
                Circle().fill(Color.appAccent.opacity(0.15))
                Text(String(position.ticker.prefix(2)))
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(.appAccent)
            }
            .frame(width: 40, height: 40)

            // Ticker + name
            VStack(alignment: .leading, spacing: 2) {
                Text(position.ticker)
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(.appText)
                Text("\(position.shares.clean) shares  ·  avg \(position.avgBuyPrice.currency)")
                    .font(.caption)
                    .foregroundStyle(.appSubtext)
            }

            Spacer()

            // Price + P&L
            VStack(alignment: .trailing, spacing: 2) {
                Text(currentValue.currency)
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(.appText)
                HStack(spacing: 6) {
                    changeBadge(pct: dayChangePct, label: "day")
                    changeBadge(pct: pnlPct, label: "total")
                }
            }
        }
        .padding(14)
        .cardStyle()
        .contentShape(Rectangle())
    }

    private func changeBadge(pct: Double, label: String) -> some View {
        Text("\(pct >= 0 ? "+" : "")\(String(format: "%.2f", pct))%")
            .font(.caption2.bold())
            .foregroundStyle(pct >= 0 ? .appGain : .appLoss)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background((pct >= 0 ? Color.appGain : Color.appLoss).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private extension Double {
    var clean: String { self.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", self)
        : String(format: "%.2f", self)
    }
}

#Preview {
    PortfolioView()
        .environmentObject(APIClient())
}
