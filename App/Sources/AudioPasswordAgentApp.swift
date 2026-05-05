import SwiftUI

@main
struct audiopasswdmanagerApp: App {
    @StateObject private var vm = TimelineViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .preferredColorScheme(vm.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 580)
    }
}
