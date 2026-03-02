import SwiftUI

@main
struct TodoKitApp: App {
    var body: some Scene {
        WindowGroup("代办列表") {
            ContentView()
        }
        .windowResizability(.automatic)
        .defaultSize(width: 460, height: 520)
    }
}
