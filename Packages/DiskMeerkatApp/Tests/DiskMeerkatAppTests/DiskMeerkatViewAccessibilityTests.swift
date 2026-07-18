import AppKit
import SwiftUI
import XCTest

@testable import DiskMeerkatApp

@MainActor
final class DiskMeerkatViewAccessibilityTests: XCTestCase {
    func testSettingsActionsRemainInTheAccessibilityHierarchy() {
        let model = DiskMeerkatPreviewFixtures.healthyModel()
        model.beginSettingsEditing()
        model.settingsDraft.thresholdText = "20.5"

        let hostingView = NSHostingView(rootView: DiskMeerkatSettingsView(model: model))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 470),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()

        let identifiers = accessibilityIdentifiers(in: hostingView)
        XCTAssertTrue(identifiers.contains(DiskMeerkatAccessibilityIdentifiers.settingsCancel))
        XCTAssertTrue(identifiers.contains(DiskMeerkatAccessibilityIdentifiers.settingsSave))
    }

    private func accessibilityIdentifiers(in root: NSView) -> Set<String> {
        var identifiers = Set<String>()
        var pending: [Any] = [root]
        var visited = Set<ObjectIdentifier>()

        while let element = pending.popLast() {
            if let object = element as? NSObject {
                guard visited.insert(ObjectIdentifier(object)).inserted else {
                    continue
                }
            }

            if let view = element as? NSView {
                let identifier = view.accessibilityIdentifier()
                if !identifier.isEmpty {
                    identifiers.insert(identifier)
                }
                pending.append(contentsOf: view.subviews)
                pending.append(contentsOf: view.accessibilityChildren() ?? [])
            } else if let accessibilityElement = element as? NSAccessibilityElement {
                if let identifier = accessibilityElement.accessibilityIdentifier(),
                    !identifier.isEmpty
                {
                    identifiers.insert(identifier)
                }
                pending.append(contentsOf: accessibilityElement.accessibilityChildren() ?? [])
            }
        }

        return identifiers
    }
}
