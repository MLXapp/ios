# MLX.app for iPhone and iPad

The companion app for [MLX Network](https://mlx.app): see your Macs working, pause or resume them, change their limits and follow what they mine, from anywhere.

[Download](https://mlx.app/download) · [MLX Node for Mac](https://github.com/MLXapp/mac) · [Live map](https://world.mlx.app)

## What it does

- **Sign in with your MLX wallet:** with the wallet's passkey (`webcredentials:mlx.app`), or with your recovery phrase. The wallet seed stays in the Keychain on this device only, behind Face ID if you choose. The app derives the same Ed25519 key as the web wallet (`Core/Crypto.swift`, `Core/Passkey.swift`).
- **Your Macs:** live status, today's jobs and AI tokens, pass rate and mining for each Mac linked to your wallet. You can pause, resume and edit limits; commands reach the Mac on its next heartbeat.
- **Nodes:** your nodes and which Mac carries each one.
- **Notifications:** a Mac stopped or came back, plus a daily summary (APNs, opt-in).

The phone itself doesn't run AI jobs or mine. All work happens on your Macs.

Every request to mlx.app is signed by the wallet key (header `x-mlx-auth`). The API is `GET /api/companion/me`, `POST /api/companion/command` and `POST /api/companion/push`.

## Build

You need Xcode 26 or later.

```sh
brew install xcodegen
xcodegen generate
open MLXiOS.xcodeproj
```

To build on your own device, set your team in `project.yml` (`DEVELOPMENT_TEAM`) and change the bundle id. Passkeys and push notifications only work with MLX's own bundle id and team, so use the recovery phrase to sign in on a self-built app.

`-demo` as a launch argument shows sample data (used for App Store screenshots; `UITests/ScreenshotTests.swift`).

## Contributing

Issues and pull requests are welcome. Security issues: see [SECURITY.md](SECURITY.md).

## License

Apache License 2.0. See [LICENSE](LICENSE). The MLX name, logo and app icon are trademarks of MLX Network and are not licensed for use in other apps. MLX Network is independent and not affiliated with Apple.
