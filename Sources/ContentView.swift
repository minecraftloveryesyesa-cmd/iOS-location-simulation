import SwiftUI
import MapKit
import CoreLocation
import UniformTypeIdentifiers

private enum Neon {
    static let bg = Color(red: 0.018, green: 0.035, blue: 0.065)
    static let panel = Color(red: 0.045, green: 0.075, blue: 0.12)
    static let cyan = Color(red: 0.30, green: 0.90, blue: 1.0)
    static let blue = Color(red: 0.18, green: 0.48, blue: 1.0)
    static let muted = Color(red: 0.62, green: 0.76, blue: 0.86)
    static let gradient = LinearGradient(colors: [cyan, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
}

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
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 35.681236, longitude: 139.767125),
                           span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))
    )

    private var coordinate: CLLocationCoordinate2D? {
        guard let lat = Double(latitude), let lon = Double(longitude),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Neon.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 17) {
                        header
                        mapCard
                        actionCard // 設定・解除ボタンはマップ直下
                        coordinatesCard
                        connectionCard
                        if let errorMessage { errorCard(errorMessage) }
                        Text("LOCATION LAB  •  DEVELOPMENT INTERFACE")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .tracking(1.4).foregroundStyle(Neon.muted.opacity(0.65))
                            .frame(maxWidth: .infinity).padding(.top, 4)
                    }
                    .padding(.horizontal, 15).padding(.top, 12).padding(.bottom, 28)
                }
            }
            .preferredColorScheme(.dark)
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) {
                importPairingFile($0)
            }
        }
        .tint(Neon.cyan)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 27, weight: .semibold)).foregroundStyle(Neon.bg)
                .frame(width: 49, height: 49).background(Neon.gradient, in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 3) {
                Text("LOCATION LAB").font(.system(size: 22, weight: .black, design: .rounded))
                    .tracking(1.2).foregroundStyle(.white)
                Text("LOCATION SIMULATION").font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2).foregroundStyle(Neon.cyan)
            }
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                Circle().fill(isActive ? Neon.cyan : Neon.muted.opacity(0.5)).frame(width: 7, height: 7)
                Text(isActive ? "ACTIVE" : "STANDBY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(isActive ? Neon.cyan : Neon.muted)
            }.padding(.horizontal, 9).padding(.vertical, 8)
                .background(Neon.panel, in: Capsule())
                .overlay(Capsule().stroke(Neon.cyan.opacity(0.25), lineWidth: 1))
        }
    }

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("01", "MAP SELECTOR", "地図をタップして地点を選択")
            MapReader { proxy in
                Map(position: $mapPosition) {
                    if let coordinate {
                        Annotation("TARGET", coordinate: coordinate, anchor: .bottom) {
                            VStack(spacing: 3) {
                                Image(systemName: "scope").font(.system(size: 25, weight: .bold))
                                    .foregroundStyle(Neon.cyan).shadow(color: Neon.cyan.opacity(0.9), radius: 8)
                                Text("TARGET").font(.system(size: 8, weight: .black, design: .monospaced))
                                    .tracking(1).foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Color.black.opacity(0.85), in: Capsule())
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat, emphasis: .muted))
                .frame(height: 285).clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Neon.cyan.opacity(0.45), lineWidth: 1))
                .onTapGesture { point in
                    guard let selected = proxy.convert(point, from: .local) else { return }
                    latitude = String(format: "%.6f", selected.latitude)
                    longitude = String(format: "%.6f", selected.longitude)
                }
            }
            HStack {
                Label("MAP TAP TO SET TARGET", systemImage: "scope")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.5).foregroundStyle(Neon.muted)
                Spacer()
                Text("WGS84").font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Neon.cyan).padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Neon.cyan.opacity(0.1), in: Capsule())
            }
        }.cardStyle()
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "location.circle.fill")
                    .font(.title3).foregroundStyle(Neon.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isActive ? "SIMULATION ACTIVE" : "TARGET COORDINATES")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(0.5).foregroundStyle(.white)
                    Text(status).font(.caption).foregroundStyle(Neon.muted)
                }
                Spacer()
                if isWorking { ProgressView().tint(Neon.cyan) }
            }
            HStack(spacing: 8) {
                coordinateValue("LATITUDE", coordinate.map { String(format: "%.6f", $0.latitude) } ?? "INVALID")
                coordinateValue("LONGITUDE", coordinate.map { String(format: "%.6f", $0.longitude) } ?? "INVALID")
            }
            Button { Task { await setLocation() } } label: {
                HStack {
                    Image(systemName: "location.fill")
                    Text(isWorking ? "処理中…" : "位置情報を設定")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 15, weight: .bold)).foregroundStyle(Neon.bg)
                .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 53)
                .background(Neon.gradient, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: Neon.blue.opacity(0.25), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isWorking || isActive || coordinate == nil || pairingPath == nil)
            .opacity(isWorking || isActive || coordinate == nil || pairingPath == nil ? 0.45 : 1)

            Button { Task { await clearLocation() } } label: {
                HStack {
                    Image(systemName: "location.slash")
                    Text(isWorking ? "処理中…" : "シミュレーションを解除")
                    Spacer()
                    Image(systemName: "xmark")
                }
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(isActive ? Neon.cyan : Neon.muted)
                .padding(.horizontal, 15).frame(maxWidth: .infinity, minHeight: 45)
                .background(Neon.cyan.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Neon.cyan.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain).disabled(isWorking || !isActive || pairingPath == nil)
            .opacity(isWorking || !isActive || pairingPath == nil ? 0.45 : 1)
        }
        .padding(15)
        .background(LinearGradient(colors: [Neon.panel, Neon.bg], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(Neon.cyan.opacity(0.3), lineWidth: 1))
    }

    private var coordinatesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("02", "MANUAL COORDINATES", "数値を直接編集することもできます")
            coordinateField("LATITUDE / 緯度", value: $latitude)
            coordinateField("LONGITUDE / 経度", value: $longitude)
            if coordinate == nil {
                Label("緯度は -90〜90、経度は -180〜180 で入力してください。",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(.orange)
            }
        }.cardStyle()
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            heading("03", "CONNECTION", "開発用サービスへの接続設定")
            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("TUNNEL IP")
                TextField("10.7.0.1", text: $deviceIP)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .font(.system(size: 14, design: .monospaced)).foregroundStyle(.white)
                    .padding(13).background(Neon.bg, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Neon.cyan.opacity(0.2), lineWidth: 1))
            }
            HStack(spacing: 10) {
                Image(systemName: "doc.badge.gearshape").font(.title2).foregroundStyle(Neon.cyan)
                    .frame(width: 40, height: 40).background(Neon.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 4) {
                    Text("RPPairing FILE").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                    Text(pairingName).font(.caption).foregroundStyle(Neon.muted).lineLimit(1)
                }
                Spacer()
                Button("選択") { showingImporter = true }
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Neon.cyan)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Neon.cyan.opacity(0.1), in: Capsule())
                    .overlay(Capsule().stroke(Neon.cyan.opacity(0.35), lineWidth: 1))
            }
            Text("ペアリングファイルは端末内のアプリ領域にコピーします。リポジトリやログには保存しません。")
                .font(.footnote).foregroundStyle(Neon.muted)
        }.cardStyle()
    }

    private func heading(_ number: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number).font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Neon.bg).frame(width: 28, height: 28)
                .background(Neon.gradient, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(0.8).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(Neon.muted)
            }
            Spacer(minLength: 0)
        }
    }

    private func coordinateValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.7).foregroundStyle(Neon.muted)
            Text(value).font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(coordinate == nil ? .orange : Neon.cyan).lineLimit(1).minimumScaleFactor(0.75)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(11)
            .background(Neon.bg, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Neon.cyan.opacity(0.14), lineWidth: 1))
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1).foregroundStyle(Neon.muted)
    }

    private func coordinateField(_ title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            fieldLabel(title)
            TextField(title, text: value).keyboardType(.numbersAndPunctuation)
                .font(.system(size: 14, design: .monospaced)).foregroundStyle(.white)
                .padding(13).background(Neon.bg, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Neon.cyan.opacity(0.2), lineWidth: 1))
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("ERROR", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.red)
            Text(message).font(.footnote).foregroundStyle(.white)
            Button("エラーを閉じる") { errorMessage = nil }.foregroundStyle(Neon.cyan)
        }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.3), lineWidth: 1))
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

private extension View {
    func cardStyle() -> some View {
        padding(14)
            .background(Neon.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 21))
            .overlay(RoundedRectangle(cornerRadius: 21).stroke(Neon.cyan.opacity(0.18), lineWidth: 1))
    }
}
