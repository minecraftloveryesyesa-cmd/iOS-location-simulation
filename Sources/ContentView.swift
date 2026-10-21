import SwiftUI
import MapKit
import CoreLocation
import UniformTypeIdentifiers
import ActivityKit
import UIKit

private enum Neon {
    static let bg = Color(red: 0.025, green: 0.035, blue: 0.050)
    static let panel = Color(red: 0.055, green: 0.070, blue: 0.090)
    static let cyan = Color(red: 0.32, green: 0.68, blue: 0.98)
    static let blue = Color(red: 0.15, green: 0.43, blue: 0.96)
    static let muted = Color(red: 0.59, green: 0.66, blue: 0.72)
    static let gradient = LinearGradient(colors: [Color(red: 0.13, green: 0.43, blue: 0.98), Color(red: 0.25, green: 0.68, blue: 1.00)], startPoint: .leading, endPoint: .trailing)
}

struct ContentView: View {
    @State private var latitude = "35.681236"
    @State private var longitude = "139.767125"
    @State private var deviceIP = "10.7.0.1"
    @State private var pairingPath: String?
    @State private var pairingName = "未選択"
    @StateObject private var pairingStore = PairingStore()
    @StateObject private var pairHost = PairOnDeviceService()
    @StateObject private var consoleLog = ConsoleLogStore.shared
    @State private var consoleSearch = ""
    @State private var consoleLevelFilter = "すべて"
    @State private var showingImporter = false
    @State private var isPairingActivityVisible = false
    @State private var isWorking = false
    @State private var isActive = false
    @State private var status = "未接続"
    @State private var errorMessage: String?
    @State private var searchQuery = ""
    @State private var showManualCoordinates = false
    @State private var showConnectionSettings = false
    @State private var showingPairingDeleteConfirmation = false
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
                        menuScreen.transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else if selectedPage == "pairing" {
                        pairingScreen.transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        locationScreen.transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: selectedPage)
                // iOS-style edge swipe: start near the left edge and drag right to go back.
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18, coordinateSpace: .local)
                        .onEnded { value in
                            guard value.startLocation.x < 34,
                                  value.translation.width > 90,
                                  abs(value.translation.height) < 90,
                                  selectedPage != "menu" else { return }
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                selectedPage = "menu"
                            }
                        }
                )
            }
            .preferredColorScheme(.dark)
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: PairingStore.supportedTypes, allowsMultipleSelection: false) {
                importPairingFile($0)
            }
        }
        .tint(Neon.cyan)
        .onAppear {
            if pairingStore.hasPairingFile {
                pairingPath = pairingStore.pairingPath
                pairingName = PairingStore.fileName
            }
        }
        .onChange(of: pairHost.phase) { _, phase in
            switch phase {
            case .advertising:
                consoleLog.log("ペアリング待機を開始")
                PairingActivityManager.update(status: "ペアリング待機", detail: "iOSの設定からペアリングを開始")
            case .deviceConnected:
                consoleLog.log("ペアリング相手が接続")
                PairingActivityManager.update(status: "接続済み", detail: "コードを生成しています")
            case .awaitingPIN(let pin):
                consoleLog.log("ペアリングコードを生成（値は安全のため記録しません）")
                PairingActivityManager.update(status: "コード入力", detail: pin)
            case .succeeded:
                consoleLog.log("ペアリング成功")
                pairingStore.refresh()
                pairingPath = pairingStore.pairingPath
                pairingName = PairingStore.fileName
                PairingActivityManager.update(status: "ペアリング完了", detail: "情報を保存しました")
            case .failed(let message):
                consoleLog.log("ペアリング失敗: \(message)", level: .error)
                PairingActivityManager.update(status: "ペアリング失敗", detail: String(message.prefix(80)))
            case .idle:
                break
            }
        }
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

                consoleCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var consoleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Neon.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text("コンソール")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(consoleLog.entries.count) 件のログ")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Neon.muted)
                }
                Spacer()
                Button {
                    let text = visibleConsoleEntries.map(\.formatted).joined(separator: "\n")
                    guard !text.isEmpty else { return }
                    UIPasteboard.general.string = text
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Neon.cyan)
                        .frame(width: 38, height: 38)
                        .background(Neon.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(SoftPressButtonStyle())
                .accessibilityLabel("表示中のログをコピー")
                .disabled(visibleConsoleEntries.isEmpty)

                Button {
                    consoleLog.clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 38, height: 38)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(SoftPressButtonStyle())
                .accessibilityLabel("ログを消去")
                .disabled(consoleLog.entries.isEmpty)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Neon.muted)
                TextField("ログを検索", text: $consoleSearch)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !consoleSearch.isEmpty {
                    Button {
                        consoleSearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Neon.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("検索をクリア")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Neon.bg.opacity(0.9), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.07), lineWidth: 1))

            Picker("ログレベル", selection: $consoleLevelFilter) {
                Text("すべて").tag("すべて")
                Text("情報").tag("INFO")
                Text("警告").tag("WARN")
                Text("エラー").tag("ERROR")
            }
            .pickerStyle(.segmented)
            .tint(Neon.cyan)

            if visibleConsoleEntries.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 22))
                        .foregroundStyle(Neon.muted)
                    Text(consoleLog.entries.isEmpty ? "ログはまだありません" : "一致するログがありません")
                        .font(.caption)
                        .foregroundStyle(Neon.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleConsoleEntries.suffix(40)) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(consoleLevelColor(entry.level))
                                .frame(width: 3)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                        .foregroundStyle(Neon.muted)
                                    Text(entry.level.rawValue)
                                        .foregroundStyle(consoleLevelColor(entry.level))
                                        .fontWeight(.bold)
                                }
                                .font(.system(size: 10, design: .monospaced))
                                Text(entry.message)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 9)
                        .padding(.horizontal, 10)
                        .background(Neon.bg.opacity(0.68), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom, 6)
                    }
                }
                if visibleConsoleEntries.count > 40 {
                    Text("最新40件を表示中。コピーではフィルターに一致する全件をコピーします。")
                        .font(.caption2)
                        .foregroundStyle(Neon.muted)
                }
            }

            Text("Location Lab 内部のイベントログです。iOS 全体や他アプリのシステムログは取得しません。PIN・ペアリング内容はログに記録しません。")
                .font(.caption2)
                .foregroundStyle(Neon.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .modifier(LiquidGlassSurface(cornerRadius: 22))
    }

    private var visibleConsoleEntries: [ConsoleLogEntry] {
        consoleLog.entries.filter { entry in
            let matchesLevel = consoleLevelFilter == "すべて" || entry.level.rawValue == consoleLevelFilter
            let query = consoleSearch.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty ||
                entry.message.localizedCaseInsensitiveContains(query) ||
                entry.level.rawValue.localizedCaseInsensitiveContains(query)
            return matchesLevel && matchesSearch
        }
    }

    private func consoleLevelColor(_ level: ConsoleLogLevel) -> Color {
        switch level {
        case .info: return Neon.cyan
        case .warning: return .orange
        case .error: return Color(red: 1, green: 0.35, blue: 0.38)
        }
    }

    private var locationScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                mapCard
                actionCard
                coordinatesCard
                connectionDiagnosticsCard
                recoveryCard
                if let errorMessage { errorCard(errorMessage) }
                Text("LOCATION LAB  •  DEVELOPMENT INTERFACE")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.4).foregroundStyle(Neon.muted.opacity(0.65))
                    .frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 14)
        }
        .confirmationDialog("ペアリング情報を削除しますか？", isPresented: $showingPairingDeleteConfirmation, titleVisibility: .visible) {
            Button("ペアリング情報を削除", role: .destructive) { deletePairingFile() }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("アプリ内に保存したペアリングファイルを削除します。削除後は再インポートが必要です。")
        }
    }

    private var pairingScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            selectedPage = "menu"
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Neon.muted)
                            .frame(width: 42, height: 42)
                            .modifier(LiquidGlassSurface(cornerRadius: 14))
                    }
                    .buttonStyle(SoftPressButtonStyle())
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
                    Label("このiPhoneとペアリング", systemImage: "iphone.gen3.radiowaves.left.and.right")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(Neon.cyan)
                    Text("開始後、設定 → プライバシーとセキュリティ → デベロッパモードからペアリングを行います。")
                        .font(.footnote).foregroundStyle(Neon.muted)
                    VStack(spacing: 12) {
                        switch pairHost.phase {
                        case .idle:
                            Label("開始待ち", systemImage: "circle.dashed").foregroundStyle(Neon.muted)
                        case .advertising:
                            ProgressView().tint(Neon.cyan)
                            Text("設定アプリからの接続を待っています").font(.subheadline).foregroundStyle(.white)
                            Text("このアプリを終了せずに設定へ移動してください。").font(.caption).foregroundStyle(Neon.muted)
                        case .deviceConnected:
                            ProgressView().tint(Neon.cyan)
                            Text("接続しました。コードを準備しています").font(.subheadline).foregroundStyle(.white)
                        case .awaitingPIN(let pin):
                            Text("設定画面に入力するコード").font(.caption).foregroundStyle(Neon.muted)
                            Text(pin).font(.system(size: 38, weight: .bold, design: .rounded))
                                .tracking(7).monospacedDigit().foregroundStyle(Neon.cyan).textSelection(.enabled)
                        case .succeeded:
                            Label("ペアリング完了", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(Neon.cyan)
                            Text("ペアリング情報をアプリ内に保存しました。").font(.caption).foregroundStyle(Neon.muted)
                        case .failed(let message):
                            Label("ペアリングに失敗しました", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text(message).font(.caption).foregroundStyle(Neon.muted)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(15)
                    .background(Neon.bg.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                    HStack(spacing: 10) {
                        Button {
                            pairHost.acknowledgeFailure()
                            pairHost.start(pairingStore: pairingStore)
                            do {
                                try PairingActivityManager.start(status: "ペアリング待機", detail: "iOSの設定からペアリングを開始")
                                isPairingActivityVisible = true
                            } catch {
                                errorMessage = "Live Activityを開始できませんでした: \(error.localizedDescription)"
                            }
                        } label: {
                            Label("ペアリング開始", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Neon.bg).frame(maxWidth: .infinity, minHeight: 46)
                                .background(Neon.gradient, in: RoundedRectangle(cornerRadius: 13))
                                .shadow(color: Neon.blue.opacity(0.20), radius: 10, y: 3)
                        }
                        .buttonStyle(SoftPressButtonStyle())
                        .disabled(pairHost.isBusy || pairHost.phase == .succeeded)
                        Button {
                            pairHost.resetToIdle()
                            PairingActivityManager.end()
                            isPairingActivityVisible = false
                        } label: {
                            Label("停止", systemImage: "stop.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white).frame(minWidth: 76, minHeight: 46)
                                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(.plain)
                        .disabled(!pairHost.isBusy && pairHost.phase != .succeeded)
                    }
                    Label("Dynamic Islandには実際の状態と取得したコードを表示します。", systemImage: "livephoto")
                        .font(.system(size: 11)).foregroundStyle(Neon.muted.opacity(0.85))
                }
                .padding(15)
                .modifier(LiquidGlassSurface(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 27)).foregroundStyle(Neon.cyan)
                            .frame(width: 50, height: 50)
                            .background(Neon.cyan.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
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
                            .shadow(color: Neon.blue.opacity(0.18), radius: 10, y: 3)
                    }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 7) {
                        fieldLabel("TUNNEL IP")
                        TextField("10.7.0.1", text: $deviceIP)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .keyboardType(.numbersAndPunctuation)
                            .font(.system(size: 14, design: .monospaced)).foregroundStyle(.white)
                            .padding(13).background(Neon.bg, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.075), lineWidth: 1))
                    }
                    Text("この画面で選んだペアリングファイルはアプリ内にコピーされます。")
                        .font(.footnote).foregroundStyle(Neon.muted)
                }
                .padding(16)
                .modifier(LiquidGlassSurface(cornerRadius: 22))
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
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .modifier(LiquidGlassSurface(cornerRadius: 22))
        }
        .frame(maxWidth: .infinity, minHeight: 116)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .buttonStyle(SoftPressButtonStyle())
    }

    private var header: some View {
        VStack(spacing: 7) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selectedPage = "menu"
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Neon.muted)
                        .frame(width: 42, height: 42)
                        .modifier(LiquidGlassSurface(cornerRadius: 14))
                }
                .buttonStyle(SoftPressButtonStyle())
                Spacer()

            }
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Neon.bg)
                        .frame(width: 64, height: 64)
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
                    .font(.system(size: 21, weight: .medium)).foregroundStyle(Neon.cyan)
                Text("場所を選択")
                    .font(.system(size: 23, weight: .bold)).foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                TextField("場所を検索", text: $searchQuery)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.09), lineWidth: 1))
                    .submitLabel(.search)
                    .onSubmit { Task { await searchPlace() } }
                Button { Task { await searchPlace() } } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(SoftPressButtonStyle())
                .accessibilityLabel("場所を検索")
            }

            MapReader { proxy in
                Map(position: $mapPosition) {
                    if let coordinate {
                        Annotation("選択地点", coordinate: coordinate, anchor: .bottom) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 42, weight: .medium))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color(red: 0.18, green: 0.31, blue: 0.40))
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
        .modifier(LiquidGlassSurface(cornerRadius: 22))
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
            consoleLog.log("場所検索成功: \(query)")
        } catch {
            consoleLog.log("場所検索失敗: \(error.localizedDescription)", level: .warning)
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
                .background(Neon.gradient, in: RoundedRectangle(cornerRadius: 17))
                .shadow(color: Neon.blue.opacity(0.22), radius: 14, y: 5)
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.07), lineWidth: 1))
                .scaleEffect(isWorking ? 0.985 : 1)
                .animation(.spring(response: 0.32, dampingFraction: 0.68), value: isWorking)
            }
            .buttonStyle(SoftPressButtonStyle())
            .disabled(isWorking || isActive || coordinate == nil || pairingPath == nil)
            .opacity(isWorking || isActive || coordinate == nil || pairingPath == nil ? 0.5 : 1)

            if isActive {
                Button { Task { await clearLocation() } } label: {
                    Label("シミュレーションを解除", systemImage: "location.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Neon.cyan)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Neon.cyan.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.09), lineWidth: 1))
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

    private var connectionDiagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg").foregroundStyle(Neon.cyan)
                Text("接続診断").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                Spacer()
                Text("LOCAL CHECK").font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Neon.muted)
            }
            diagnosticRow("ペアリングファイル", value: pairingPath == nil ? "未設定" : (FileManager.default.fileExists(atPath: pairingPath!) ? "アプリ内に存在" : "パス上に見つからない"),
                          good: pairingPath != nil && FileManager.default.fileExists(atPath: pairingPath!))
            diagnosticRow("Tunnel IPv4", value: isValidIPv4Address(deviceIP) ? deviceIP : "入力値を確認",
                          good: isValidIPv4Address(deviceIP))
            diagnosticRow("座標入力", value: coordinate == nil ? "範囲外または未入力" : "緯度・経度の範囲内",
                          good: coordinate != nil)
            diagnosticRow("アプリ内ステータス", value: isWorking ? "処理中" : (isActive ? "設定API成功（端末側は未検証）" : status),
                          good: !isWorking && (isActive || status == "未接続" || status.contains("成功")))
            Text("ここで確認するのはアプリ内のファイル・入力・処理状態です。端末への接続や他アプリへの反映を、この診断だけで保証するものではありません。")
                .font(.caption).foregroundStyle(Neon.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                refreshConnectionState()
            } label: {
                Label("状態を再確認", systemImage: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Neon.cyan)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Neon.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.09), lineWidth: 1))
            }
            .buttonStyle(SoftPressButtonStyle())
            .disabled(isWorking)
        }
        .padding(14)
        .modifier(LiquidGlassSurface(cornerRadius: 20))
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("復旧・状態管理", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            Text("接続に失敗した場合は、設定を確認して再試行できます。ペアリングファイルの削除はシミュレーション解除後に行ってください。")
                .font(.caption).foregroundStyle(Neon.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await retryLocationSetup() }
            } label: {
                Label(isWorking ? "処理中…" : "現在の座標で接続を再試行", systemImage: "arrow.clockwise.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Neon.gradient, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(SoftPressButtonStyle())
            .disabled(isWorking || isActive || coordinate == nil || pairingPath == nil || !isValidIPv4Address(deviceIP))
            Button(role: .destructive) {
                showingPairingDeleteConfirmation = true
            } label: {
                Label("ペアリング情報を削除", systemImage: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isActive ? Neon.muted : Color.orange)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.orange.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(SoftPressButtonStyle())
            .disabled(isWorking || isActive || pairingPath == nil)
            if isActive {
                Text("先に「シミュレーションを解除」を実行してください。")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(14)
        .modifier(LiquidGlassSurface(cornerRadius: 20))
    }

    private func diagnosticRow(_ title: String, value: String, good: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Neon.muted)
            Spacer(minLength: 8)
            Text(value).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(good ? Neon.cyan : Color.orange)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    private func isValidIPv4Address(_ value: String) -> Bool {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard !part.isEmpty, let number = Int(part), (0...255).contains(number) else { return false }
            return String(number) == String(part)
        }
    }

    private func refreshConnectionState() {
        pairingStore.refresh()
        if pairingStore.hasPairingFile {
            pairingPath = pairingStore.pairingPath
            pairingName = PairingStore.fileName
        } else {
            pairingPath = nil
            pairingName = "未選択"
        }
        status = "アプリ内状態を再確認しました（端末側の反映は未検証）"
    }

    private func deletePairingFile() {
        guard !isActive else {
            errorMessage = "ペアリング情報を削除する前に、シミュレーションを解除してください。"
            return
        }
        do {
            try pairingStore.removePairing()
            pairingPath = nil
            pairingName = "未選択"
            status = "ペアリング情報を削除しました"
            errorMessage = nil
        } catch {
            errorMessage = "ペアリング情報を削除できませんでした: \\(error.localizedDescription)"
        }
    }

    @MainActor
    private func retryLocationSetup() async {
        guard !isActive else { return }
        await setLocation()
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
            }.buttonStyle(SoftPressButtonStyle())
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
            .modifier(LiquidGlassSurface(cornerRadius: 18))
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
            }.buttonStyle(SoftPressButtonStyle())
            if showConnectionSettings {
                heading("03", "CONNECTION", "開発用サービスへの接続設定")
            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("TUNNEL IP")
                TextField("10.7.0.1", text: $deviceIP)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .font(.system(size: 14, design: .monospaced)).foregroundStyle(.white)
                    .padding(13).background(Neon.bg, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.075), lineWidth: 1))
            }
            HStack(spacing: 10) {
                Image(systemName: "doc.badge.gearshape").font(.title2).foregroundStyle(Neon.cyan)
                    .frame(width: 40, height: 40).background(Neon.cyan.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 4) {
                    Text("RPPairing FILE").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                    Text(pairingName).font(.caption).foregroundStyle(Neon.muted).lineLimit(1)
                }
                Spacer()
                Button("選択") { showingImporter = true }
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Neon.cyan)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Neon.cyan.opacity(0.055), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
            }
                Text("ペアリングファイルは端末内のアプリ領域にコピーします。リポジトリやログには保存しません。")
                    .font(.footnote).foregroundStyle(Neon.muted)
            }
        }.padding(12)
            .modifier(LiquidGlassSurface(cornerRadius: 18))
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
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.06), lineWidth: 1))
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
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.075), lineWidth: 1))
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
            // Keep all imports in PairingStore's canonical Application Support location.
            // The previous Documents copy made the UI and native pairing engine disagree
            // about which pairing file was installed.
            try pairingStore.importPairing(from: source)
            pairingStore.refresh()
            pairingPath = pairingStore.hasPairingFile ? pairingStore.pairingPath : nil
            pairingName = pairingStore.hasPairingFile ? PairingStore.fileName : "未選択"
            errorMessage = nil
            consoleLog.log("ペアリングファイルを取り込みました")
        } catch {
            consoleLog.log("ペアリングファイルの取り込み失敗: \(error.localizedDescription)", level: .error)
            errorMessage = "ペアリングファイルを取り込めませんでした: \(error.localizedDescription)"
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
            status = "座標設定APIは成功（端末側の反映は未検証）"
            consoleLog.log(String(format: "位置情報設定 API 成功: %.6f, %.6f（端末側の反映は未検証）", coordinate.latitude, coordinate.longitude))
            PairingActivityManager.update(status: "位置情報設定API成功", detail: String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
        } catch {
            status = "設定失敗"
            errorMessage = error.localizedDescription
            consoleLog.log("位置情報設定 API 失敗: \(error.localizedDescription)", level: .error)
            PairingActivityManager.update(status: "位置情報設定失敗", detail: String(error.localizedDescription.prefix(80)))
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
            status = "解除APIは成功（端末側の解除状態は未検証）"
            consoleLog.log("位置情報解除 API 成功（端末側の解除状態は未検証）")
            PairingActivityManager.update(status: "シミュレーション解除API成功", detail: "端末側の解除状態は未検証")
        } catch {
            status = "解除失敗"
            errorMessage = error.localizedDescription
            consoleLog.log("位置情報解除 API 失敗: \(error.localizedDescription)", level: .error)
            PairingActivityManager.update(status: "シミュレーション解除失敗", detail: String(error.localizedDescription.prefix(80)))
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(14)
            .modifier(LiquidGlassSurface(cornerRadius: 21))
    }
}


private struct SoftPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.62), value: configuration.isPressed)
    }
}


private struct LiquidGlassSurface: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if #available(iOS 26.0, *) {
                    shape.fill(.clear)
                        .glassEffect(.regular, in: shape)
                } else {
                    shape.fill(Neon.panel.opacity(0.96))
                }
            }
            .overlay {
                shape.stroke(.white.opacity(0.11), lineWidth: 1)
            }
    }
}
