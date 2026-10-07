import SwiftUI

@main
struct ShogiCoachPoCApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            #if targetEnvironment(simulator)
            .task {
                await RecommendationDecisionHDSRealGameProbe.runPreflightIfRequested()
                await SimulatorCIProbe.runIfRequested()
            }
            #endif
        }
    }
}
