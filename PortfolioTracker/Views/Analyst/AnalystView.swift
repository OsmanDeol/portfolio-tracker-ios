import SwiftUI

// MARK: - History item model

struct AnalysisHistoryItem: Identifiable {
    let id    = UUID()
    let ticker: String
    let analysis: String
}

// MARK: - Main view

struct AnalystView: View {
    @EnvironmentObject var api: APIClient

    @State private var ticker    = ""
    @State private var result    : AIAnalysisResponse?
    @State private var isLoading = false
    @State private var errorMsg  = ""
    @State private var history   : [AnalysisHistoryItem] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        searchBar
                        if isLoading        { loadingCard }
                        if !errorMsg.isEmpty { errorCard }
                        if let r = result   { resultCard(r) }
                        if !history.isEmpty && result == nil { historySection }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("AI Analyst")
        }
    }

    // MARK: - Sub-views

    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI-Powered Stock Analysis")
                .font(.caption.bold())
                .foregroundStyle(Color.appSubtext)

            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.appSubtext)
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

                Button(action: { Task { await analyze() } }) {
                    if isLoading {
                        ProgressView().tint(.white).frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.headline)
                            .foregroundStyle(Color.white)
                            .frame(width: 44, height: 44)
                            .background(ticker.isEmpty ? Color.appBorder : Color.appAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .disabled(ticker.isEmpty || isLoading)
            }

            Text("Powered by Groq · analyses price, fundamentals, and news")
                .font(.caption2)
                .foregroundStyle(Color.appSubtext)
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(Color.appAccent)
            VStack(spacing: 4) {
                Text("Analysing \(ticker.uppercased())…")
                    .font(.headline)
                    .foregroundStyle(Color.appText)
                Text("Fetching market data and generating insights")
                    .font(.caption)
                    .foregroundStyle(Color.appSubtext)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .cardStyle()
    }

    private var errorCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.appLoss)
            VStack(alignment: .leading, spacing: 4) {
                Text("Analysis Failed")
                    .font(.caption.bold())
                    .foregroundStyle(Color.appLoss)
                Text(errorMsg)
                    .font(.caption)
                    .foregroundStyle(Color.appSubtext)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appLoss.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appLoss.opacity(0.3)))
    }

    private func resultCard(_ r: AIAnalysisResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color.appAccent.opacity(0.15))
                        Image(systemName: "sparkles")
                            .font(.caption.bold())
                            .foregroundStyle(Color.appAccent)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.ticker)
                            .font(.headline.bold())
                            .foregroundStyle(Color.appText)
                        Text("AI Analysis")
                            .font(.caption2)
                            .foregroundStyle(Color.appSubtext)
                    }
                }
                Spacer()
                Button { result = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.appSubtext)
                }
            }

            Divider().background(Color.appBorder)

            AnalysisTextView(text: r.analysis)

            if let model = r.model {
                HStack {
                    Spacer()
                    Text("Model: \(model)")
                        .font(.caption2)
                        .foregroundStyle(Color.appSubtext.opacity(0.6))
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Analyses")
                .font(.caption.bold())
                .foregroundStyle(Color.appSubtext)
                .padding(.leading, 4)

            ForEach(Array(history.reversed())) { item in
                Button {
                    ticker = item.ticker
                    result = AIAnalysisResponse(analysis: item.analysis, ticker: item.ticker, model: nil)
                } label: {
                    HStack {
                        Text(item.ticker)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.appAccent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSubtext)
                    }
                    .padding(14)
                    .cardStyle()
                }
            }
        }
    }

    // MARK: - Actions

    private func analyze() async {
        let t = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        isLoading = true; errorMsg = ""; result = nil
        defer { isLoading = false }
        do {
            let r = try await api.analyzeStock(ticker: t)
            result = r
            if !history.contains(where: { $0.ticker == t }) {
                history.append(AnalysisHistoryItem(ticker: t, analysis: r.analysis))
                if history.count > 10 { history.removeFirst() }
            }
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

// MARK: - Analysis text renderer

struct AnalysisTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(paragraphs, id: \.self) { para in
                if para.hasPrefix("## ") {
                    Text(para.dropFirst(3))
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.appText)
                        .padding(.top, 4)
                } else if para.hasPrefix("# ") {
                    Text(para.dropFirst(2))
                        .font(.headline.bold())
                        .foregroundStyle(Color.appText)
                } else if para.hasPrefix("- ") || para.hasPrefix("• ") {
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(Color.appAccent)
                        Text(para.dropFirst(2))
                            .font(.callout)
                            .foregroundStyle(Color.appSubtext)
                    }
                } else if !para.isEmpty {
                    Text(para)
                        .font(.callout)
                        .foregroundStyle(Color.appSubtext)
                        .lineSpacing(4)
                }
            }
        }
    }

    private var paragraphs: [String] {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

#Preview {
    AnalystView().environmentObject(APIClient())
}
