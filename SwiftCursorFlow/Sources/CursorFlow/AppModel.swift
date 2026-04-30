import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var config: AppConfig {
        didSet { config.save() }
    }
    @Published var movementEnabled = false {
        didSet { updateStatusIcon() }
    }
    @Published var clickEnabled = false {
        didSet { updateStatusIcon() }
    }
    @Published var clickCount: UInt64 = 0
    @Published var accessibilityGranted = MouseController.accessibilityGranted()
    @Published var isCapturingPosition = false
    @Published var cognitiveState = "Idle"
    @Published var batteryStatus = BatteryStatus(percentage: nil, isCharging: true)
    @Published var timerRemaining: TimeInterval?

    var onStatusChanged: ((Bool) -> Void)?
    var onThemeChanged: ((NSAppearance?) -> Void)?
    var onPositionCaptureStarted: (() -> Void)?
    var onPositionCaptureFinished: (() -> Void)?

    private var tickTimer: Timer?
    private var automationStartedAt: Date?
    private var stopTimerStartedAt: Date?
    private var lastMovement = Date()
    private var lastClick = Date()
    private var nextMovementAt = Date()
    private var movementQueue: [(point: CGPoint, delay: TimeInterval)] = []
    private var lastUserMove = Date.distantPast
    private var enginePosition = MouseController.currentPosition()
    private var lastEngineClick = Date.distantPast
    private var previousButtons = 0
    private var movementHistory = MovementHistory()
    private var clickCaptureMonitor: Any?
    private var localClickCaptureMonitor: Any?
    private var lastBatteryPoll = Date.distantPast

    init() {
        config = AppConfig.load()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func requestAccessibility() {
        MouseController.requestAccessibility()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.accessibilityGranted = MouseController.accessibilityGranted()
        }
    }

    func setClickPosition() {
        stopPositionCapture()
        isCapturingPosition = true
        onPositionCaptureStarted?()

        clickCaptureMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.finishPositionCapture(at: NSEvent.mouseLocation) }
        }
        localClickCaptureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in self?.finishPositionCapture(at: NSEvent.mouseLocation) }
            return nil
        }
    }

    func clearClickPosition() {
        config.clickPosition = nil
        clickEnabled = false
    }

    func resetClickCount() {
        clickCount = 0
    }

    func setTimerEnabled(_ enabled: Bool) {
        config.timerEnabled = enabled
        stopTimerStartedAt = enabled ? Date() : nil
        timerRemaining = enabled ? timerDuration : nil
    }

    func updateTimerHours(_ hours: Int) {
        config.timerHours = hours
        resetStopTimerIfNeeded()
    }

    func updateTimerMinutes(_ minutes: Int) {
        config.timerMinutes = minutes
        resetStopTimerIfNeeded()
    }

    func applyTheme() {
        let appearance = appearanceForCurrentTheme()
        NSApp.appearance = appearance
        onThemeChanged?(appearance)
    }

    func appearanceForCurrentTheme() -> NSAppearance? {
        switch config.theme {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    private func tick() {
        accessibilityGranted = MouseController.accessibilityGranted()
        if Date().timeIntervalSince(lastBatteryPoll) > 30 {
            batteryStatus = readBatteryStatus()
            lastBatteryPoll = Date()
        }
        observeUserActivity()
        enforceTimer()

        if shouldPauseForBattery() {
            movementEnabled = false
            clickEnabled = false
            return
        }

        if clickEnabled {
            if userMovedRecently() {
                return
            }
            if Date().timeIntervalSince(lastClick) >= config.clickInterval {
                if let pos = config.clickPosition {
                    MouseController.click(at: CGPoint(x: pos.x, y: pos.y), button: config.clickButton)
                    lastEngineClick = Date()
                    clickCount += 1
                }
                lastClick = Date()
            }
        }

        guard movementEnabled, !userMovedRecently() else {
            movementQueue.removeAll()
            return
        }

        let state = inferredCognitiveState()
        cognitiveState = state.label
        if !movementQueue.isEmpty {
            executeQueuedMovementIfNeeded()
        } else if Date().timeIntervalSince(lastMovement) >= nextInterval(for: state) {
            planMovement(for: state)
            lastMovement = Date()
            executeQueuedMovementIfNeeded()
        }
    }

    private func observeUserActivity() {
        let current = MouseController.currentPosition()
        let distance = hypot(current.x - enginePosition.x, current.y - enginePosition.y)
        if distance > 12 {
            lastUserMove = Date()
            enginePosition = current
        }
        cognitiveState = currentCognitiveState()

        let buttons = NSEvent.pressedMouseButtons
        let newDown = buttons & ~previousButtons
        if (newDown & 0b11) != 0, Date().timeIntervalSince(lastEngineClick) > 0.4 {
            clickEnabled = false
        }
        previousButtons = buttons
    }

    private func userMovedRecently() -> Bool {
        guard config.startAfter > 0 else { return false }
        return Date().timeIntervalSince(lastUserMove) < config.startAfter
    }

    private func planMovement(for state: CognitiveState) {
        let start = MouseController.currentPosition()
        let end = selectTarget(from: start, state: state)
        movementQueue = generatePath(from: start, to: end, state: state)
        movementHistory.record(from: start, to: end)
    }

    private func executeQueuedMovementIfNeeded() {
        guard Date() >= nextMovementAt, !movementQueue.isEmpty else { return }
        let next = movementQueue.removeFirst()
        MouseController.move(to: next.point)
        enginePosition = next.point
        nextMovementAt = Date().addingTimeInterval(next.delay)
    }

    private func selectTarget(from start: CGPoint, state: CognitiveState) -> CGPoint {
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let intent = Intent.select(for: state)
        let boost = movementHistory.spatialSpread < 35 ? 2.0 : 1.0
        let amplitude = state.amplitude
        let low = amplitude.lowerBound * boost
        let high = amplitude.upperBound * boost
        let angle = pickAngle(avoiding: movementHistory.meanDirection, intent: intent)
        let roll = Double.random(in: 0..<2.7)

        let x: Double
        let y: Double
        if roll < 0.9 {
            let amp = Double.random(in: (low * 0.25)..<low)
            x = start.x + cos(angle) * amp
            y = start.y + sin(angle) * amp
        } else if roll < 1.6 {
            let cx = screen.minX + screen.width * Double.random(in: 0.28...0.72)
            let cy = screen.minY + screen.height * Double.random(in: 0.22...0.68)
            let amp = Double.random(in: low...high) * 0.38
            x = cx + cos(angle) * amp
            y = cy + sin(angle) * amp
        } else if roll < 2.4 {
            let baseY = screen.minY + screen.height * Double.random(in: 0.48...0.88)
            let amp = Double.random(in: low...high)
            x = start.x + cos(angle) * amp
            y = baseY + sin(angle) * amp * 0.22
        } else if roll < 2.6 {
            let baseY = Bool.random() ? screen.minY + screen.height * 0.03 : screen.minY + screen.height * 0.95
            let amp = Double.random(in: (low * 0.4)...(high * 0.4))
            x = start.x + cos(angle) * amp
            y = baseY + sin(angle) * amp * 0.07
        } else {
            let amp = Double.random(in: low...(high * 1.5))
            x = start.x + cos(angle) * amp
            y = start.y + sin(angle) * amp
        }

        return CGPoint(
            x: min(max(x, screen.minX + 20), screen.maxX - 20),
            y: min(max(y, screen.minY + 20), screen.maxY - 20)
        )
    }

    private func generatePath(from start: CGPoint, to end: CGPoint, state: CognitiveState) -> [(point: CGPoint, delay: TimeInterval)] {
        let steps = state.waypoints
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, hypot(dx, dy))
        let nx = -dy / length
        let ny = dx / length
        let sign = Bool.random() ? 1.0 : -1.0
        let b1 = length * state.curveFactor * Double.random(in: 0.55...1.45) * sign
        let b2 = length * state.curveFactor * Double.random(in: 0.55...1.45) * -sign
        let c1 = CGPoint(
            x: start.x + dx * 0.28 + nx * b1,
            y: start.y + dy * 0.28 + ny * b1
        )
        let c2 = CGPoint(
            x: start.x + dx * 0.72 + nx * b2,
            y: start.y + dy * 0.72 + ny * b2
        )
        let overshoot = Double.random(in: 0...1) < 0.28
        let overshootDistance = Double.random(in: 4...12)
        let target = overshoot
            ? CGPoint(x: end.x + dx / length * overshootDistance, y: end.y + dy / length * overshootDistance)
            : end
        let seed = Double.random(in: 0...600)
        var result: [(CGPoint, TimeInterval)] = []

        for step in 1...steps {
            let t = Double(step) / Double(steps)
            let eased = easeInOutCubic(t)
            let basePoint = cubic(start, c1, c2, target, eased)
            let envelope = sin(t * .pi)
            let noiseX = (smoothNoise(seed + t * 9.5) * 2 - 1) * state.noiseStrength * envelope
            let noiseY = (smoothNoise(seed + 300 + t * 9.5) * 2 - 1) * state.noiseStrength * envelope
            let point = CGPoint(
                x: basePoint.x + nx * noiseX,
                y: basePoint.y + ny * noiseY
            )

            let speed = 0.32 + 0.68 * envelope
            let baseDelay = min(max((0.058 / speed), 0.018), 0.095)
            let delay: TimeInterval
            if step > 1, step < steps, Double.random(in: 0...1) < state.hesitationProbability {
                delay = Double.random(in: state.hesitationRange)
            } else {
                delay = baseDelay
            }
            result.append((point, delay))
        }

        if overshoot, let last = result.last?.0 {
            let corrections = Int.random(in: 2...5)
            for step in 1...corrections {
                let t = Double(step) / Double(corrections)
                result.append((
                    CGPoint(x: last.x + (end.x - last.x) * t, y: last.y + (end.y - last.y) * t),
                    Double.random(in: 0.025...0.075)
                ))
            }
        }

        return result
    }

    private func updateStatusIcon() {
        let active = movementEnabled || clickEnabled
        if active, automationStartedAt == nil {
            automationStartedAt = Date()
        } else if !active {
            automationStartedAt = nil
        }
        onStatusChanged?(active)
    }

    private func finishPositionCapture(at point: CGPoint) {
        config.clickPosition = ClickPosition(x: point.x, y: point.y)
        stopPositionCapture()
    }

    private func stopPositionCapture() {
        let wasCapturing = isCapturingPosition || clickCaptureMonitor != nil || localClickCaptureMonitor != nil
        if let clickCaptureMonitor {
            NSEvent.removeMonitor(clickCaptureMonitor)
            self.clickCaptureMonitor = nil
        }
        if let localClickCaptureMonitor {
            NSEvent.removeMonitor(localClickCaptureMonitor)
            self.localClickCaptureMonitor = nil
        }
        isCapturingPosition = false
        if wasCapturing {
            onPositionCaptureFinished?()
        }
    }

    private func currentCognitiveState() -> String {
        guard movementEnabled else { return "Idle" }
        if userMovedRecently() { return "User Active" }
        return inferredCognitiveState().label
    }

    private func enforceTimer() {
        guard config.timerEnabled else {
            timerRemaining = nil
            stopTimerStartedAt = nil
            return
        }
        let duration = timerDuration
        guard duration > 0 else {
            timerRemaining = nil
            return
        }
        if stopTimerStartedAt == nil {
            stopTimerStartedAt = Date()
        }
        let remaining = duration - Date().timeIntervalSince(stopTimerStartedAt ?? Date())
        timerRemaining = max(0, remaining)
        if remaining <= 0 {
            movementEnabled = false
            clickEnabled = false
            setTimerEnabled(false)
        }
    }

    private var timerDuration: TimeInterval {
        TimeInterval(max(0, config.timerHours) * 3600 + max(0, config.timerMinutes) * 60)
    }

    private func resetStopTimerIfNeeded() {
        if config.timerEnabled {
            stopTimerStartedAt = Date()
            timerRemaining = timerDuration
        }
    }

    private func shouldPauseForBattery() -> Bool {
        guard config.batteryProtectionEnabled,
              !batteryStatus.isCharging,
              let percentage = batteryStatus.percentage
        else {
            return false
        }
        return percentage <= config.batteryThreshold
    }
}

private enum CognitiveState {
    case microInteraction
    case navigatingUI
    case reading
    case thinking
    case idle

    var label: String {
        switch self {
        case .microInteraction: "Micro"
        case .navigatingUI: "Navigating"
        case .reading: "Reading"
        case .thinking: "Thinking"
        case .idle: "Idle"
        }
    }

    var amplitude: ClosedRange<Double> {
        switch self {
        case .microInteraction: 14...55
        case .navigatingUI: 90...300
        case .reading: 45...160
        case .thinking: 30...110
        case .idle: 10...40
        }
    }

    var waypoints: Int {
        switch self {
        case .microInteraction: 8
        case .navigatingUI: 26
        case .reading: 18
        case .thinking: 14
        case .idle: 8
        }
    }

    var curveFactor: Double {
        switch self {
        case .microInteraction: 0.10
        case .navigatingUI: 0.38
        case .reading: 0.28
        case .thinking: 0.22
        case .idle: 0.13
        }
    }

    var noiseStrength: Double {
        switch self {
        case .microInteraction: 1.2
        case .navigatingUI: 4.0
        case .reading: 2.8
        case .thinking: 2.0
        case .idle: 1.0
        }
    }

    var hesitationProbability: Double {
        switch self {
        case .microInteraction: 0.04
        case .navigatingUI: 0.07
        case .reading: 0.13
        case .thinking: 0.20
        case .idle: 0.10
        }
    }

    var hesitationRange: ClosedRange<Double> {
        switch self {
        case .microInteraction: 0.040...0.130
        case .navigatingUI: 0.080...0.260
        case .reading: 0.120...0.480
        case .thinking: 0.180...0.700
        case .idle: 0.200...0.900
        }
    }

    var intervalFactor: ClosedRange<Double> {
        switch self {
        case .microInteraction: 0.08...0.28
        case .navigatingUI: 0.25...0.60
        case .reading: 0.50...1.10
        case .thinking: 1.00...2.60
        case .idle: 1.50...3.80
        }
    }

    static func fromIdle(_ idleSeconds: TimeInterval) -> CognitiveState {
        let jitter = Double.random(in: -2...2)
        let t = max(0, idleSeconds + jitter)
        switch t {
        case 0..<5: return .microInteraction
        case 5..<20: return .navigatingUI
        case 20..<60: return .reading
        case 60..<180: return .thinking
        default: return .idle
        }
    }
}

private enum Intent {
    case maintainPresence
    case simulateReading
    case simulateThinking
    case moveToInteraction
    case microAdjust

    static func select(for state: CognitiveState) -> Intent {
        let r = Double.random(in: 0...1)
        switch state {
        case .microInteraction:
            return r < 0.72 ? .microAdjust : .maintainPresence
        case .navigatingUI:
            if r < 0.48 { return .moveToInteraction }
            if r < 0.78 { return .simulateReading }
            return .maintainPresence
        case .reading:
            if r < 0.58 { return .simulateReading }
            if r < 0.84 { return .maintainPresence }
            return .microAdjust
        case .thinking:
            if r < 0.52 { return .simulateThinking }
            if r < 0.78 { return .maintainPresence }
            return .microAdjust
        case .idle:
            return .maintainPresence
        }
    }
}

private struct MovementHistory {
    private var positions: [CGPoint] = []
    private var directions: [Double] = []

    var meanDirection: Double? {
        guard !directions.isEmpty else { return nil }
        let s = directions.map(sin).reduce(0, +) / Double(directions.count)
        let c = directions.map(cos).reduce(0, +) / Double(directions.count)
        return atan2(s, c)
    }

    var spatialSpread: Double {
        guard positions.count >= 2 else { return 9999 }
        let cx = positions.map(\.x).reduce(0, +) / Double(positions.count)
        let cy = positions.map(\.y).reduce(0, +) / Double(positions.count)
        return positions
            .map { hypot($0.x - cx, $0.y - cy) }
            .reduce(0, +) / Double(positions.count)
    }

    mutating func record(from: CGPoint, to: CGPoint) {
        if positions.count >= 10 {
            positions.removeFirst()
            directions.removeFirst()
        }
        positions.append(to)
        directions.append(atan2(to.y - from.y, to.x - from.x))
    }
}

private extension AppModel {
    func inferredCognitiveState() -> CognitiveState {
        let idle = lastUserMove == .distantPast ? 9999 : Date().timeIntervalSince(lastUserMove)
        return CognitiveState.fromIdle(idle)
    }

    func nextInterval(for state: CognitiveState) -> TimeInterval {
        let base = 10.0
        return base * Double.random(in: state.intervalFactor)
    }

    func pickAngle(avoiding forbidden: Double?, intent: Intent) -> Double {
        let base: Double = {
            switch intent {
            case .simulateReading:
                Double.random(in: -0.4...0.9) + .pi * 0.5
            default:
                Double.random(in: 0...(2 * .pi))
            }
        }()
        guard let forbidden else { return base }
        let reverse = (forbidden + .pi).truncatingRemainder(dividingBy: 2 * .pi)
        var diff = abs(base - reverse).truncatingRemainder(dividingBy: 2 * .pi)
        diff = min(diff, 2 * .pi - diff)
        if diff < .pi * 0.30 {
            return reverse + .pi * 0.38 * (Bool.random() ? 1 : -1)
        }
        return base
    }
}

private func cubic(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: Double) -> CGPoint {
    let u = 1 - t
    let a = u * u * u
    let b = 3 * u * u * t
    let c = 3 * u * t * t
    let d = t * t * t
    return CGPoint(
        x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
        y: a * p0.y + b * p1.y + c * p2.y + d * p3.y
    )
}

private func easeInOutCubic(_ t: Double) -> Double {
    if t < 0.5 {
        return 4 * t * t * t
    }
    return 1 - pow(-2 * t + 2, 3) / 2
}

private func smoothNoise(_ x: Double) -> Double {
    let xi = floor(x)
    let xf = x - xi
    let u = xf * xf * (3 - 2 * xf)
    func h(_ n: Int64) -> Double {
        var value = n &* 1619 &+ 31337
        value = value ^ (value >> 8)
        value = value &* 1_000_003
        return Double(value & 0x7FFF_FFFF) / Double(0x7FFF_FFFF)
    }
    let a = h(Int64(xi))
    let b = h(Int64(xi) + 1)
    return a + (b - a) * u
}

private func readBatteryStatus() -> BatteryStatus {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["-g", "batt"]
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        let percent = output
            .split(separator: "\n")
            .compactMap { line -> Int? in
                guard let range = line.range(of: #"\d+%"#, options: .regularExpression) else { return nil }
                return Int(line[range].dropLast())
            }
            .first
        let charging = output.localizedCaseInsensitiveContains("AC Power")
            || output.localizedCaseInsensitiveContains("charging")
            || output.localizedCaseInsensitiveContains("charged")
        return BatteryStatus(percentage: percent, isCharging: charging)
    } catch {
        return BatteryStatus(percentage: nil, isCharging: true)
    }
}
