import SwiftUI

@main
struct ShogiCoachPoCApp: App {
    var body: some Scene {
        WindowGroup {
            VE1BB6RootView()
            #if targetEnvironment(simulator)
            .task {
                await VE1ASimulatorPreflight.runIfRequested()
                await VE1BSimulatorCIProbe.runIfRequested()
                await B6ShallowFixedNodeSimulatorProbe.runIfRequested()
                await B6IncompleteStateSimulatorProbe.runIfRequested()
                await VE1C1B6ShallowParityProbe.runIfRequested()
                await VE1C1PoolSimulatorProbe.runIfRequested()
                await SimulatorCIProbe.runIfRequested()
            }
            #endif
        }
    }
}