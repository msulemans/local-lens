import SwiftUI

@main
struct LocalLensApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("Local Lens")
                    .font(.largeTitle.weight(.semibold))
                Text("Evidence-native search for Mac")
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 720, minHeight: 480)
        }
    }
}
