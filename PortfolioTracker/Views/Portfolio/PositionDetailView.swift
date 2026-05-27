import SwiftUI

struct PositionDetailView: View {
    @EnvironmentObject var api: APIClient
    let position: Position

    @State private var detail: StockPrice?
    @State private var isLoading = true
    @State private var showSell  = false
    @State private var errorMsg  = ""

    private var currentPrice: Double { detail?.price ?? position.avgBuyPrice }
    private var currentValue: Double { position.shares * currentPrice }
    private var pnl:          Double { currentValue - position.totalInvested }
    private var pnlPct:       Double { position.totalInvested > 0 ? pnl / position.totalInvested * 100 : 0 }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if isLoading {
                ProgressView("Loading…").foregroundStyle(.appSubtext)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                        statsGrid
                        if let d = detail { fundamentals(d) }
                        if let d = detail, let desc = d.description, !desc.isEmpty {
                            aboutCard(desc)
                        }
                        sellButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable { await loadDetail() }
            }
        }
        .navigationTitle(position.ticker)
        .navigationBarTitleDisplayMode(.large)
        .task { await loadDetail() }
        .sheet(isPresented: $showSell) {
            SellFromDetailSheet(position: position, currentPrice: currentPrice)
                .environmentObject(api)
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail?.name ?? position.ticker)
                        .font(.caption).foregroundStyle(.appSubtext)
                    Text(currentPrice.currency)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.appText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let pct = detail?.changePct {
                        Text(pct.pct)
                            .font(.title3.bold()).foregroundStyle(pct.gainColor)
                        Text("today")
                            .font(.caption2).foregroundStyle(.appSubtext)
                    }
                }
            }

            Divider().background(Color.appBorder)

            HStack {
                miniStat(label: "Value",  value: currentValue.currency)
                Divider().frame(height: 32).background(Color.appBorder)
                miniStat(label: "P&L",    value: pnl.currency,    color: pnl.gainColor)
                Divider().frame(height: 32).background(Color.appBorder)
                miniStat(label: "Return", value: pnlPct.pct,       color: pnlPct.gainColor)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            gridCell(label: "Shares",     value: position.shares.clean)
            gridCell(label: "Avg Cost",   value: position.avgBuyPrice.currency)
            gridCell(label: "Invested",   value: position.totalInvested.currency)
            gridCell(label: "Realized",   value: position.realizedPnl.currency, color: position.realizedPnl.gainColor)
        }
    }

    private func fundamentals(_ d: StockPrice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fundamentals")
                .font(.caption.bold()).foregroundStyle(.appSubtext)
                .padding(.leading, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                if let mc = d.marketCap  { gridCell(label: "Mkt Cap",    value: mc.compact) }
                if let pe = d.pe         { gridCell(label: "P/E Ratio",  value: String(format: "%.1f", pe)) }
                if let ep = d.eps        { gridCell(label: "EPS",        value: ep.currency) }
                if let b  = d.beta       { gridCell(label: "Beta",       value: String(format: "%.2f", b)) }
                if let h  = d.high52w    { gridCell(label: "52w High",   value: h.currency) }
                if let l  = d.low52w     { gridCell(label: "52w Low",    value: l.currency) }
                if let dy = d.dividendYield, dy > 0 {
                    gridCell(label: "Div Yield", value: String(format: "%.2f%%", dy))
                }
                if let s  = d.sector     { gridCell(label: "Sector",     value: s) }
            }
        }
    }

    private func aboutCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.caption.bold()).foregroundStyle(.appSubtext)
            Text(text)
                .font(.caption).foregroundStyle(.appSubtext)
                .lineLimit(6)
        }
        .padding(14)
        .cardStyle()
    }

    private var sellButton: some View {
        Button { showSell = true } label: {
            HStack {
                Image(systemName: "arrow.up.right.circle.fill")
                Text("Sell \(position.ticker)")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Color.appLoss)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.bottom, 8)
    }

    // MARK: - Helper views

    private func miniStat(label: String, value: String, color: Color = .appText) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.callout.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.appSubtext)
        }
        .frame(maxWidth: .infinity)
    }

    private func gridCell(label: String, value: String, color: Color = .appText) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.appSubtext)
            Text(value).font(.callout.bold()).foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Load

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }
        detail = try? await api.fetchStockDetail(ticker: position.ticker)
    }
}

// MARK: - Quick sell from detail

struct SellFromDetailSheet: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss

    let position: Position
    let currentPrice: Double

    @State private var sharesStr = ""
    @State private var priceStr  = ""
    @State private var commission = "0"
    @State private var tradeDate = Date()
    @State private var isSubmitting = false
    @State private var errorMsg  = ""

    private var shares: Double { Double(sharesStr) ?? 0 }
    private var price:  Double { Double(priceStr) ?? 0 }
    private var comm:   Double { Double(commission) ?? 0 }

    private let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("You hold \(position.shares.clean) shares · avg \(position.avgBuyPrice.currency)")
                        .font(.caption).foregroundStyle(.appSubtext)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Shares to Sell").font(.caption.bold()).foregroundStyle(.appSubtext).padding(.leading, 4)
                        TextField("0", text: $sharesStr).keyboardType(.decimalPad).sellFieldStyle()
                        Button("Sell All") { sharesStr = position.shares.clean }
                            .font(.caption.bold()).foregroundStyle(.appAccent).padding(.leading, 4)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sell Price").font(.caption.bold()).foregroundStyle(.appSubtext).padding(.leading, 4)
                        TextField("0.00", text: $priceStr).keyboardType(.decimalPad).sellFieldStyle()
                        Button("Use Market Price (\(currentPrice.currency))") {
                            priceStr = String(format: "%.2f", currentPrice)
                        }
                        .font(.caption.bold()).foregroundStyle(.appAccent).padding(.leading, 4)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Commission").font(.caption.bold()).foregroundStyle(.appSubtext).padding(.leading, 4)
                        TextField("0.00", text: $commission).keyboardType(.decimalPad).sellFieldStyle()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trade Date").font(.caption.bold()).foregroundStyle(.appSubtext).padding(.leading, 4)
                        DatePicker("", selection: $tradeDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact).labelsHidden()
                            .padding(12)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
                            .padding(.horizontal)
                    }

                    if !errorMsg.isEmpty {
                        Text(errorMsg).font(.caption).foregroundStyle(.appLoss)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appLoss.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8)).padding(.horizontal)
                    }

                    Button(action: { Task { await submit() } }) {
                        HStack {
                            if isSubmitting { ProgressView().tint(.white) }
                            Text(isSubmitting ? "Submitting…" : "Confirm Sell")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity).padding(14)
                        .background(shares > 0 && price > 0 ? Color.appLoss : Color.appBorder)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(shares <= 0 || price <= 0 || isSubmitting)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Sell \(position.ticker)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func submit() async {
        errorMsg = ""; isSubmitting = true; defer { isSubmitting = false }
        do {
            let resp = try await api.sell(SellRequest(
                ticker: position.ticker, shares: shares, price: price,
                commission: Double(commission) ?? 0, tradeDate: df.string(from: tradeDate)
            ))
            if resp.success { dismiss() } else { errorMsg = resp.error ?? "Unknown error" }
        } catch { errorMsg = error.localizedDescription }
    }
}

private extension View {
    func sellFieldStyle() -> some View {
        self.padding(12)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
            .foregroundStyle(Color.appText)
            .padding(.horizontal)
    }
}

private extension Double {
    var clean: String { self.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", self) : String(format: "%.4f", self) }
}
