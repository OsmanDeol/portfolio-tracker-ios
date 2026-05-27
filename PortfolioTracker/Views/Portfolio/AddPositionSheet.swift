import SwiftUI

enum TradeType: String, CaseIterable { case buy = "Buy", sell = "Sell" }

struct AddPositionSheet: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss

    @State private var tradeType  : TradeType = .buy
    @State private var ticker     = ""
    @State private var sharesStr  = ""
    @State private var priceStr   = ""
    @State private var commission = "0"
    @State private var tradeDate  = Date()

    @State private var isLookingUp  = false
    @State private var isSubmitting = false
    @State private var errorMsg     = ""
    @State private var lookupName   = ""

    private var shares: Double { Double(sharesStr) ?? 0 }
    private var price:  Double { Double(priceStr) ?? 0 }
    private var comm:   Double { Double(commission) ?? 0 }
    private var total:  Double { shares * price + (tradeType == .buy ? comm : -comm) }
    private var canSubmit: Bool { !ticker.isEmpty && shares > 0 && price > 0 && !isSubmitting }

    private let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader

                ScrollView {
                    VStack(spacing: 16) {

                        // Trade type
                        Picker("Type", selection: $tradeType) {
                            ForEach(TradeType.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // Ticker
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Ticker Symbol")
                            HStack {
                                TextField("e.g. AAPL", text: $ticker)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .onChange(of: ticker) { _, _ in lookupName = "" }
                                    .foregroundStyle(Color.appText)
                                if isLookingUp {
                                    ProgressView().scaleEffect(0.7)
                                } else if !ticker.isEmpty {
                                    Button("Look up") { Task { await lookupPrice() } }
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .styledField()
                            if !lookupName.isEmpty {
                                Text(lookupName)
                                    .font(.caption)
                                    .foregroundStyle(Color.appSubtext)
                                    .padding(.leading, 20)
                            }
                        }

                        inputField("Shares",                  text: $sharesStr,  placeholder: "0",    keyboard: .decimalPad)
                        inputField("Price per Share",          text: $priceStr,   placeholder: "0.00", keyboard: .decimalPad)
                        inputField("Commission (optional)",    text: $commission, placeholder: "0.00", keyboard: .decimalPad)

                        // Date picker
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Trade Date")
                            DatePicker("", selection: $tradeDate, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(12)
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
                                .padding(.horizontal)
                        }

                        // Total preview
                        if shares > 0 && price > 0 {
                            HStack {
                                Text("Total \(tradeType == .buy ? "Cost" : "Proceeds")")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSubtext)
                                Spacer()
                                Text(total.currency)
                                    .font(.headline)
                                    .foregroundStyle(Color.appText)
                            }
                            .padding(14)
                            .cardStyle()
                            .padding(.horizontal)
                        }

                        // Error banner
                        if !errorMsg.isEmpty {
                            Text(errorMsg)
                                .font(.caption)
                                .foregroundStyle(Color.appLoss)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.appLoss.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.horizontal)
                        }

                        // Submit button
                        Button(action: { Task { await submit() } }) {
                            HStack {
                                if isSubmitting { ProgressView().tint(.white) }
                                Text(isSubmitting ? "Submitting…" : "\(tradeType.rawValue) \(ticker.uppercased().isEmpty ? "Stock" : ticker.uppercased())")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(canSubmit
                                ? (tradeType == .buy ? Color.appGain : Color.appLoss)
                                : Color.appBorder)
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!canSubmit)
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 16)
                }
            }
        }
    }

    // MARK: - Header (replaces NavigationStack + toolbar to avoid ambiguity)

    private var sheetHeader: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .foregroundStyle(Color.appSubtext)
            Spacer()
            Text("Add Trade")
                .font(.headline)
                .foregroundStyle(Color.appText)
            Spacer()
            Color.clear.frame(width: 56) // visual balance
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.appSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appBorder).frame(height: 1)
        }
    }

    // MARK: - Helper views

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(Color.appSubtext)
            .padding(.leading, 20)
    }

    private func inputField(
        _ title: String, text: Binding<String>,
        placeholder: String, keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(title)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .foregroundStyle(Color.appText)
                .styledField()
        }
    }

    // MARK: - Actions

    private func lookupPrice() async {
        let t = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        isLookingUp = true; defer { isLookingUp = false }
        if let sp = try? await api.fetchStockDetail(ticker: t) {
            lookupName = sp.name ?? t
            priceStr   = String(format: "%.2f", sp.price)
        }
    }

    private func submit() async {
        errorMsg = ""; isSubmitting = true; defer { isSubmitting = false }
        let t = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        let dateStr = df.string(from: tradeDate)
        do {
            let resp: APIResponse
            if tradeType == .buy {
                resp = try await api.buy(BuyRequest(ticker: t, shares: shares, price: price, commission: comm, tradeDate: dateStr))
            } else {
                resp = try await api.sell(SellRequest(ticker: t, shares: shares, price: price, commission: comm, tradeDate: dateStr))
            }
            if resp.success { dismiss() }
            else { errorMsg = resp.error ?? "Unknown error" }
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

// MARK: - Text field style

private extension View {
    func styledField() -> some View {
        self
            .padding(12)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
            .padding(.horizontal)
    }
}

#Preview {
    AddPositionSheet().environmentObject(APIClient())
}
