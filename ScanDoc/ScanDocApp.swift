import SwiftUI

@main
struct ScanDocApp: App {
    @StateObject private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(store)
        }
    }
}
