import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var api: APIClient

    @State private var editingURL = ""
    @State private var isEditing  = false
    @State private var isTesting  = false
    @State private var testResult : Bool?
    @State private var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"

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

    // MARK: - Server section

    private var serverSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Server URL")
                    .font(.caption.bold())
                    .foregroundStyle(Color.appSubtext)

                if isEditing {
                    TextField("http://192.168.1.x:5050", text: $editingURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .foregroundStyle(Color.appText)
                        .font(.system(.body, design: .monospaced))

                    HStack(spacing: 10) {
                        Button("Cancel") {
                            editingURL = api.baseURL
                            isEditing = false
                        }
                        .foregroundStyle(Color.appSubtext)

                        Spacer()

                        Button("Save") {
                            api.baseURL = editingURL.trimmingCharacters(in: .init(charactersIn: "/"))
                            isEditing = false
                            testResult = nil
                        }
                        .font(.headline)
                        .foregroundStyle(Color.appAccent)
                    }
                } else {
                    Text(api.baseURL)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.appText)
                        .onTapGesture { isEditing = true }
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.appSurface)

            Button(action: { Task { await testConnection() } }) {
                HStack {
                    if isTesting {
                        ProgressView().tint(Color.appAccent).scaleEffect(0.8)
                        Text("Testing…").foregroundStyle(Color.appSubtext)
                    } else if let ok = testResult {
                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(ok ? Color.appGain : Color.appLoss)
                        Text(ok ? "Connected successfully" : "Cannot reach server")
                            .foregroundStyle(ok ? Color.appGain : Color.appLoss)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(Color.appAccent)
                        Text("Test Connection")
                            .foregroundStyle(Color.appAccent)
                    }
                    Spacer()
                }
            }
            .listRowBackground(Color.appSurface)

        } header: {
            Text("Server").foregroundStyle(Color.appSubtext)
        } footer: {
            Text("Set this to your Flask server's IP and port. On home Wi-Fi use your Mac's local IP (e.g. 192.168.1.x:5050). For remote access, use a Tailscale IP or a Railway HTTPS URL.")
                .foregroundStyle(Color.appSubtext)
                .font(.caption)
        }
    }

    // MARK: - About section

    private var aboutSection: some View {
        Section {
            settingRow(icon: "tag.fill",  label: "App Version", value: appVersion)
            settingRow(icon: "globe",     label: "Backend",     value: "Flask + yfinance + Groq")

            Link(destination: URL(string: "https://github.com/OsmanDeol/portfolio-tracker")!) {
                HStack {
                    Label("Source Code (Backend)", systemImage: "chevron.left.forwardslash.chevron.right")
                        .foregroundStyle(Color.appAccent)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Color.appSubtext)
                }
            }
            .listRowBackground(Color.appSurface)

        } header: {
            Text("About").foregroundStyle(Color.appSubtext)
        }
    }

    // MARK: - Distribution section

    private var distributionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("AltStore / Sideloading", systemImage: "iphone")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.appText)

                Text("This app is distributed via AltStore for free. Your iPhone must be on the same Wi-Fi as your Mac once a week for AltStore to auto-renew the signing certificate in the background — you don't need to do anything manually.")
                    .font(.caption)
                    .foregroundStyle(Color.appSubtext)
                    .lineSpacing(3)

                Divider().background(Color.appBorder)

                Label("Tips for best experience", systemImage: "lightbulb.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.appSubtext)

                VStack(alignment: .leading, spacing: 4) {
                    tip("Keep your server Mac and iPhone on the same Wi-Fi for local access")
                    tip("For remote access install Tailscale on Mac + iPhone (free)")
                    tip("Prices auto-refresh every 30 seconds while the app is open")
                    tip("Pull down on any list to force a refresh")
                }
            }
            .padding(.vertical, 6)
            .listRowBackground(Color.appSurface)

        } header: {
            Text("Distribution").foregroundStyle(Color.appSubtext)
        }
    }

    // MARK: - Helper views

    private func settingRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundStyle(Color.appText)
            Spacer()
            Text(value).foregroundStyle(Color.appSubtext).font(.callout)
        }
        .listRowBackground(Color.appSurface)
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundStyle(Color.appAccent)
            Text(text).font(.caption).foregroundStyle(Color.appSubtext)
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
