import Darwin
import Foundation
import idevice

enum LocationEngineError: LocalizedError {
    case invalidIP, pairingRead, tunnelCreate, remoteServer, simulationCreate, locationSet, locationClear

    var errorDescription: String? {
        switch self {
        case .invalidIP: return "Tunnel IPがIPv4アドレスとして認識できません。"
        case .pairingRead: return "選択したRPPairingファイルを読み込めません。"
        case .tunnelCreate: return "開発用トンネルを作成できません。端末・LocalDevVPN・ペアリングを確認してください。"
        case .remoteServer: return "RemoteXPC接続に失敗しました。"
        case .simulationCreate: return "位置情報シミュレーションサービスを開始できません。"
        case .locationSet: return "座標を設定できませんでした。"
        case .locationClear: return "位置情報シミュレーションを解除できませんでした。"
        }
    }
}

/// Shift の LocationEngine を最小化した実験用ラッパー。
/// ペアリングファイルの内容やネイティブエラー文字列はログに出さない。
enum LocationEngine {
    private static let queue = DispatchQueue(label: "location.simulation.engine")
    private static var adapter: OpaquePointer?
    private static var handshake: OpaquePointer?
    private static var remoteServer: OpaquePointer?
    private static var simulation: OpaquePointer?
    private static var activePairingPath: String?
    private static var activeDeviceIP: String?

    static func set(latitude: Double, longitude: Double, pairingPath: String, deviceIP: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try connectIfNeeded(pairingPath: pairingPath, deviceIP: deviceIP)
                    guard let simulation else { throw LocationEngineError.simulationCreate }
                    if let error = location_simulation_set(simulation, latitude, longitude) {
                        idevice_error_free(error)
                        cleanup()
                        throw LocationEngineError.locationSet
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func clear(pairingPath: String, deviceIP: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try connectIfNeeded(pairingPath: pairingPath, deviceIP: deviceIP)
                    guard let simulation else { throw LocationEngineError.simulationCreate }
                    let error = location_simulation_clear(simulation)
                    cleanup()
                    if let error {
                        idevice_error_free(error)
                        throw LocationEngineError.locationClear
                    }
                    continuation.resume()
                } catch {
                    cleanup()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func connectIfNeeded(pairingPath: String, deviceIP: String) throws {
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(49152).bigEndian
        guard deviceIP.withCString({ inet_pton(AF_INET, $0, &address.sin_addr) }) == 1 else {
            throw LocationEngineError.invalidIP
        }

        if simulation != nil, activePairingPath == pairingPath, activeDeviceIP == deviceIP {
            return
        }
        if simulation != nil || adapter != nil || handshake != nil || remoteServer != nil {
            cleanup()
        }

        var pairing: OpaquePointer?
        if let error = pairingPath.withCString({ rp_pairing_file_read($0, &pairing) }) {
            idevice_error_free(error)
            throw LocationEngineError.pairingRead
        }
        guard let pairing else { throw LocationEngineError.pairingRead }
        defer { rp_pairing_file_free(pairing) }

        let tunnelError = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                tunnel_create_rppairing(
                    $0,
                    socklen_t(MemoryLayout<sockaddr_in>.stride),
                    "LocationSimulationLab",
                    pairing,
                    nil,
                    nil,
                    &adapter,
                    &handshake
                )
            }
        }
        if let tunnelError {
            idevice_error_free(tunnelError)
            cleanup()
            throw LocationEngineError.tunnelCreate
        }

        if let error = remote_server_connect_rsd(adapter, handshake, &remoteServer) {
            idevice_error_free(error)
            cleanup()
            throw LocationEngineError.remoteServer
        }

        if let error = location_simulation_new(remoteServer, &simulation) {
            idevice_error_free(error)
            cleanup()
            throw LocationEngineError.simulationCreate
        }
        // Shift と同じく、simulation 作成後は remoteServer の所有権を移す。
        remoteServer = nil
        activePairingPath = pairingPath
        activeDeviceIP = deviceIP
    }

    private static func cleanup() {
        if let simulation {
            location_simulation_free(simulation)
            self.simulation = nil
        }
        if let remoteServer {
            remote_server_free(remoteServer)
            self.remoteServer = nil
        }
        if let handshake {
            rsd_handshake_free(handshake)
            self.handshake = nil
        }
        if let adapter {
            adapter_free(adapter)
            self.adapter = nil
        }
        activePairingPath = nil
        activeDeviceIP = nil
    }
}
