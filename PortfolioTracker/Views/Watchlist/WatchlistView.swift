import SwiftUI

struct WatchlistView: View {
    @EnvironmentObject var api: APIClient

    @State private var watchlists: [Watchlist] = []
    @State private var selectedId: Int?
    @State private var prices:     [WatchlistPriceRow] = []
    @State private var isLoading   = false
    @State private var pricesLoading = false
    @State private var errorMsg    = ""

    // Add watchlist
    @State private var showNewWL   = false
    @State private var newWLName   = ""
    // Add ticker
    @State private var showAddTicker = false
    @State private var newTicker   = ""

    private var selected: Watchlist? {
        watchlists.first { $0.id == selectedId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if !watchlists.isEmpty { watchlistPicker }
                    mainContent
                }
            }
            .navigationTitle("Watchlist")
            .toolbar { toolbarItems }
            .alert("New Watchlist", isPresented: $showNewWL) {
                TextField("Name", text: $newWLName)
                Button("Create") { Task { await createWatchlist() } }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Add Ticker", isPresented: $showAddTicker) {
                TextField("Ticker (e.g. TSLA)", text: $newTicker)
                    .textCase(.uppercase)
                Button("Add") { Task { await addTicker() } }
                Button("Cancel", role: .cancel) {}
            }
        }
        .task { await loadWatchlists() }
    }

    // MARK: - Sub-views

    private var watchlistPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(watchlists) { wl in
                    Button {
                        selectedId = wl.id
                        Task { await loadPrices(for: wl.id) }
                    } label: {
                        Text(wl.name)
                            .font(.subheadline.bold())
                            .foregroundStyle(selectedId == wl.id ? .black : .appText)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(selectedId == wl.id ? Color.appAccent : Color.appSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: selectedId == wl.id ? 0 : 1))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Color.appBackground)
    }

    @ViewBuilder
    private var mainContent: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading…").foregroundStyle(.appSubtext)
            Spacer()
        } else if watchlists.isEmpty {
            emptyWatchlistState
        } else if let wl = selected {
            if wl.items.isEmpty {
                emptyTickerState
            } else {
                priceList(wl: wl)
            }
        }
    }

    private var emptyWatchlistState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.slash").font(.system(size: 44)).foregroundStyle(.appSubtext)
            Text("No watchlists yet").font(.headline).foregroundStyle(.appText)
            Text("Tap + to create your first watchlist").font(.subheadline).foregroundStyle(.appSubtext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyTickerState: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle").font(.system(size: 44)).foregroundStyle(.appSubtext)
            Text("No stocks yet").font(.headline).foregroundStyle(.appText)
            Button("Add a ticker") { showAddTicker = true }
                .font(.subheadline.bold()).foregroundStyle(.appAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func priceList(wl: Watchlist) -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(prices) { row in
                    WatchlistRow(row: row)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await removeTicker(watchlistId: wl.id, ticker: row.ticker) }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
                if pricesLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding()
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .refreshable {
            if let id = selectedId { await loadPrices(for: id) }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { showNewWL = true } label: {
                Label("New List", systemImage: "plus.rectangle.on.folder")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { showAddTicker = true } label: {
                Image(systemName: "plus")
            }
            .disabled(selectedId == nil)
        }
    }

    // MARK: - Actions

    private func loadWatchlists() async {
        isLoading = true; defer { isLoading = false }
        do {
            watchlists = try await api.fetchWatchlists()
            if selectedId == nil, let first = watchlists.first {
                selectedId = first.id
                await loadPrices(for: first.id)
            } else if let id = selectedId {
                await loadPrices(for: id)
            }
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func loadPrices(for id: Int) async {
        pricesLoading = true; defer { pricesLoading = false }
        prices = (try? await api.fetchWatchlistPrices(watchlistId: id)) ?? []
    }

    private func createWatchlist() async {
        let name = newWLName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        newWLName = ""
        _ = try? await api.createWatchlist(name: name)
        await loadWatchlists()
    }

    private func addTicker() async {
        guard let id = selectedId else { return }
        let t = newTicker.uppercased().trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        newTicker = ""
        _ = try? await api.addToWatchlist(watchlistId: id, ticker: t)
        await loadWatchlists()
    }

    private func removeTicker(watchlistId: Int, ticker: String) async {
        _ = try? await api.removeFromWatchlist(watchlistId: watchlistId, ticker: ticker)
        await loadPrices(for: watchlistId)
    }
}

// MARK: - Watchlist Row

struct WatchlistRow: View {
    let row: WatchlistPriceRow

    private var displayChangePct: Double { row.changePct ?? 0 }

    var body: some View {
        HStack(spacing: 12) {
            // Ticker badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appAccent.opacity(0.15))
                Text(String(row.ticker.prefix(2)))
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(.appAccent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.ticker)
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(.appText)
                Text(row.name ?? "")
                    .font(.caption)
                    .foregroundStyle(.appSubtext)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(row.price.currency)
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(.appText)

                HStack(spacing: 4) {
                    // Pre/post market indicator
                    if row.prePrice != nil, let prePct = row.preChangePct {
                        extSessionBadge(label: "PRE", pct: prePct)
                    } else if row.postPrice != nil, let postPct = row.postChangePct {
                        extSessionBadge(label: "POST", pct: postPct)
                    }
                    changeBadge(pct: displayChangePct)
                }
            }
        }
        .padding(14)
        .cardStyle()
        .contentShape(Rectangle())
    }

    private func changeBadge(pct: Double) -> some View {
        Text(pct.pct)
            .font(.caption2.bold())
            .foregroundStyle(pct >= 0 ? .appGain : .appLoss)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background((pct >= 0 ? Color.appGain : Color.appLoss).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func extSessionBadge(label: String, pct: Double) -> some View {
        Text("\(label) \(pct.pct)")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color.orange)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    WatchlistView().environmentObject(APIClient())
}
