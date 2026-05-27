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

    @State private var isLookingUp = false
    @State private var isSubmitting = false
    @State private var errorMsg    = ""
    @State private var lookupName  = ""

    private var shares: Double { Double(sharesStr) ?? 0 }
    private var price:  Double { Double(priceStr) ?? 0 }
    private var comm:   Double { Double(commission) ?? 0 }
    private var total:  Double { shares * price + (tradeType == .buy ? comm : -comm) }
    private var canSubmit: Bool { !ticker.isEmpty && shares > 0 && price > 0 && !isSubmitting }

    private let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

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
                            label("Ticker Symbol")
                            HStack {
                                TextField("e.g. AAPL", text: $ticker)
                                    .textCase(.uppercase)
                                    .autocorrectionDisabled()
                                    .onChange(of: ticker) { _, _ in lookupName = "" }
                                if isLookingUp {
                                    ProgressView().scaleEffect(0.7)
                                } else if !ticker.isEmpty {
                                    Button("Look up") { Task { await lookupPrice() } }
                                        .font(.caption.bold())
                                        .foregroundStyle(.appAccent)
                                }
                            }
                            .fieldStyle()
                            if !lookupName.isEmpty {
                                Text(lookupName)
                                    .font(.caption).foregroundStyle(.appSubtext)
                                    .padding(.leading, 4)
                            }
                        }

                        // Shares
                        inputField("Shares", text: $sharesStr, placeholder: "0", keyboard: .decimalPad)

                        // Price
                        inputField("Price per Share", text: $priceStr, placeholder: "0.00", keyboard: .decimalPad)

                        // Commission
                        inputField("Commission (optional)", text: $commission, placeholder: "0.00", keyboard: .decimalPad)

                        // Date
                        VStack(alignment: .leading, spacing: 6) {
                            label("Trade Date")
                            DatePicker("", selection: $tradeDate, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(12)
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
                        }

                        // Total preview
                        if shares > 0 && price > 0 {
                            HStack {
                                Text("Total \(tradeType == .buy ? "Cost" : "Proceeds")")
                                    .font(.subheadline).foregroundStyle(.appSubtext)
                                Spacer()
                                Text(total.currency)
                                    .font(.headline).foregroundStyle(.appText)
                            }
                            .padding(14)
                            .cardStyle()
                            .padding(.horizontal)
                        }

                        // Error
                        if !errorMsg.isEmpty {
                            Text(errorMsg)
                                .font(.caption).foregroundStyle(.appLoss)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.appLoss.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.horizontal)
                        }

                        // Submit
                        Button(action: { Task { await submit() } }) {
                            HStack {
                                if isSubmitting { ProgressView().tint(.white) }
                                Text(isSubmitting ? "Submitting…" : "\(tradeType.rawValue) \(ticker.uppercased().isEmpty ? "Stock" : ticker.uppercased())")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(canSubmit ? (tradeType == .buy ? Color.appGain : Color.appLoss) : Color.appBorder)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!canSubmit)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Add Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helper views

    private func label(_ text: String) -> some View {
        Text(text).font(.caption.bold()).foregroundStyle(.appSubtext).padding(.leading, 4)
    }

    private func inputField(
        _ title: String, text: Binding<String>,
        placeholder: String, keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label(title)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .fieldStyle()
        }
    }

    // MARK: - Actions

    private func lookupPrice() async {
        let t = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        isLookingUp = true
        defer { isLookingUp = false }
        if let sp = try? await api.fetchStockDetail(ticker: t) {
            lookupName = sp.name ?? t
            priceStr   = String(format: "%.2f", sp.price)
        }
    }

    private func submit() async {
        errorMsg = ""
        isSubmitting = true
        defer { isSubmitting = false }
        let t = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        let dateStr = df.string(from: tradeDate)
        do {
            let resp: APIResponse
            if tradeType == .buy {
                resp = try await api.buy(BuyRequest(ticker: t, shares: shares, price: price, commission: comm, tradeDate: dateStr))
            } else {
                resp = try await api.sell(SellRequest(ticker: t, shares: shares, price: price, commission: comm, tradeDate: dateStr))
            }
            if resp.success {
                dismiss()
            } else {
                errorMsg = resp.error ?? "Unknown error"
            }
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

// MARK: - Field style modifier

private extension View {
    func fieldStyle() -> some View {
        self
            .padding(12)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
            .foregroundStyle(Color.appText)
            .padding(.horizontal)
    }
}

#Preview {
    AddPositionSheet()
        .environmentObject(APIClient())
}
