import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var tab: PanelTab = .automation
    @State private var showingHelp = false
    @State private var themeFadeOverlay: AppTheme?
    @State private var themeFadeOpacity = 0.0
    private let accent = Color(red: 0.098, green: 0.565, blue: 0.929)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                Divider()
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)

                VStack(spacing: 14) {
                    preferencesStrip

                    Group {
                        switch tab {
                        case .automation: automationPane
                        case .click: clickPane
                        case .options: optionsPane
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                footer
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            }

            if showingHelp {
                helpOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
            }
        }
        .frame(width: 430, height: 610)
        .background(panelBackground(for: model.config.theme))
        .overlay {
            if let themeFadeOverlay {
                panelBackground(for: themeFadeOverlay)
                    .opacity(themeFadeOpacity)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
        .tint(accent)
        .focusEffectDisabled()
        .preferredColorScheme(preferredColorScheme)
        .onAppear { model.applyTheme() }
        .onChange(of: model.config.theme) { _, _ in model.applyTheme() }
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: showingHelp)
        .animation(.easeInOut(duration: 0.22), value: model.config.theme)
    }

    private var header: some View {
        HStack {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("CursorFlow")
                    .font(.system(size: 21, weight: .bold))
                statusPill(appActive ? t("active") : t("idle"), active: appActive)
            }
            Spacer()
            HStack(spacing: 12) {
                headerIconButton(themeIconName, help: t("theme")) {
                    toggleTheme()
                }
                headerIconButton("questionmark.circle", help: t("help")) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        showingHelp = true
                    }
                }
                headerIconButton("power", help: t("quit")) {
                    NSApp.terminate(nil)
                }
            }
        }
        .foregroundStyle(Color.primary.opacity(0.88))
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    private var preferencesStrip: some View {
        HStack(spacing: 10) {
            tabStrip
            Spacer()
            HStack(spacing: 0) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        model.config.language = language
                    } label: {
                        Text(languageShortLabel(language))
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(model.config.language == language ? accent : Color.clear)
                                    .animation(.easeInOut(duration: 0.24), value: model.config.language)
                            )
                            .foregroundStyle(model.config.language == language ? .white : Color.primary.opacity(0.82))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)

                    if language != AppLanguage.allCases.last {
                        Rectangle()
                            .fill(Color.primary.opacity(0.10))
                            .frame(width: 1, height: 16)
                            .padding(.horizontal, 2)
                    }
                }
            }
            .padding(3)
            .frame(width: 112, height: 36)
            .glassBackground(cornerRadius: 9, opacity: 0.36)
        }
    }

    private var tabStrip: some View {
        HStack(spacing: 6) {
            tabButton(.automation, icon: "bolt")
            tabButton(.click, icon: "cursorarrow")
            tabButton(.options, icon: "gearshape")
        }
        .padding(3)
        .frame(width: 260, height: 36)
        .glassBackground(cornerRadius: 9, opacity: 0.34)
    }

    private func tabButton(_ item: PanelTab, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                tab = item
            }
        } label: {
            HStack(spacing: tab == item ? 6 : 0) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                    if tab != item, tabStatusActive(item) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5.5, height: 5.5)
                            .offset(x: 5, y: -4)
                    }
                }
                if tab == item {
                    Text(tabTitle(item))
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
                .font(.system(size: 13, weight: .semibold))
                .frame(width: tab == item ? 156 : 42)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tab == item ? accent.opacity(0.12) : Color.clear)
                        .animation(.easeInOut(duration: 0.24), value: tab)
                )
                .foregroundStyle(tabForeground(item))
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private var automationPane: some View {
        VStack(spacing: 12) {
            section {
                HStack {
                    Label(t("movement"), systemImage: "cursorarrow")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.primary.opacity(0.90))
                    Spacer()
                    Toggle("", isOn: $model.movementEnabled).labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: accent))
                        .focusable(false)
                }

                HStack {
                    Label(t("behavior"), systemImage: "brain")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(behaviorStateText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(t("autoMovementNote"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(t("startAfter"))
                        Spacer()
                        Text("\(Int(model.config.startAfter)) \(t("sec"))")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: binding(\.startAfter), in: 0...60, step: 1)
                        .tint(accent)
                        .focusable(false)
                }

            }

            section {
                HStack {
                    Label(t("timer"), systemImage: "timer")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.primary.opacity(0.90))
                    Spacer()
                    Text(timerText)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12, design: .monospaced))
                    Toggle("", isOn: timerEnabledBinding).labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: accent))
                        .focusable(false)
                }

                HStack {
                    Spacer()
                    Stepper("\(model.config.timerHours)h", value: timerHoursBinding, in: 0...12)
                        .focusable(false)
                    Stepper("\(model.config.timerMinutes)m", value: timerMinutesBinding, in: 0...59)
                        .focusable(false)
                }
            }
        }
    }

    private var clickPane: some View {
        VStack(spacing: 12) {
            section {
                HStack {
                    Label(t("click"), systemImage: "cursorarrow.click.2")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.primary.opacity(0.90))
                    Spacer()
                    Toggle("", isOn: clickToggleBinding).labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: accent))
                        .focusable(false)
                }

                HStack {
                    Text(t("button"))
                    Spacer()
                    mouseButtonControl
                }

                HStack {
                    Text(t("interval"))
                    Spacer()
                    TextField("1000", value: clickIntervalMilliseconds, format: .number)
                        .frame(width: 82)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .focusEffectDisabled()
                    Text("ms")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(t("position"))
                    Spacer()
                    Text(positionText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Button(model.isCapturingPosition ? t("waiting") : t("set")) {
                        model.setClickPosition()
                    }
                    .buttonStyle(.plain)
                    .glassControl(cornerRadius: 8)
                    .focusable(false)
                    Button(t("clear")) { model.clearClickPosition() }
                        .disabled(model.config.clickPosition == nil)
                        .buttonStyle(.plain)
                        .glassControl(cornerRadius: 8)
                        .focusable(false)
                }
            }

            section {
                HStack {
                    Text(t("clicks"))
                    Spacer()
                    Text("\(model.clickCount)")
                        .font(.system(size: 13, design: .monospaced))
                    Button(t("reset")) { model.resetClickCount() }
                        .buttonStyle(.plain)
                        .glassControl(cornerRadius: 8)
                        .focusable(false)
                }

                HStack {
                    Text(t("accessibility"))
                    Spacer()
                    Circle()
                        .fill(model.accessibilityGranted ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(model.accessibilityGranted ? t("granted") : t("required"))
                        .foregroundStyle(.secondary)
                    if !model.accessibilityGranted {
                        Button(t("grant")) { model.requestAccessibility() }
                            .buttonStyle(.plain)
                            .glassControl(cornerRadius: 8)
                            .focusable(false)
                    }
                }
            }
        }
    }

    private var optionsPane: some View {
        VStack(spacing: 12) {
            section {
                HStack {
                    Label(t("keepAwake"), systemImage: "cup.and.saucer.fill")
                    Spacer()
                    Toggle("", isOn: binding(\.keepAwakeEnabled)).labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: accent))
                        .focusable(false)
                }

                HStack {
                    Toggle(t("schedule"), isOn: scheduleEnabledBinding)
                        .focusable(false)
                    Spacer()
                    Text(scheduleStatusText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                scheduleTimeRow(
                    label: t("from"),
                    hour: scheduleStartHourBinding,
                    minute: scheduleStartMinuteBinding,
                    valueText: "\(twoDigits(model.config.scheduleStartHour)):\(twoDigits(model.config.scheduleStartMinute))"
                )

                scheduleTimeRow(
                    label: t("to"),
                    hour: scheduleEndHourBinding,
                    minute: scheduleEndMinuteBinding,
                    valueText: "\(twoDigits(model.config.scheduleEndHour)):\(twoDigits(model.config.scheduleEndMinute))"
                )

                Toggle(t("batteryProtection"), isOn: binding(\.batteryProtectionEnabled))
                    .focusable(false)

                HStack {
                    Text(t("batteryThreshold"))
                    Spacer()
                    Stepper("\(model.config.batteryThreshold)%", value: binding(\.batteryThreshold), in: 1...100)
                        .focusable(false)
                }

                HStack {
                    Text(t("battery"))
                    Spacer()
                    Text(batteryText)
                        .foregroundStyle(.secondary)
                }
            }

        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text(t("footer"))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 4) {
                Text("v1.0.0 ·")
                Button("WooZH") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/WooZH")!)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary.opacity(0.78))
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var helpOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                        showingHelp = false
                    }
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(t("helpTitle"), systemImage: "questionmark.circle")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                            showingHelp = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
                VStack(alignment: .leading, spacing: 10) {
                    helpSection(icon: "cursorarrow", title: t("helpMovementTitle"), body: t("helpMovementBody"))
                    helpSection(icon: "cursorarrow.click.2", title: t("helpClickTitle"), body: t("helpClickBody"))
                    helpSection(icon: "timer", title: t("helpTimerTitle"), body: t("helpTimerBody"))
                    helpSection(icon: "hand.raised", title: t("helpManualTitle"), body: t("helpManualBody"))
                }
            }
            .padding(18)
            .frame(width: 340)
            .glassBackground(cornerRadius: 16, opacity: 0.94)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.20), radius: 22, y: 10)
        }
    }

    private func panelBackground(for theme: AppTheme) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(themeBaseColor(theme).opacity(0.94))
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(themeTintColor(theme).opacity(0.10))
        }
    }

    private func themeBaseColor(_ theme: AppTheme) -> Color {
        switch resolvedTheme(theme) {
        case .dark:
            return Color(red: 0.10, green: 0.105, blue: 0.12)
        default:
            return Color(red: 0.97, green: 0.975, blue: 0.99)
        }
    }

    private func themeTintColor(_ theme: AppTheme) -> Color {
        switch resolvedTheme(theme) {
        case .dark:
            return Color(red: 0.098, green: 0.565, blue: 0.929)
        default:
            return Color.white
        }
    }

    private func helpSection(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.88))
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func section<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(18)
            .frame(maxWidth: .infinity)
            .glassBackground(cornerRadius: 14, opacity: 0.88)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    .animation(.easeInOut(duration: 0.34), value: model.config.theme)
            )
    }

    private func headerIconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .foregroundStyle(Color.primary.opacity(0.78))
        .help(help)
    }

    private var mouseButtonControl: some View {
        HStack(spacing: 0) {
            ForEach(MouseButton.allCases) { button in
                Button {
                    model.config.clickButton = button
                } label: {
                    Text(localizedButton(button))
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(model.config.clickButton == button ? accent : Color.clear)
                                .animation(.easeInOut(duration: 0.24), value: model.config.clickButton)
                        )
                        .foregroundStyle(model.config.clickButton == button ? .white : Color.primary.opacity(0.76))
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(3)
        .frame(width: 132, height: 36)
        .glassBackground(cornerRadius: 9, opacity: 0.36)
    }

    private func statusPill(_ text: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.green.opacity(0.85))
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 1))
        .foregroundStyle(Color.primary.opacity(0.74))
        .clipShape(Capsule())
    }

    private var positionText: String {
        guard let pos = model.config.clickPosition else { return t("notSet") }
        return "\(Int(pos.x)), \(Int(pos.y))"
    }

    private var batteryText: String {
        guard let percentage = model.batteryStatus.percentage else { return t("unknown") }
        return model.batteryStatus.isCharging ? "\(percentage)% · \(t("charging"))" : "\(percentage)%"
    }

    private var timerText: String {
        guard let remaining = model.timerRemaining else {
            return "\(model.config.timerHours)h \(model.config.timerMinutes)m"
        }
        let totalSeconds = max(0, Int(ceil(remaining)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    private var behaviorStateText: String {
        model.cognitiveState == "User Active" ? t("userActive") : t("auto")
    }

    private var appActive: Bool {
        model.movementEnabled || model.clickEnabled || model.config.keepAwakeEnabled || model.scheduleKeepAwakeActive
    }

    private var clickToggleBinding: Binding<Bool> {
        Binding {
            model.clickEnabled
        } set: { enabled in
            model.clickEnabled = enabled && model.config.clickPosition != nil
        }
    }

    private var clickIntervalMilliseconds: Binding<Int> {
        Binding {
            Int(model.config.clickInterval * 1000)
        } set: { value in
            model.config.clickInterval = max(1, Double(value) / 1000)
        }
    }

    private var timerEnabledBinding: Binding<Bool> {
        Binding {
            model.config.timerEnabled
        } set: { enabled in
            model.setTimerEnabled(enabled)
        }
    }

    private var timerHoursBinding: Binding<Int> {
        Binding {
            model.config.timerHours
        } set: { hours in
            model.updateTimerHours(hours)
        }
    }

    private var timerMinutesBinding: Binding<Int> {
        Binding {
            model.config.timerMinutes
        } set: { minutes in
            model.updateTimerMinutes(minutes)
        }
    }

    private var scheduleEnabledBinding: Binding<Bool> {
        Binding {
            model.config.scheduleEnabled
        } set: { enabled in
            model.setScheduleEnabled(enabled)
        }
    }

    private var scheduleStartHourBinding: Binding<Int> {
        Binding {
            model.config.scheduleStartHour
        } set: { hour in
            model.updateScheduleStartHour(hour)
        }
    }

    private var scheduleStartMinuteBinding: Binding<Int> {
        Binding {
            model.config.scheduleStartMinute
        } set: { minute in
            model.updateScheduleStartMinute(minute)
        }
    }

    private var scheduleEndHourBinding: Binding<Int> {
        Binding {
            model.config.scheduleEndHour
        } set: { hour in
            model.updateScheduleEndHour(hour)
        }
    }

    private var scheduleEndMinuteBinding: Binding<Int> {
        Binding {
            model.config.scheduleEndMinute
        } set: { minute in
            model.updateScheduleEndMinute(minute)
        }
    }

    private var scheduleStatusText: String {
        guard model.config.scheduleEnabled else { return t("off") }
        if model.scheduleKeepAwakeActive { return t("active") }
        return "\(twoDigits(model.config.scheduleStartHour)):\(twoDigits(model.config.scheduleStartMinute))-\(twoDigits(model.config.scheduleEndHour)):\(twoDigits(model.config.scheduleEndMinute))"
    }

    private var preferredColorScheme: ColorScheme? {
        switch model.config.theme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppConfig, Value>) -> Binding<Value> {
        Binding {
            model.config[keyPath: keyPath]
        } set: { value in
            model.config[keyPath: keyPath] = value
        }
    }

    private func tabTitle(_ tab: PanelTab) -> String {
        switch tab {
        case .automation: t("automationTab")
        case .click: t("clickTab")
        case .options: t("optionsTab")
        }
    }

    private func tabStatusActive(_ tab: PanelTab) -> Bool {
        switch tab {
        case .automation:
            return model.movementEnabled
        case .click:
            return model.clickEnabled
        case .options:
            return model.config.keepAwakeEnabled || model.scheduleKeepAwakeActive
        }
    }

    private func tabForeground(_ item: PanelTab) -> Color {
        if tab == item { return accent }
        if tabStatusActive(item) { return .green }
        return Color.primary.opacity(0.86)
    }

    private var themeIconName: String {
        model.config.theme == .dark ? "sun.max" : "moon"
    }

    private func toggleTheme() {
        let previous = model.config.theme
        themeFadeOverlay = previous
        themeFadeOpacity = 1
        model.config.theme = resolvedTheme(previous) == .dark ? .light : .dark

        withAnimation(.easeInOut(duration: 0.34)) {
            themeFadeOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            themeFadeOverlay = nil
        }
    }

    private func resolvedTheme(_ theme: AppTheme) -> AppTheme {
        if theme != .system { return theme }
        let appearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return appearance == .darkAqua ? .dark : .light
    }

    private func localizedButton(_ button: MouseButton) -> String {
        button == .left ? t("left") : t("right")
    }

    private func scheduleTimeRow(label: String, hour: Binding<Int>, minute: Binding<Int>, valueText: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(valueText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
            Stepper("h", value: hour, in: 0...23)
                .labelsHidden()
                .focusable(false)
            Stepper("m", value: minute, in: 0...59, step: 5)
                .labelsHidden()
                .focusable(false)
        }
    }

    private func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    private func languageShortLabel(_ language: AppLanguage) -> String {
        switch language {
        case .english: "EN"
        case .chinese: "中"
        case .japanese: "日"
        }
    }

    private func t(_ key: String) -> String {
        L.text(key, model.config.language)
    }
}

private enum PanelTab: String, CaseIterable, Identifiable {
    case automation
    case click
    case options
    var id: String { rawValue }
}

private extension View {
    func glassBackground(cornerRadius: CGFloat, opacity: Double) -> some View {
        modifier(GlassBackgroundModifier(cornerRadius: cornerRadius, opacity: opacity))
    }

    func glassControl(cornerRadius: CGFloat) -> some View {
        modifier(GlassControlModifier(cornerRadius: cornerRadius))
    }
}

private struct GlassBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(baseColor.opacity(opacity))
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(highlightColor.opacity(0.18))
            }
            .animation(.easeInOut(duration: 0.34), value: colorScheme)
        )
    }

    private var baseColor: Color {
        colorScheme == .dark
            ? Color(red: 0.17, green: 0.17, blue: 0.20)
            : Color(red: 0.96, green: 0.965, blue: 0.98)
    }

    private var highlightColor: Color {
        colorScheme == .dark
            ? Color(red: 0.098, green: 0.565, blue: 0.929)
            : Color.white
    }
}

private struct GlassControlModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(baseColor)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.thinMaterial)
                }
                .animation(.easeInOut(duration: 0.34), value: colorScheme)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
                    .animation(.easeInOut(duration: 0.34), value: colorScheme)
            )
            .foregroundStyle(Color(red: 0.098, green: 0.565, blue: 0.929))
    }

    private var baseColor: Color {
        colorScheme == .dark
            ? Color(red: 0.20, green: 0.20, blue: 0.24).opacity(0.82)
            : Color.white.opacity(0.72)
    }

    private var strokeColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }
}

private enum L {
    static func text(_ key: String, _ language: AppLanguage) -> String {
        table[language]?[key] ?? table[.english]?[key] ?? key
    }

    private static let table: [AppLanguage: [String: String]] = [
        .english: [
            "active": "Active", "idle": "Idle", "quit": "Quit", "help": "Help", "theme": "Toggle theme",
            "automationTab": "Automation", "clickTab": "Click", "optionsTab": "Options",
            "movement": "Mouse Movement", "click": "Auto Click",
            "behavior": "Behavior", "autoMovementNote": "Uses the original CursorFlow automatic path model. Movement timing, distance, curves, pauses, and overshoot adapt to idle time.",
            "auto": "Auto", "userActive": "User active",
            "startAfter": "Start after", "sec": "sec", "button": "Button",
            "interval": "Interval", "position": "Position", "set": "Set",
            "waiting": "Waiting", "clear": "Clear", "accessibility": "Accessibility",
            "granted": "Granted", "required": "Required", "grant": "Grant",
            "clicks": "Clicks", "reset": "Reset", "notSet": "Not set",
            "system": "System", "light": "Light", "dark": "Dark",
            "left": "Left", "right": "Right", "natural": "Natural", "smart": "Smart", "subtle": "Subtle",
            "timer": "Stop after", "keepAwake": "Keep awake", "batteryProtection": "Pause on low battery",
            "schedule": "Schedule", "from": "From", "to": "To", "off": "Off",
            "batteryThreshold": "Threshold", "battery": "Battery", "charging": "charging", "unknown": "Unknown",
            "stateIdle": "Idle", "stateUserActive": "User active", "stateMicro": "Micro", "stateNavigating": "Navigating", "stateReading": "Reading", "stateThinking": "Thinking",
            "footer": "Manual movement pauses automation. Manual clicking cancels auto click.",
            "helpTitle": "CursorFlow Help",
            "helpMovementTitle": "Mouse Movement", "helpMovementBody": "Keeps the pointer active with automatic curved paths.",
            "helpClickTitle": "Auto Click", "helpClickBody": "Clicks the selected screen position on the chosen interval.",
            "helpTimerTitle": "Stop After", "helpTimerBody": "Starts a countdown and stops automation when time runs out.",
            "helpManualTitle": "Manual Control", "helpManualBody": "Manual movement pauses automation. Manual clicking cancels auto click."
        ],
        .chinese: [
            "active": "运行中", "idle": "待机", "quit": "退出", "help": "帮助", "theme": "切换主题",
            "automationTab": "自动化", "clickTab": "点击", "optionsTab": "选项",
            "movement": "鼠标移动", "click": "自动点击",
            "behavior": "行为", "autoMovementNote": "使用原 CursorFlow 自动轨迹模型，会根据闲置时间自动调整移动时机、距离、曲线、停顿和轻微越位修正。",
            "auto": "自动", "userActive": "用户活跃",
            "startAfter": "闲置后开始", "sec": "秒", "button": "按键",
            "interval": "间隔", "position": "坐标", "set": "设置",
            "waiting": "等待点击", "clear": "清除", "accessibility": "辅助功能",
            "granted": "已授权", "required": "需要授权", "grant": "授权",
            "clicks": "点击数", "reset": "重置", "notSet": "未设置",
            "system": "系统", "light": "浅色", "dark": "深色",
            "left": "左键", "right": "右键", "natural": "自然", "smart": "智能", "subtle": "轻微",
            "timer": "定时停止", "keepAwake": "保持清醒", "batteryProtection": "低电量暂停",
            "schedule": "定时保持", "from": "开始", "to": "结束", "off": "关闭",
            "batteryThreshold": "阈值", "battery": "电量", "charging": "充电中", "unknown": "未知",
            "stateIdle": "空闲", "stateUserActive": "用户活跃", "stateMicro": "微操作", "stateNavigating": "导航", "stateReading": "阅读", "stateThinking": "思考",
            "footer": "手动移动会暂停自动化；手动点击会取消自动点击。",
            "helpTitle": "CursorFlow 帮助",
            "helpMovementTitle": "鼠标移动", "helpMovementBody": "使用自动曲线路径保持指针活跃。",
            "helpClickTitle": "自动点击", "helpClickBody": "按设定间隔点击选定的屏幕坐标。",
            "helpTimerTitle": "定时停止", "helpTimerBody": "开启后启动倒计时，时间结束时停止自动化。",
            "helpManualTitle": "手动控制", "helpManualBody": "手动移动会暂停自动化；手动点击会取消自动点击。"
        ],
        .japanese: [
            "active": "稼働中", "idle": "待機中", "quit": "終了", "help": "ヘルプ", "theme": "テーマ切替",
            "automationTab": "自動化", "clickTab": "クリック", "optionsTab": "オプション",
            "movement": "マウス移動", "click": "自動クリック",
            "behavior": "動作", "autoMovementNote": "元の CursorFlow 自動パスモデルを使い、アイドル時間に応じてタイミング、距離、曲線、一時停止、補正を調整します。",
            "auto": "自動", "userActive": "ユーザー操作中",
            "startAfter": "開始まで", "sec": "秒", "button": "ボタン",
            "interval": "間隔", "position": "座標", "set": "設定",
            "waiting": "クリック待ち", "clear": "クリア", "accessibility": "アクセシビリティ",
            "granted": "許可済み", "required": "許可が必要", "grant": "許可",
            "clicks": "クリック数", "reset": "リセット", "notSet": "未設定",
            "system": "システム", "light": "ライト", "dark": "ダーク",
            "left": "左", "right": "右", "natural": "自然", "smart": "スマート", "subtle": "控えめ",
            "timer": "停止タイマー", "keepAwake": "スリープ防止", "batteryProtection": "低電力で一時停止",
            "schedule": "スケジュール", "from": "開始", "to": "終了", "off": "オフ",
            "batteryThreshold": "しきい値", "battery": "バッテリー", "charging": "充電中", "unknown": "不明",
            "stateIdle": "アイドル", "stateUserActive": "ユーザー操作中", "stateMicro": "マイクロ", "stateNavigating": "ナビゲート", "stateReading": "閲覧", "stateThinking": "思考",
            "footer": "手動移動で自動化を一時停止します。手動クリックで自動クリックを解除します。",
            "helpTitle": "CursorFlow ヘルプ",
            "helpMovementTitle": "マウス移動", "helpMovementBody": "自動の曲線パスでポインタを維持します。",
            "helpClickTitle": "自動クリック", "helpClickBody": "選択した画面座標を指定間隔でクリックします。",
            "helpTimerTitle": "停止タイマー", "helpTimerBody": "有効にするとカウントダウンし、終了時に自動化を停止します。",
            "helpManualTitle": "手動操作", "helpManualBody": "手動移動で自動化を一時停止し、手動クリックで自動クリックを解除します。"
        ]
    ]
}
