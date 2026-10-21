# iOS Location Simulation Lab

iOS の位置情報シミュレーションを、SwiftUI と GitHub Actions で検証するための実験用リポジトリです。

## 現在の状態

- [x] GitHub Actions で iOS アプリをビルドする土台
- [x] 座標入力 UI の試作
- [ ] Shift の接続・セッション管理を切り出す
- [ ] `idevice` FFI のバイナリ・アーキテクチャ・ライセンスを確認する
- [ ] 独自ビルドを LiveContainer で実機検証する

**重要:** 現在の初期版は UI とビルド経路の検証用です。座標入力欄があっても、OS の位置情報を変更するエンジンはまだ接続されていません。動作済みとは扱いません。

## 背景

[ N3moStudio/Shift ](https://github.com/N3moStudio/Shift) の実装を調査対象にします。Shift のソースでは、位置情報シミュレーション用の API と、接続・セッション管理を組み合わせています。Shift が LiveContainer 内で動き、他アプリにも反映されたという実機報告はありますが、独自アプリへの移植が成功することを保証するものではありません。

## ビルド

GitHub Actions の **Build unsigned IPA** を手動実行するか、main ブランチに push してください。成功すると unsigned IPA がアーティファクトとして保存されます。

- Mac は不要です。ビルドは GitHub-hosted macOS runner で行います。
- 署名なし IPA が LiveContainer で動作するかは、実機と構成に依存します。
- この workflow の成功は、位置情報シミュレーション機能の動作確認を意味しません。

## 安全な検証方針

- 自分の端末・許可されたテスト環境でのみ検証してください。
- ペアリング情報や秘密情報をログ、スクリーンショット、リポジトリに含めないでください。
- アプリやサービスの利用規約に反する用途には使用しないでください。
- 実測結果とソースからの推定を分けて記録してください。

詳しくは [docs/TESTING.md](docs/TESTING.md) と [docs/STATUS.md](docs/STATUS.md) を参照してください。
