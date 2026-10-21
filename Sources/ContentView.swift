import SwiftUI
import MapKit
import CoreLocation
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var latitude = "35.681236"
    @State private var longitude = "139.767125"
    @State private var deviceIP = "10.7.0.1"
    @State private var pairingPath: String?
    @State private var pairingName = "未選択"
    @State private var showingImporter = false
    @State private var isWorking = false
    @State private var isActive = false
    @State private var status = "未接続"
    @State private var errorMessage: String?
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.681236, longitude: 139.767125),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    private var coordinate: CLLocationCoordinate2D? {
        guard let lat = Double(latitude), let lon = Double(longitude),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("地図から選択") {
                    MapReader { proxy in
                        Map(position: $mapPosition) {
                            if let coordinate {
                                Marker("選択した地点", coordinate: coordinate)
                                    .tint(.blue)
                            }
                        }
                        .mapStyle(.standard(elevation: .flat))
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { point in
                            guard let selected = proxy.convert(point, from: .local) else { return }
                            latitude = String(format: "%.6f", selected.latitude)
                            longitude = String(format: "%.6f", selected.longitude)
                        }
                    }
                    Text("地図をタップすると、その地点の座標が下の入力欄に反映されます。地図はドラッグ・拡大縮小できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let coordinate {
                        LabeledContent("選択地点") {
                            Text(String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude))
                                .monospacedDigit()
                                .font(.footnote)
                        }
                    }
                }

                Section("座標") {
                    TextField("緯度", text: $latitude).keyboardType(.numbersAndPunctuation)
                    TextField("経度", text: $longitude).keyboardType(.numbersAndPunctuation)
                    if coordinate == nil {
                        Text("緯度は -90〜90、経度は -180〜180 で入力してください。")
                            .foregroundStyle(.red)
                    }
                }

                Section("接続設定") {
                    TextField("トンネルIP", text: $deviceIP)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numbersAndPunctuation)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RPPairingファイル")
                            Text(pairingName).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("選択") { showingImporter = true }
                    }
                    Text("ペアリングファイルは端末内のアプリ領域にコピーします。リポジトリやログには保存しません。")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("シミュレーション") {
                    Label(status, systemImage: isActive ? "location.fill" : "location")
                    Button(isWorking ? "処理中…" : "この座標を設定", systemImage: "location.fill") {
                        Task { await setLocation() }
                    }
                    .disabled(isWorking || isActive || coordinate == nil || pairingPath == nil)
                    Button(isWorking ? "処理中…" : "シミュレーションを解除", systemImage: "location.slash") {
                        Task { await clearLocation() }
                    }
                    .disabled(isWorking || !isActive || pairingPath == nil)
                    Text("接続先端末・開発用サービス・RPPairingファイルが必要です。")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section("エラー") {
                        Text(errorMessage).foregroundStyle(.red)
                        Button("エラーを閉じる") { self.errorMessage = nil }
                    }
                }
            }
            .navigationTitle("Location Lab")
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
                importPairingFile(result)
            }
        }
    }

    private func importPairingFile(_ result: Result<[URL], Error>) {
        do {
            guard let source = try result.get().first else { return }
            let accessed = source.startAccessingSecurityScopedResource()
            defer { if accessed { source.stopAccessingSecurityScopedResource() } }
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destination = directory.appendingPathComponent("RPPairing.data")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            pairingPath = destination.path
            pairingName = source.lastPathComponent
            errorMessage = nil
        } catch {
            errorMessage = "ファイルを取り込めませんでした: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func setLocation() async {
        guard let coordinate, let pairingPath else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await LocationEngine.set(latitude: coordinate.latitude, longitude: coordinate.longitude,
                                         pairingPath: pairingPath, deviceIP: deviceIP.trimmingCharacters(in: .whitespacesAndNewlines))
            isActive = true
            status = "座標設定APIは成功"
        } catch {
            status = "設定失敗"
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func clearLocation() async {
        guard let pairingPath else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await LocationEngine.clear(pairingPath: pairingPath,
                                           deviceIP: deviceIP.trimmingCharacters(in: .whitespacesAndNewlines))
            isActive = false
            status = "解除APIは成功"
        } catch {
            status = "解除失敗"
            errorMessage = error.localizedDescription
        }
    }
}
