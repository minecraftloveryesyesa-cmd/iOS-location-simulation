import SwiftUI
import CoreLocation

struct ContentView: View {
    @State private var latitude = "35.681236"
    @State private var longitude = "139.767125"

    private var coordinate: CLLocationCoordinate2D? {
        guard let lat = Double(latitude),
              let lon = Double(longitude),
              (-90...90).contains(lat),
              (-180...180).contains(lon) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("座標") {
                    TextField("緯度", text: $latitude)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("経度", text: $longitude)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let coordinate {
                        LabeledContent("入力値") {
                            Text(String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude))
                                .monospacedDigit()
                        }
                    } else {
                        Text("緯度は -90〜90、経度は -180〜180 で入力してください。")
                            .foregroundStyle(.red)
                    }
                }

                Section("エンジン状態") {
                    Label("未接続 — 研究用 UI のみ", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("この初期版は座標を検証・表示するだけです。iOS の位置情報は変更しません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("次の検証") {
                    Label("Shift の接続・セッション管理を分離", systemImage: "1.circle")
                    Label("FFI ライブラリのリンク条件を確認", systemImage: "2.circle")
                    Label("実機で開始・解除・他アプリへの反映を検証", systemImage: "3.circle")
                }
            }
            .navigationTitle("Location Lab")
        }
    }
}
