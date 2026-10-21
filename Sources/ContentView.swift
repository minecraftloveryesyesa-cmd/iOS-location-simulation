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
    @State private var searchQuery = ""
    @State private var showManualCoordinates = false
    @State private var showConnectionSettings = false
    @State private var selectedPage = "menu"
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
                Group {
                    if selectedPage == "menu" {
                        menuScreen
                    } else if selectedPage == "pairing" {
                        pairingScreen
                    } else {
                        locationScreen
                    }
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

    private var menuScreen: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("ツール")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 12)

                VStack(spacing: 14) {
                    menuRow(icon: "iphone.gen3.radiowaves.left.and.right", title: "ペアリング",
                            subtitle: pairingPath == nil ? "iPhoneとの接続設定" : "ペアリングファイル設定済み",
                            badge: nil) {
                        selectedPage = "pairing"
                    }
                    menuRow(icon: "mappin.and.ellipse", title: "位置情報の偽装",
                            subtitle: isActive ? "偽装しています" : "地図から場所を選択",
                            badge: nil) {
                        selectedPage = "location"
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var locationScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                mapCard
                actionCard
                coordinatesCard
                if let errorMessage { errorCard(errorMessage) }
                Text("LOCATION LAB  •  DEVELOPMENT INTERFACE")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.4).foregroundStyle(Neon.muted.opacity(0.65))
                    .frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 14)
        }
    }

    private var pairingScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button { selectedPage = "menu" } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.10), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                    }
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("ペアリング")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("iPhoneとの接続に使うペアリング情報を設定します")
                        .font(.subheadline).foregroundStyle(Neon.muted)
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 27)).foregroundStyle(Neon.cyan)
                            .frame(width: 50, height: 50)
                            .background(Neon.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ペアリングファイル")
                                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            Text(pairingPath == nil ? "未設定" : pairingName)
                                .font(.caption).foregroundStyle(Neon.muted).lineLimit(2)
                        }
                        Spacer()
                    }
                    Button { showingImporter = true } label: {
                        Label(pairingPath == nil ? "ファイルを選択" : "ファイルを変更", systemImage: "folder")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Neon.bg)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Neon.gradient, in: RoundedRectangle(cornerRadius: 15))
                    }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 7) {
                        fieldLabel("TUNNEL IP")
                        TextField("10.7.0.1", text: $deviceIP)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .keyboardType(.numbersAndPunctuation)
                            .font(.system(size: 14, design: .monospaced)).foregroundStyle(.white)
                            .padding(13).background(Neon.bg, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Neon.cyan.opacity(0.2), lineWidth: 1))
                    }
                    Text("この画面で選んだペアリングファイルはアプリ内にコピーされます。")
                        .font(.footnote).foregroundStyle(Neon.muted)
                }
                .padding(16)
                .background(Neon.panel, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Neon.cyan.opacity(0.22), lineWidth: 1))
                if let errorMessage { errorCard(errorMessage) }
            }
            .padding(16)
        }
    }

    private func menuRow(icon: String, title: String, subtitle: String, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 17) {
                Image(systemName: icon)
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 66)
                    .background(Neon.bg, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Neon.blue.opacity(0.45), lineWidth: 1))
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                        if let badge {
                            Text(badge).font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Neon.cyan).padding(.horizontal, 9).padding(.vertical, 5)
                                .background(Neon.blue.opacity(0.18), in: Capsule())
                        }
                    }
                    Text(subtitle).font(.caption).foregroundStyle(Neon.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white.opacity(0.42))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .background(Neon.panel.opacity(0.45), in: RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.27), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(spacing: 7) {
            HStack {
                Button { selectedPage = "menu" } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.12), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 1))
                })
                Spacer()
                Button { selectedPage = "pairing" } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.12), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 1))
                }
                .accessibilityLabel("接続設定")
            }
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Neon.bg)
                        .frame(width: 64, height: 64)
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Neon.blue.opacity(0.65), lineWidth: 1))
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white)
                }
                Text("位置情報の偽装")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 9) {
                    Image(systemName: isActive ? "location.fill" : "location.slash.fill")
                        .foregroundStyle(isActive ? Neon.cyan : Color.orange)
                    Text(isActive ? "偽装しています" : "偽装していません")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isActive ? Neon.cyan : Color.orange)
                }
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Color(red: 0.12, green: 0.15, blue: 0.21), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
            }
            .padding(.top, 0).padding(.bottom, 0)
        }
    }

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 24, weight: .medium)).foregroundStyle(Neon.blue)
                Text("場所を選択")
                    .font(.system(size: 23, weight: .bold)).foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                TextField("場所を検索", text: $searchQuery)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                    .background(Color(red: 0.10, green: 0.12, blue: 0.17), in: RoundedRectangle(cornerRadius: 20))
                    .submitLabel(.search)
                    .onSubmit { Task { await searchPlace() } }
                Button { Task { await searchPlace() } } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Color(red: 0.13, green: 0.16, blue: 0.22), in: RoundedRectangle(cornerRadius: 22))
                }
                .accessibilityLabel("場所を検索")
            }

            MapReader { proxy in
                Map(position: $mapPosition) {
                    if let coordinate {
                        Annotation("選択地点", coordinate: coordinate, anchor: .bottom) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 42, weight: .medium))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Neon.blue)
                                .shadow(color: Neon.blue.opacity(0.45), radius: 8)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .onTapGesture { point in
                    guard let selected = proxy.convert(point, from: .local) else { return }
                    latitude = String(format: "%.6f", selected.latitude)
                    longitude = String(format: "%.6f", selected.longitude)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "scope").foregroundStyle(Neon.muted)
                Text(coordinate.map { String(format: "%.5f,  %.5f", $0.latitude, $0.longitude) } ?? "座標を選択してください")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Neon.muted)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
        }
        .padding(11)
        .background(Neon.panel.opacity(0.62), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.30), lineWidth: 1))
    }

    @MainActor
    private func searchPlace() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                errorMessage = "場所が見つかりませんでした。別の検索語を試してください。"
                return
            }
            let target = item.placemark.coordinate
            latitude = String(format: "%.6f", target.latitude)
            longitude = String(format: "%.6f", target.longitude)
            mapPosition = .region(MKCoordinateRegion(
                center: target,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            ))
            errorMessage = nil
        } catch {
            errorMessage = "場所を検索できませんでした: \\(error.localizedDescription)"
        }
    }

    private var actionCard: some View {
        VStack(spacing: 8) {
            Button { Task { await setLocation() } } label: {
                HStack(spacing: 10) {
                    if isWorking { ProgressView().tint(.white) }
                    else { Image(systemName: "location.fill") }
                    Text(isWorking ? "設定中" : "位置情報を設定")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Neon.gradient, in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: Neon.blue.opacity(0.32), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isWorking || isActive || coordinate == nil || pairingPath == nil)
            .opacity(isWorking || isActive || coordinate == nil || pairingPath == nil ? 0.5 : 1)

            if isActive {
                Button { Task { await clearLocation() } } label: {
                    Label("シミュレーションを解除", systemImage: "location.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Neon.cyan)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Neon.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Neon.cyan.opacity(0.25), lineWidth: 1))
                }
                .disabled(isWorking || pairingPath == nil)
            }
            if !isActive {
                Text(pairingPath == nil ? "接続設定からRPPairingファイルを選択してください" : status)
                    .font(.caption).foregroundStyle(Neon.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var coordinatesCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { showManualCoordinates.toggle() } } label: {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3").foregroundStyle(Neon.cyan)
                    Text("座標を手入力").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    Image(systemName: showManualCoordinates ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Neon.muted)
                }
            }.buttonStyle(.plain)
            if showManualCoordinates {
                coordinateField("LATITUDE / 緯度", value: $latitude)
                coordinateField("LONGITUDE / 経度", value: $longitude)
                if coordinate == nil {
                    Label("緯度は -90〜90、経度は -180〜180 で入力してください。",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.orange)
                }
            }
        }.padding(12)
            .background(Neon.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Neon.cyan.opacity(0.18), lineWidth: 1))
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { showConnectionSettings.toggle() } } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape").foregroundStyle(Neon.cyan)
                    Text("接続設定").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    Text(pairingPath == nil ? "未設定" : "設定済み")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(Neon.muted)
                    Image(systemName: showConnectionSettings ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Neon.muted)
                }
            }.buttonStyle(.plain)
            if showConnectionSettings {
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
            }
        }.padding(12)
            .background(Neon.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Neon.cyan.opacity(0.18), lineWidth: 1))
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
