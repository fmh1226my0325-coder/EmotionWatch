
import Foundation
import Combine
import WatchConnectivity

@MainActor
final class WatchTransferManager: NSObject, ObservableObject {

    @Published private(set) var isSupported = WCSession.isSupported()
    @Published private(set) var pendingCount = 0
    @Published var status = "尚未传输"

    static let shared = WatchTransferManager()

    private override init() {
        super.init()

        guard WCSession.isSupported() else { return }

        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - iPhone 发送文件到 Apple Watch

    func sendToWatch(fileURL: URL) {
        #if os(iOS)

        guard WCSession.isSupported() else {
            status = "当前设备不支持 WatchConnectivity"
            return
        }

        guard WCSession.default.isPaired else {
            status = "请先配对 Apple Watch"
            return
        }

        guard WCSession.default.isWatchAppInstalled else {
            status = "请先安装手表 App"
            return
        }

        WCSession.default.transferFile(
            fileURL,
            metadata: [
                "fileName": fileURL.lastPathComponent
            ]
        )

        pendingCount = WCSession.default.outstandingFileTransfers.count
        status = "已加入传输队列"

        #else

        status = "请在 iPhone App 中发送文件"

        #endif
    }

    // MARK: - 保存接收到的文件

    private func saveReceivedFile(
        _ source: URL,
        metadata: [String: Any]?
    ) {
        let name =
            (metadata?["fileName"] as? String)
            ?? source.lastPathComponent

        let safeName = URL(fileURLWithPath: name).lastPathComponent

        let destination = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(safeName)

        do {
            if FileManager.default.fileExists(
                atPath: destination.path
            ) {
                try FileManager.default.removeItem(at: destination)
            }

            try FileManager.default.copyItem(
                at: source,
                to: destination
            )

            status = "已接收：\(safeName)"

        } catch {
            status = "接收失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - WatchConnectivity

extension WatchTransferManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.status = "连接失败：\(error.localizedDescription)"
            } else {
                self.status = "连接状态：\(state.rawValue)"
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceive file: WCSessionFile
    ) {
        let url = file.fileURL
        let metadata = file.metadata

        Task { @MainActor in
            self.saveReceivedFile(url, metadata: metadata)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.status = "传输失败：\(error.localizedDescription)"
            } else {
                self.status = "文件传输完成"
            }

            #if os(iOS)
            self.pendingCount =
                WCSession.default.outstandingFileTransfers.count
            #endif
        }
    }

    #if os(iOS)

    nonisolated func sessionDidBecomeInactive(
        _ session: WCSession
    ) {
    }

    nonisolated func sessionDidDeactivate(
        _ session: WCSession
    ) {
        session.activate()
    }

    #endif
}
