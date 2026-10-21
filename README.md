# iOS Location Simulation Lab

iOS の位置情報シミュレーションを SwiftUI と GitHub Actions で検証する実験用リポジトリです。

## リリース

- **最新リリース:** [Location Lab v1.0.1](https://github.com/minecraftloveryesyesa-cmd/iOS-location-simulation/releases/tag/v1.0.1)
- **IPA単体をダウンロード:** [LocationLab-v1.0.1.ipa](https://github.com/minecraftloveryesyesa-cmd/iOS-location-simulation/releases/download/v1.0.1/LocationLab-v1.0.1.ipa)
- [すべてのリリースを見る](https://github.com/minecraftloveryesyesa-cmd/iOS-location-simulation/releases)

## ビルド成果物

GitHub Actions の **Build versioned IPA** を手動実行し、バージョン番号（例: `1.0.1`）を指定してください。

- IPAファイル名: `LocationLab-v1.0.1.ipa` のようにバージョン別になります。
- GitHub Actions の Artifacts は、GitHub側の仕様でダウンロード時にZIPコンテナになります。
- **ZIPに包まれていないIPA単体**が必要な場合は、workflow_dispatchの `publish_release` を有効にしてください。GitHub ReleaseのAssetsに `.ipa` ファイルそのものが添付されます。
- `v1.0.2` などのタグを push しても、そのバージョンのIPAをRelease assetとして公開するワークフローが実行されます。
- このリポジトリがPrivateの場合、Release assetの取得にはGitHubでの認証が必要です。

## 現在の実装状態

- [x] GitHub Actions上でiOSアプリをビルドする基盤
- [x] 座標入力画面
- [x] バージョン別IPAファイル名とRelease assetの出力設定
- [ ] Shiftのネイティブ `idevice` ライブラリをアプリへリンク
- [ ] 接続・セッション管理と位置情報シミュレーションAPIの統合
- [ ] 独自ビルドをLiveContainerで実機検証

**注意:** 現時点で座標入力画面は位置情報エンジンに接続されていません。Shiftの依存ライブラリをCIで取得するステップはありますが、それだけではアプリにリンクされたことにも、位置情報が変更できることにもなりません。動作確認済みとは扱いません。

## 大型アップデート：Dynamic Island

- [x] Live Activity / Dynamic Island の表示基盤
- [x] ペアリング画面から表示開始・終了
- [x] ロック画面にもペアリング状態を表示
- [ ] 実際のペアリングコード取得との連携
- [ ] iPhone実機でDynamic Island表示を検証

現在の表示は「ペアリング待機」などの状態情報のみです。アプリは現時点でペアリングコードを生成・取得していないため、コードは表示しません。Live Activityの実機表示と署名・配布形態による動作は、ビルド後に別途確認が必要です。

## テスト方針

- 自分の端末または許可されたテスト環境でのみ検証してください。
- ペアリング情報などの秘密情報をログ、スクリーンショット、リポジトリに含めないでください。
- ビルド成功、API呼び出し成功、他アプリへの位置情報反映は、それぞれ別に検証してください。

## 参考

- [N3moStudio/Shift](https://github.com/N3moStudio/Shift)
- [GitHub Actions workflow](.github/workflows/build.yml)
