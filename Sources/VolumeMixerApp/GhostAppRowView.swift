import AppKit
import SwiftUI
import VolumeMixerCore

struct GhostAppRowView: View {
    @EnvironmentObject private var engine: AudioEngine
    let bundleID: String
    let name: String

    private static var iconCache: [String: NSImage] = [:]

    private var icon: NSImage {
        if let cached = Self.iconCache[bundleID] {
            return cached
        }
        let resolved: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            resolved = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            resolved = NSImage(named: NSImage.applicationIconName) ?? NSImage()
        }
        Self.iconCache[bundleID] = resolved
        return resolved
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 18, height: 18)
                .saturation(0.4)
            Image(systemName: "pin.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(name), закреплено")
                Text("Нет аудиосессии")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu { pinContextMenuActions }
        .accessibilityActions { pinAccessibilityActions }
    }

    @ViewBuilder
    private var pinContextMenuActions: some View {
        Button("Открепить") { engine.unpin(bundleID: bundleID) }
        Button("Переместить выше") {
            engine.movePinned(bundleID: bundleID, direction: .up)
        }
        Button("Переместить ниже") {
            engine.movePinned(bundleID: bundleID, direction: .down)
        }
    }

    @ViewBuilder
    private var pinAccessibilityActions: some View {
        Button("Открепить") { engine.unpin(bundleID: bundleID) }
        Button("Переместить выше") {
            engine.movePinned(bundleID: bundleID, direction: .up)
        }
        Button("Переместить ниже") {
            engine.movePinned(bundleID: bundleID, direction: .down)
        }
    }
}
