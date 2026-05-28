import SwiftUI

// MARK: - History item

struct AnalysisHistoryItem: Identifiable {
    let id       = UUID()
    let ticker:   String
    let price:    Double?
    let analysis: AIAnalysis
}

// MARK: - Main view

struct AnalystView: View {
    @EnvironmentObject var api: APIClient
    @AppStorage("groqAPIKey") private var groqAPIKey: String = ""

    @State private var ticker    = ""
    @State private var response  : AIAnalysisResponse?
    @State private var isLoading = false
    @State private var errorMsg  = ""
    @State private var history   : [AnalysisHistoryItem] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        if groqAPIKey.isEmpty { apiKeyBanner }
                        searchBar
                        if isLoading         { loadingCard }
                        if !errorMsg.isEmpty { errorCard }
                        if let r = response  { resultCard(r) }
                        if !history.isEmpty && response == nil { historySection }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("AI Analyst")
        }
    }

    // MARK: - API key banner

    private var apiKeyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .foregroundStyle(Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Groq API Key Required")
                    .font(.caption.bold())
                    .foregroundStyle(Color.appText)
                Text("Add your key in Settings → Groq API Key")
                    .font(.caption2)
                    .foregroundStyle(Color.appSubtext)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3)))
    }

    // MARK: - Search bar

    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI-Powered Stock Analysis")
                .font(.caption.bold())
                .foregroundStyle(Color.appSubtext)

            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.appSubtext)
                    TextField("Enter ticker (e.g. AAPL)", text: $ticker)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await analyze() } }
                        .foregroundStyle(Color.appText)
                }
                .padding(12)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder))

                Button { Task { await analyze() } } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "sparkles").font(.headline).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(ticker.isEmpty ? Color.appBorder : Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(ticker.isEmpty || isLoading)
            }

            Text("Powered by Groq · analyses price, fundamentals, macro & news")
                .font(.caption2).foregroundStyle(Color.appSubtext)
        }
    }

    // MARK: - Loading

    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4).tint(Color.appAccent)
            VStack(spacing: 4) {
                Text("Analysing \(ticker.uppercased())…")
                    .font(.headline).foregroundStyle(Color.appText)
                Text("Fetching market data and generating insights")
                    .font(.caption).foregroundStyle(Color.appSubtext)
            }
        }
        .frame(maxWidth: .infinity).padding(32).cardStyle()
    }

    // MARK: - Error

    private var errorCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.appLoss)
            VStack(alignment: .leading, spacing: 4) {
                Text("Analysis Failed").font(.caption.bold()).foregroundStyle(Color.appLoss)
                Text(errorMsg).font(.caption).foregroundStyle(Color.appSubtext)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appLoss.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appLoss.opacity(0.3)))
    }

    // MARK: - Result card

    private func resultCard(_ r: AIAnalysisResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Header ───────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.ticker).font(.title2.bold()).foregroundStyle(Color.appText)
                    if let price = r.price {
                        Text(price.currency).font(.subheadline).foregroundStyle(Color.appSubtext)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    recommendationBadge(r.analysis.recommendation)
                    confidencePill(r.analysis.confidence)
                }
                Button { response = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.appSubtext).padding(.leading, 8)
                }
            }

            Divider().background(Color.appBorder)

            // ── Summary ───────────────────────────────────────────
            Text(r.analysis.summary)
                .font(.callout).foregroundStyle(Color.appSubtext).lineSpacing(4)

            // ── Price targets ─────────────────────────────────────
            HStack(spacing: 12) {
                targetCell(label: "Price Target Low",  value: r.analysis.priceTargetLow.currency)
                Divider().frame(height: 36).background(Color.appBorder)
                targetCell(label: "Price Target High", value: r.analysis.priceTargetHigh.currency)
                Divider().frame(height: 36).background(Color.appBorder)
                targetCell(label: "Horizon", value: shortHorizon(r.analysis.timeHorizon))
            }
            .padding(12)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // ── Signal chips ──────────────────────────────────────
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                signalChip(label: "Valuation",  value: r.analysis.valuation,  color: valuationColor(r.analysis.valuation))
                signalChip(label: "Momentum",   value: r.analysis.momentum,   color: momentumColor(r.analysis.momentum))
                signalChip(label: "Quality",    value: r.analysis.quality,    color: qualityColor(r.analysis.quality))
                signalChip(label: "Macro Risk", value: r.analysis.macroRisk,  color: riskColor(r.analysis.macroRisk))
            }

            Divider().background(Color.appBorder)

            // ── Bull / Bear ───────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                caseColumn(title: "Bull Case", items: r.analysis.bullCase, color: Color.appGain)
                caseColumn(title: "Bear Case", items: r.analysis.bearCase, color: Color.appLoss)
            }

            Divider().background(Color.appBorder)

            // ── Detail sections ───────────────────────────────────
            detailSection(icon: "chart.line.uptrend.xyaxis", title: "Technicals",   body: r.analysis.technicals)
            detailSection(icon: "building.columns",          title: "Fundamentals", body: r.analysis.fundamentals)
            detailSection(icon: "globe.americas",            title: "Macro Impact", body: r.analysis.macroImpact)
            detailSection(icon: "newspaper",                 title: "News Impact",  body: r.analysis.newsImpact)
        }
        .padding(16).cardStyle()
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Analyses")
                .font(.caption.bold()).foregroundStyle(Color.appSubtext).padding(.leading, 4)

            ForEach(history.reversed()) { item in
                Button {
                    ticker   = item.ticker
                    response = AIAnalysisResponse(
                        success: true, ticker: item.ticker,
                        price: item.price, analysis: item.analysis)
                } label: {
                    HStack {
                        recommendationBadge(item.analysis.recommendation)
                        Text(item.ticker)
                            .font(.subheadline.bold()).foregroundStyle(Color.appText)
                        Spacer()
                        Text("Confidence \(item.analysis.confidence)/10")
                            .font(.caption2).foregroundStyle(Color.appSubtext)
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(Color.appSubtext)
                    }
                    .padding(14).cardStyle()
                }
            }
        }
    }

    // MARK: - Helper views

    private func recommendationBadge(_ rec: String) -> some View {
        let color: Color = rec == "BUY" ? .appGain : rec == "SELL" ? .appLoss : .orange
        return Text(rec)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func confidencePill(_ score: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(1...10, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= score ? Color.appAccent : Color.appBorder)
                    .frame(width: 6, height: 10)
            }
        }
    }

    private func targetCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.callout.bold()).foregroundStyle(Color.appText)
            Text(label).font(.caption2).foregroundStyle(Color.appSubtext)
        }
        .frame(maxWidth: .infinity)
    }

    private func signalChip(label: String, value: String, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundStyle(Color.appSubtext)
                Text(value).font(.caption.bold()).foregroundStyle(color)
            }
            Spacer()
            Circle().fill(color.opacity(0.25)).frame(width: 8, height: 8)
        }
        .padding(10)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func caseColumn(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.bold()).foregroundStyle(color)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text(title == "Bull Case" ? "↑" : "↓")
                        .font(.caption2.bold()).foregroundStyle(color)
                    Text(item).font(.caption).foregroundStyle(Color.appSubtext).lineSpacing(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailSection(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption.bold()).foregroundStyle(Color.appSubtext)
            Text(body)
                .font(.caption).foregroundStyle(Color.appSubtext).lineSpacing(3)
        }
    }

    // MARK: - Color helpers

    private func valuationColor(_ v: String) -> Color {
        switch v { case "Cheap": return .appGain; case "Expensive": return .appLoss; default: return .orange }
    }
    private func momentumColor(_ v: String) -> Color {
        switch v { case "Strong": return .appGain; case "Weak": return .appLoss; default: return .orange }
    }
    private func qualityColor(_ v: String) -> Color {
        switch v { case "High": return .appGain; case "Low": return .appLoss; default: return .orange }
    }
    private func riskColor(_ v: String) -> Color {
        switch v { case "Low": return .appGain; case "High": return .appLoss; default: return .orange }
    }
    private func shortHorizon(_ h: String) -> String {
        if h.contains("Short") { return "Short-term" }
        if h.contains("Medium") { return "Mid-term" }
        return "Long-term"
    }

    // MARK: - Analyze action

    private func analyze() async {
        let t = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        isLoading = true; errorMsg = ""; response = nil
        defer { isLoading = false }
        do {
            let r = try await api.analyzeStock(ticker: t)
            response = r
            if !history.contains(where: { $0.ticker == t }) {
                history.append(AnalysisHistoryItem(ticker: t, price: r.price, analysis: r.analysis))
                if history.count > 10 { history.removeFirst() }
            }
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

#Preview {
    AnalystView().environmentObject(APIClient())
}
