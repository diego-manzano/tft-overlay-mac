import Foundation

/// Talks to the League client's local API (the LCU) — the same Riot-approved
/// surface every overlay uses. Polls the gameflow phase and auto-shows the
/// overlay when a TFT game starts, hides it when the game ends.
@MainActor
final class LCUClient: NSObject, ObservableObject {
    static let shared = LCUClient()

    @Published private(set) var phase = "Disconnected"
    @Published private(set) var isTFTGame = false

    static let autoShowKey = "autoShowInGame"

    private struct Lockfile {
        let port: Int
        let password: String
    }

    private static let lockfilePath =
        "/Applications/League of Legends.app/Contents/LoL/lockfile"

    private static let inGamePhases: Set<String> = ["GameStart", "InProgress"]

    private var timer: Timer?
    private lazy var session = URLSession(
        configuration: .ephemeral,
        delegate: LocalhostTrustDelegate(),
        delegateQueue: nil
    )

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
        Task { await tick() }
    }

    private func tick() async {
        guard let lock = readLockfile() else {
            apply(phase: "Disconnected", tft: false)
            return
        }
        guard let data = await get("/lol-gameflow/v1/gameflow-phase", lock: lock),
              let newPhase = try? JSONDecoder().decode(String.self, from: data)
        else {
            apply(phase: "Disconnected", tft: false)
            return
        }

        var tft = isTFTGame
        if Self.inGamePhases.contains(newPhase) {
            // The session endpoint returns a schema dump on current client
            // builds, so detect TFT from the game process itself: the game
            // binary launches with "-Product=TFT" in its arguments.
            tft = await Task.detached { Self.tftGameProcessRunning() }.value
        }
        apply(phase: newPhase, tft: tft)
    }

    private nonisolated static func tftGameProcessRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "Product=TFT"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func apply(phase newPhase: String, tft: Bool) {
        let wasInGame = Self.inGamePhases.contains(phase) && isTFTGame
        let oldPhase = phase
        phase = newPhase
        isTFTGame = tft
        guard oldPhase != newPhase,
              UserDefaults.standard.object(forKey: Self.autoShowKey) as? Bool ?? true
        else { return }

        let isInGame = Self.inGamePhases.contains(newPhase) && tft
        if isInGame && !wasInGame {
            OverlayPanelController.shared.show()
        } else if wasInGame && !isInGame {
            OverlayPanelController.shared.hide()
        }
    }

    private func readLockfile() -> Lockfile? {
        guard let content = try? String(contentsOfFile: Self.lockfilePath, encoding: .utf8) else {
            return nil
        }
        // Format: ProcessName:PID:PORT:PASSWORD:PROTOCOL
        let parts = content.split(separator: ":").map(String.init)
        guard parts.count >= 5, let port = Int(parts[2]) else { return nil }
        return Lockfile(port: port, password: parts[3])
    }

    private func get(_ path: String, lock: Lockfile) async -> Data? {
        guard let url = URL(string: "https://127.0.0.1:\(lock.port)\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        let token = Data("riot:\(lock.password)".utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return data
    }
}

/// The LCU serves a self-signed cert; trust it for 127.0.0.1 only.
private final class LocalhostTrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.host == "127.0.0.1",
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
