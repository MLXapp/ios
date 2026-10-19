import SwiftUI

struct NodesView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        List {
            if let me = store.me {
                if me.nodes.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No nodes yet").font(.headline)
                            Text("Your Macs mine at the free rate, up to 1 MLX a day each wallet. A node matched to a Mac's chip multiplies that: 20× for Core, 80× for Pro, 320× for Ultra.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
                ForEach(me.nodes) { n in
                    HStack(spacing: 14) {
                        Text("#\(n.id)")
                            .font(.callout.weight(.bold).monospacedDigit())
                            .frame(width: 58, height: 44)
                            .background(Brand.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(Brand.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(n.name).font(.body.weight(.semibold))
                            if let u = n.unlockAt {
                                Text("Unlocks \(Date(timeIntervalSince1970: u / 1000).formatted(date: .abbreviated, time: .omitted))")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Amount.mlx(n.reward, max: 0)).font(.callout.weight(.semibold).monospacedDigit())
                            Text("MLX, locked").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Nodes")
        .refreshable { await store.refresh() }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @State private var confirmSignOut = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Emblem(size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.me?.account ?? "–").font(.headline)
                        Text("Signed in with your MLX wallet").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                Toggle("Notifications", isOn: Binding(get: { store.pushOn }, set: { on in Task { await store.setPush(on) } }))
                Toggle("Lock with Face ID", isOn: $store.lockWithFaceID)
            } footer: {
                Text(store.pushError ?? "Tells you when a Mac stops or comes back, and what your Macs mined each day.")
                    .foregroundStyle(store.pushError == nil ? Color.secondary : Color.red)
            }
            Section {
                Link(destination: URL(string: "mailto:support@mlx.app")!) { Label("Help and support", systemImage: "questionmark.circle") }
                Link(destination: URL(string: "https://mlx.app/privacy")!) { Label("Privacy", systemImage: "hand.raised") }
                Link(destination: URL(string: "https://mlx.app/terms")!) { Label("Terms", systemImage: "doc.text") }
                Link(destination: URL(string: "https://mlx.app")!) { Label("mlx.app", systemImage: "globe") }
            } footer: {
                Text("MLX.app \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · MLX Network is not affiliated with Apple Inc.")
            }
            Section {
                Button("Sign out", role: .destructive) { confirmSignOut = true }
            } footer: {
                Text("Signing out removes your wallet key from this iPhone. Your wallet and Macs aren't affected.")
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Sign out of MLX.app?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await store.signOut() } }
        }
    }
}
