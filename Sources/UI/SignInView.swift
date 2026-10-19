import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var store: Store
    @State private var phraseOpen = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            Brand.warm.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 40)
                Emblem(size: 84)
                    .shadow(color: Brand.orange.opacity(0.35), radius: 24, y: 10)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
                Text("Your Macs,\nin your pocket.")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)
                Text("See every Mac that works for your MLX wallet, what it mined today, and pause or resume it from anywhere.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 8)
                Spacer(minLength: 32)
                VStack(spacing: 12) {
                    Button {
                        Task { await store.signInWithPasskey() }
                    } label: {
                        HStack(spacing: 10) {
                            if store.loading { ProgressView().tint(.white) } else { Image(systemName: "person.badge.key.fill") }
                            Text("Sign in with passkey").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.ink)
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(Capsule())
                    .disabled(store.loading)
                    .accessibilityIdentifier("passkey")

                    Button("Use recovery phrase") { phraseOpen = true }
                        .font(.callout.weight(.semibold))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("phrase")

                    if let e = store.error {
                        Text(e).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                Text("Uses the passkey of your MLX wallet. No wallet yet? Create one at mlx.app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 520)
        }
        .animation(.smooth(duration: 0.3), value: store.error)
        .sheet(isPresented: $phraseOpen) { PhraseSheet() }
        .onAppear { withAnimation(.spring(duration: 0.7, bounce: 0.3)) { appeared = true } }
    }
}

struct PhraseSheet: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var phrase = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $phrase)
                        .frame(minHeight: 150)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .accessibilityIdentifier("phraseField")
                } header: {
                    Text("Your 24 words")
                } footer: {
                    Text("The recovery phrase of your MLX wallet, in order. It stays on this iPhone: MLX.app only uses it to sign requests for your Macs.")
                }
                if let e = store.error {
                    Section { Text(e).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Recovery phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { if await store.signIn(phrase: phrase) { dismiss() } }
                    } label: {
                        if store.loading { ProgressView() } else { Text("Sign in").fontWeight(.semibold) }
                    }
                    .disabled(store.loading || phrase.split(whereSeparator: { $0.isWhitespace }).count < 24)
                }
            }
            .onAppear { focused = true }
        }
    }
}

struct LockView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 18) {
                Emblem(size: 64)
                Text("MLX is locked").font(.title3.weight(.semibold))
                Button {
                    Task { await store.unlock() }
                } label: {
                    Label("Unlock", systemImage: "faceid").frame(minWidth: 160, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.ink)
                .foregroundStyle(Color(.systemBackground))
                .clipShape(Capsule())
            }
        }
        .task { await store.unlock() }
    }
}
