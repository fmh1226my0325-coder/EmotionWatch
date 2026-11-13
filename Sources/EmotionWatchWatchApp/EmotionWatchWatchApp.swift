import SwiftUI

@main
struct EmotionWatchWatchApp: App {
    @StateObject private var mediaLibrary = OfflineMediaLibrary()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mediaLibrary)
        }
    }
}
