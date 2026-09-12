import AppKit

/// The two parts of the icon always describe the same provider and quota window.
public struct QuotaClockState: Equatable, Sendable {
    public let usedFraction: Double?
    public let remainingSteps: Int?
    public let awaitingReset: Bool
    public let resetsAt: Date?

    public var exhausted: Bool { (usedFraction ?? 0) >= 1 }

    public init(usage: ProviderUsage?, windowID: String = "session", now: Date = Date()) {
        let weekly = windowID == "weekly"
        let percent = weekly ? usage?.weeklyPercent : usage?.sessionPercent
        let minutes = weekly ? usage?.weeklyWindowMinutes : usage?.sessionWindowMinutes
        let reset = weekly ? usage?.weeklyResetsAt : usage?.sessionResetsAt
        let valid = usage?.error == nil && percent?.isFinite == true && (percent ?? -1) >= 0
        usedFraction = valid ? min(1, (percent ?? 0) / 100) : nil
        resetsAt = valid ? reset : nil
        awaitingReset = valid && reset.map { $0 <= now } == true
        if valid, let reset, let minutes, minutes > 0 {
            let fraction = max(0, min(1, reset.timeIntervalSince(now) / (Double(minutes) * 60)))
            remainingSteps = Int(ceil(fraction * 60))
        } else {
            remainingSteps = nil
        }
    }

    public func description(provider: String, window: String, now: Date = Date()) -> String {
        guard let usedFraction else { return "\(provider) · \(window): quota unavailable" }
        let usage = "\(provider) · \(window): \(Int((usedFraction * 100).rounded()))% used"
        if awaitingReset { return usage + " · awaiting reset update" }
        if let resetsAt {
            let minutes = max(1, Int(ceil(resetsAt.timeIntervalSince(now) / 60)))
            return usage + " · resets in \(minutes / 60)h \(minutes % 60)m"
        }
        return usage + " · reset time unavailable"
    }
}

/// Native vector drawing is required for a live, sixty-step status indicator.
/// Normal glyphs are templates; exhaustion uses adaptive foreground plus system red.
public enum QuotaClockIcon {
    public static func render(state: QuotaClockState, dark: Bool = false, size: CGFloat = 18, rotationAngle: CGFloat = 0) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let scale = size / 18
            let foreground: NSColor = state.exhausted && dark ? .white : .black
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = 7.4 * scale
            func arc(start: CGFloat, end: CGFloat, color: NSColor, dashed: Bool = false) {
                color.setStroke()
                let path = NSBezierPath()
                path.lineWidth = 1.65 * scale
                path.lineCapStyle = .round
                if dashed { path.setLineDash([1.0 * scale, 2.0 * scale], count: 2, phase: 0) }
                path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
                path.stroke()
            }

            NSGraphicsContext.saveGraphicsState()
            if rotationAngle != 0 && state.remainingSteps == nil {
                let transform = NSAffineTransform()
                transform.translateX(by: center.x, yBy: center.y)
                transform.rotate(byDegrees: rotationAngle)
                transform.translateX(by: -center.x, yBy: -center.y)
                transform.concat()
            }

            // The subdued track keeps the clock silhouette recognisable near reset.
            arc(start: 80, end: -260, color: foreground.withAlphaComponent(0.20))
            if let steps = state.remainingSteps {
                if steps > 0 {
                    let elapsed = CGFloat(60 - steps) * (340.0 / 60)
                    arc(start: 80 - elapsed, end: -260, color: foreground)
                }
            } else {
                arc(start: 80, end: -260, color: foreground.withAlphaComponent(0.65), dashed: true)
            }
            NSGraphicsContext.restoreGraphicsState()

            let barRect = NSRect(x: center.x - 4.6 * scale, y: center.y - 1.55 * scale,
                                 width: 9.2 * scale, height: 3.1 * scale)
            let capsule = NSBezierPath(roundedRect: barRect, xRadius: 1.55 * scale, yRadius: 1.55 * scale)
            foreground.withAlphaComponent(0.20).setFill()
            capsule.fill()
            if let fraction = state.usedFraction, fraction > 0 {
                NSGraphicsContext.saveGraphicsState()
                capsule.addClip()
                (state.exhausted ? NSColor.systemRed : foreground).setFill()
                NSRect(x: barRect.minX, y: barRect.minY, width: barRect.width * fraction, height: barRect.height).fill()
                NSGraphicsContext.restoreGraphicsState()
            } else if state.usedFraction == nil {
                // An outline is unknown data; an empty filled track means confirmed zero usage.
                foreground.withAlphaComponent(0.65).setStroke()
                capsule.lineWidth = 0.6 * scale
                capsule.stroke()
            }
            return true
        }
        image.isTemplate = !state.exhausted
        image.accessibilityDescription = "TokenBar quota clock"
        return image
    }

    public static func combining(clock: NSImage, details: NSImage, dark: Bool) -> NSImage {
        let gap: CGFloat = 6
        return NSImage(size: NSSize(width: clock.size.width + gap + details.size.width, height: 22), flipped: false) { _ in
            let rect = NSRect(x: 0, y: (22 - clock.size.height) / 2, width: clock.size.width, height: clock.size.height)
            NSGraphicsContext.saveGraphicsState()
            clock.draw(in: rect)
            if clock.isTemplate {
                (dark ? NSColor.white : NSColor.black).setFill()
                rect.fill(using: .sourceAtop)
            }
            NSGraphicsContext.restoreGraphicsState()
            details.draw(in: NSRect(x: clock.size.width + gap, y: 0, width: details.size.width, height: details.size.height))
            return true
        }
    }
}
