import SwiftUI

@main
struct ShogiCoachPoCApp: App {
    var body: some Scene {
        WindowGroup {
            VE1ARootView()
            #if targetEnvironment(simulator)
            .task {
                await VE1ASimulatorPreflight.runIfRequested()
                await VE1BSimulatorCIProbe.runIfRequested()
                await SimulatorCIProbe.runIfRequested()
            }
            #endif
        }
    }
}
