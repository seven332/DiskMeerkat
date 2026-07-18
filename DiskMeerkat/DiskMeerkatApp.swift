import SwiftUI

@main
struct DiskMeerkatApp: App {
    @NSApplicationDelegateAdaptor(DiskMeerkatApplicationDelegate.self)
    private var applicationDelegate

    var body: some Scene {
        MenuBarExtra {
            DiskMeerkatMenuScene(
                controller: applicationDelegate.controller,
                statusRouter: applicationDelegate.statusRouter
            )
        } label: {
            DiskMeerkatMenuBarSceneLabel(
                controller: applicationDelegate.controller,
                statusRouter: applicationDelegate.statusRouter
            )
        }
        .menuBarExtraStyle(.window)

        Window("DiskMeerkat Status", id: DiskMeerkatSceneIdentifier.status) {
            DiskMeerkatStatusScene(controller: applicationDelegate.controller)
        }
        .defaultSize(width: 640, height: 540)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .windowResizability(.contentSize)

        Settings {
            DiskMeerkatSettingsScene(controller: applicationDelegate.controller)
        }
    }
}
