import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var api: APIClient

    @State private var editingURL  = ""
    @State private var isEditing   = false
    @State private var isTesting   = false
    @State private var testResult  : Bool?
    @State private var appVersion  = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List {
                    serverSection
                    aboutSection
                    distributionSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .onAppear { editingURL = api.baseURL }
        }
    }

    // MARK: - Sections

    private var serverSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Server URL")
                    .font(.caption.bold()).foregroundStyle(.appSubtext)

                if isEditing {
                    TextField("http://192.168.1.x:5050", text: $editingURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .foregroundStyle(.appText)
                        .font(.system(.body, design: .monospaced))

                    HStack(spacing: 10) {
                        Button("Cancel") {
                            editingURL = api.baseURL
                            isEditing = false
                        }
                        .foregroundStyle(.appSubtext)

                        Spacer()

                        Button("Save") {
                            api.baseURL = editingURL.trimmingCharacters(in: .init(charactersIn: "/"))
                            isEditing = false
                            testResult = nil
                        }
                        .font(.headline)
                        .foregroundStyle(.appAccent)
                    }
                } else {
                    Text(api.baseURL)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.appText)
                        .onTapGesture { isEditing = true }
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.appSurface)

            // Test connection button
            Button(action: { Task { await testConnection() } }) {
                HStack {
                    if isTesting {
                        ProgressView().tint(.appAccent).scaleEffect(0.8)
                        Text("Testing…").foregroundStyle(.appSubtext)
                    } else if let ok = testResult {
                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(ok ? .appGain : .appLoss)
                        Text(ok ? "Connected successfully" : "Cannot reach server")
                            .foregroundStyle(ok ? .appGain : .appLoss)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(.appAccent)
                        Text("Test Connection")
                            .foregroundStyle(.appAccent)
                    }
                    Spacer()
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Server").foregroundStyle(.appSubtext)
        } footer: {
            Text("Set this to your Flask server's IP address and port. On home Wi-Fi use your Mac's IP (Settings → Wi-Fi → (i)).\nFor remote access deploy to Railway and paste the HTTPS URL.")
                .foregroundStyle(.appSubtext)
                .font(.caption)
        }
    }

    private var aboutSection: some View {
        Section {
            settingRow(icon: "tag.fill", label: "App Version", value: appVersion)
            settingRow(icon: "globe", label: "Backend", value: "Flask + yfinance + Groq")
            Link(destination: URL(string: "https://github.com/OsmanDeol/portfolio-tracker")!) {
                HStack {
                    Label("Source Code (Backend)", systemImage: "chevron.left.forwardslash.chevron.right")
                        .foregroundStyle(.appAccent)
                    Spacer()
                    Image(systemName: "arrow.up.right.square").foregroundStyle(.appSubtext)
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("About").foregroundStyle(.appSubtext)
        }
    }

    private var distributionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("AltStore / Sideloading", systemImage: "iphone")
                    .font(.subheadline.bold()).foregroundStyle(.appText)
                Text("This app is distributed via AltStore for free. Your phone must be connected to the same Wi-Fi as your PC once a week for AltStore to auto-renew the signing certificate. You don't need to do anything — it happens in the background.")
                    .font(.caption).foregroundStyle(.appSubtext)
                    .lineSpacing(3)

                Divider().background(Color.appBorder)

                Label("Tips for best experience", systemImage: "lightbulb.fill")
                    .font(.caption.bold()).foregroundStyle(.appSubtext)
                VStack(alignment: .leading, spacing: 4) {
                    tip("Keep your server Mac and iPhone on the same Wi-Fi")
                    tip("For remote access, deploy backend to Railway (free tier)")
                    tip("Prices auto-refresh every 30 seconds")
                    tip("Pull down on any list to force refresh")
                }
            }
            .padding(.vertical, 6)
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Distribution").foregroundStyle(.appSubtext)
        }
    }

    // MARK: - Helper views

    private func settingRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundStyle(.appText)
            Spacer()
            Text(value).foregroundStyle(.appSubtext).font(.callout)
        }
        .listRowBackground(Color.appSurface)
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundStyle(.appAccent)
            Text(text).font(.caption).foregroundStyle(.appSubtext)
        }
    }

    // MARK: - Actions

    private func testConnection() async {
        isTesting = true; defer { isTesting = false }
        testResult = await api.testConnection()
    }
}

#Preview {
    SettingsView().environmentObject(APIClient())
}
