import AppKit
import DiskMeerkatApp
import SwiftUI

enum DiskMeerkatSceneIdentifier {
    static let status = "DiskMeerkat.status"
}

struct DiskMeerkatMenuBarSceneLabel: View {
    @Environment(\.openWindow) private var openWindow

    let controller: DiskMeerkatApplicationController
    let statusRouter: DiskMeerkatStatusWindowRouter

    var body: some View {
        DiskMeerkatMenuBarLabel(model: controller.model)
            .onAppear {
                statusRouter.install {
                    openWindow(id: DiskMeerkatSceneIdentifier.status)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
    }
}

struct DiskMeerkatMenuScene: View {
    @Environment(\.openSettings) private var openSettings

    let controller: DiskMeerkatApplicationController
    let statusRouter: DiskMeerkatStatusWindowRouter

    var body: some View {
        DiskMeerkatMenuView(
            model: controller.model,
            actions: DiskMeerkatSurfaceActions(
                openStatus: {
                    dismissMenuBarExtra()
                    statusRouter.requestStatus()
                },
                openSettings: {
                    dismissMenuBarExtra()
                    openSettings()
                },
                quit: {
                    NSApp.terminate(nil)
                }
            )
        )
    }

    private func dismissMenuBarExtra() {
        NSApp.keyWindow?.close()
    }
}

struct DiskMeerkatStatusScene: View {
    @Environment(\.openSettings) private var openSettings

    let controller: DiskMeerkatApplicationController

    var body: some View {
        DiskMeerkatStatusView(
            model: controller.model,
            openSettings: {
                openSettings()
            }
        )
        .onDisappear {
            controller.statusWindowDidClose()
        }
    }
}

struct DiskMeerkatSettingsScene: View {
    let controller: DiskMeerkatApplicationController

    var body: some View {
        DiskMeerkatSettingsView(model: controller.model)
    }
}
