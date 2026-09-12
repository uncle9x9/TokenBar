// Build with the TokenBarCore module and object files after `make build`.
import AppKit
import TokenBarCore

let now = Date(timeIntervalSince1970: 1_800_000_000)
let canvas = NSImage(size: NSSize(width: 1000, height: 450), flipped: false) { _ in
    let labels = ["New window", "Halfway", "Near reset", "Quota full", "Reset pending", "Unavailable"]
    for row in 0..<2 {
        let dark = row == 0
        (dark ? NSColor(calibratedWhite: 0.10, alpha: 1) : .white).setFill()
        NSRect(x: 0, y: row * 225, width: 1000, height: 225).fill()
        for index in 0..<6 {
            let remaining: Double = [18000, 9000, 900, 4500, -1, 0][index]
            let percent: Double = [0, 45, 80, 100, 100, 0][index]
            let usage = index == 5 ? nil : ProviderUsage(id: "claude", displayName: "Claude", sessionPercent: percent,
                sessionWindowMinutes: 300, sessionResetsAt: now.addingTimeInterval(remaining))
            let state = QuotaClockState(usage: usage, now: now)
            let x = CGFloat(index) * 163 + 38
            let y = CGFloat(row) * 225
            for size: CGFloat in [72, 18] {
                let icon = QuotaClockIcon.render(state: state, dark: dark, size: size)
                let rect = NSRect(x: x + (72 - size) / 2, y: y + (size == 72 ? 102 : 60), width: size, height: size)
                let tinted = NSImage(size: icon.size, flipped: false) { bounds in
                    icon.draw(in: bounds)
                    if icon.isTemplate {
                        (dark ? NSColor.white : .black).setFill()
                        bounds.fill(using: .sourceAtop)
                    }
                    return true
                }
                tinted.draw(in: rect)
            }
            (labels[index] as NSString).draw(at: NSPoint(x: x - 14, y: y + 22), withAttributes: [
                .font: NSFont.systemFont(ofSize: 13), .foregroundColor: dark ? NSColor.white : NSColor.black
            ])
        }
    }
    return true
}
let rep = NSBitmapImageRep(data: canvas.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
