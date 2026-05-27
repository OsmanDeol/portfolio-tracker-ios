import SwiftUI

enum HistoryTab: String, CaseIterable { case transactions = "Transactions", realized = "Realized P&L" }

struct HistoryView: View {
    @EnvironmentObject var api: APIClient

    @State private var activeTab: HistoryTab = .transactions
    @State private var transactions: [Transaction] = []
    @State private var realized: [RealizedPnL] = []
    @State private var isLoading = false
    @State private var filterTicker = ""

    // Totals
    private var totalRealized: Double { realized.reduce(0) { $0 + $1.netProfitLoss } }

    // Filtered transactions
    private var filteredTxns: [Transaction] {
        if filterTicker.isEmpty { return transactions }
        return transactions.filter { $0.ticker.contains(filterTicker.uppercased()) }
    }

    private var filteredRealized: [RealizedPnL] {
        if filterTicker.isEmpty { return realized }
        return realized.filter { $0.ticker.contains(filterTicker.uppercased()) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    tabPicker
                    searchBar
                    if isLoading {
                        Spacer()
                        ProgressView("Loading…").foregroundStyle(.appSubtext)
                        Spacer()
                    } else {
                        switch activeTab {
                        case .transactions: transactionsList
                        case .realized:     realizedList
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
        .task { await loadAll() }
    }

    // MARK: - Sub-views

    private var tabPicker: some View {
        Picker("", selection: $activeTab) {
            ForEach(HistoryTab.allCases, id: \.self) { t in Text(t.rawValue).tag(t) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease").foregroundStyle(.appSubtext)
            TextField("Filter by ticker…", text: $filterTicker)
                .textCase(.uppercase)
                .autocorrectionDisabled()
                .foregroundStyle(.appText)
            if !filterTicker.isEmpty {
                Button { filterTicker = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.appSubtext)
                }
            }
        }
        .padding(10)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    private var transactionsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if filteredTxns.isEmpty {
                    emptyState(icon: "clock", msg: "No transactions found")
                } else {
                    ForEach(filteredTxns) { txn in
                        TransactionRow(txn: txn)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
        .refreshable { await loadAll() }
    }

    private var realizedList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if !filteredRealized.isEmpty {
                    // Summary banner
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total Realized P&L").font(.caption).foregroundStyle(.appSubtext)
                            Text(totalRealized.currency)
                                .font(.headline.bold()).foregroundStyle(totalRealized.gainColor)
                        }
                        Spacer()
                        Text("\(filteredRealized.count) trades").font(.caption).foregroundStyle(.appSubtext)
                    }
                    .padding(14)
                    .cardStyle()
                }

                if filteredRealized.isEmpty {
                    emptyState(icon: "chart.bar", msg: "No realized trades yet")
                } else {
                    ForEach(filteredRealized) { pnl in
                        RealizedRow(pnl: pnl)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
        .refreshable { await loadAll() }
    }

    private func emptyState(icon: String, msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(.appSubtext)
            Text(msg).font(.headline).foregroundStyle(.appSubtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Load

    private func loadAll() async {
        isLoading = true; defer { isLoading = false }
        async let t = api.fetchTransactions()
        async let r = api.fetchRealizedPnL()
        transactions = (try? await t) ?? []
        realized     = (try? await r) ?? []
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let txn: Transaction

    private var isBuy: Bool { txn.type == "buy" }
    private var dateDisplay: String { txn.tradeDate ?? txn.createdAt ?? "" }

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                Circle()
                    .fill((isBuy ? Color.appGain : Color.appLoss).opacity(0.15))
                Image(systemName: isBuy ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundStyle(isBuy ? .appGain : .appLoss)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(txn.ticker)
                        .font(.system(.body, design: .rounded).bold()).foregroundStyle(.appText)
                    Text(txn.type.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isBuy ? .appGain : .appLoss)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background((isBuy ? Color.appGain : Color.appLoss).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text("\(txn.shares.clean) shares @ \(txn.price.currency)")
                    .font(.caption).foregroundStyle(.appSubtext)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(txn.total.currency)
                    .font(.callout.bold()).foregroundStyle(.appText)
                Text(dateDisplay)
                    .font(.caption2).foregroundStyle(.appSubtext)
            }
        }
        .padding(12)
        .cardStyle()
        .contentShape(Rectangle())
    }
}

// MARK: - Realized P&L Row

struct RealizedRow: View {
    let pnl: RealizedPnL

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((pnl.netProfitLoss >= 0 ? Color.appGain : Color.appLoss).opacity(0.15))
                Text(String(pnl.ticker.prefix(2)))
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(pnl.netProfitLoss >= 0 ? .appGain : .appLoss)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(pnl.ticker)
                    .font(.system(.body, design: .rounded).bold()).foregroundStyle(.appText)
                Text("\(pnl.sharesSold.clean) shares · sold \(pnl.sellPrice.currency)")
                    .font(.caption).foregroundStyle(.appSubtext)
                if let d = pnl.sellDate { Text(d).font(.caption2).foregroundStyle(.appSubtext) }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(pnl.netProfitLoss.currency)
                    .font(.callout.bold()).foregroundStyle(pnl.netProfitLoss.gainColor)
                Text(pnl.plPct.pct)
                    .font(.caption2).foregroundStyle(pnl.plPct.gainColor)
            }
        }
        .padding(12)
        .cardStyle()
    }
}

private extension Double {
    var clean: String { self.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", self) : String(format: "%.4f", self) }
}

#Preview {
    HistoryView().environmentObject(APIClient())
}
