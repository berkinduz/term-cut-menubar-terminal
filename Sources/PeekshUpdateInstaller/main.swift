import AppKit
import Darwin
import Foundation
import PeekshCore

func reopen(_ application: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-n", application.path]
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 { throw AppUpdateError.invalidApplication }
}

func installUpdate() -> Int32 {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 4, let parent = Int32(arguments[0]), parent > 1 else { return 2 }
    let application = URL(fileURLWithPath: arguments[1])
    let destination = URL(fileURLWithPath: arguments[2])
    let directory = URL(fileURLWithPath: arguments[3])
    defer { try? FileManager.default.removeItem(at: directory) }

    do {
        let deadline = Date().addingTimeInterval(60)
        while kill(parent, 0) == 0 {
            if Date() >= deadline {
                throw NSError(domain: "PeekshUpdate", code: 1, userInfo: [NSLocalizedDescriptionKey: "Peeksh could not quit. Please try updating again."])
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        try UpdateInstallation.install(from: application, to: destination, relaunch: reopen)
        return 0
    } catch {
        if kill(parent, 0) != 0 { try? reopen(destination) }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Could Not Update Peeksh"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
        return 1
    }
}

exit(installUpdate())
