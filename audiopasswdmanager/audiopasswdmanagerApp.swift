import SwiftUI

#if os(macOS)
private let kAspectRatio: CGFloat = 1100 / 580
private let kMinWidth:    CGFloat = 780
#endif

@main
struct audiopasswdmanagerApp: App {
    @StateObject private var vm = TimelineViewModel()

    var body: some Scene {
        #if os(iOS)
        WindowGroup {
            iOSContentView()
                .environmentObject(vm)
                .preferredColorScheme(vm.colorScheme)
        }
        #else
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .preferredColorScheme(vm.colorScheme)
                .background(WindowAspectLocker(ratio: kAspectRatio))
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 580)
        #endif
    }
}

// MARK: - Window aspect ratio enforcer (macOS only)

#if os(macOS)
private struct WindowAspectLocker: NSViewRepresentable {
    let ratio: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.apply(to: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { self.apply(to: nsView.window) }
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
        window.contentAspectRatio = NSSize(width: ratio, height: 1)
        let minH = (kMinWidth / ratio).rounded()
        window.minSize = NSSize(width: kMinWidth, height: minH)
    }
}
#endif
