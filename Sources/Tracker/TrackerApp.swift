import SwiftUI
import AppKit

@main
struct TrackerApp: App {
    @StateObject private var store = TrackerStore(baseDirectory: "/Users/Arne/Documents/GitHub/Tracker")
    @State private var hasAdjustedInitialWindowState = false
    private var initialWindowSize: CGSize {
        NSScreen.main?.visibleFrame.size ?? CGSize(width: 1512, height: 982)
    }

    var body: some Scene {
        WindowGroup("Arne Daily Tracker") {
            ContentView()
                .environmentObject(store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    enforceWindowStateIfNeeded()
                }
        }
        .defaultSize(width: initialWindowSize.width, height: initialWindowSize.height)
        .windowStyle(.hiddenTitleBar)
    }

    private func enforceWindowStateIfNeeded() {
        guard !hasAdjustedInitialWindowState else { return }
        hasAdjustedInitialWindowState = true

        let delays: [TimeInterval] = [0.0, 0.12, 0.35]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard let window = NSApplication.shared.windows.first else { return }
                if window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }
                if !window.isZoomed {
                    window.zoom(nil)
                }
            }
        }
    }
}
