import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import "IdleModel.js" as IdleModel

Item {
  id: root

  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string stayAwakeStateDir: home + "/.local/state/omarchy/indicators"
  readonly property string stayAwakeStatePath: stayAwakeStateDir + "/stay-awake"
  readonly property string launchScreensaverBin: "/usr/bin/omarchy-launch-screensaver"
  readonly property int defaultScreensaverOnAcSeconds: 150
  readonly property int defaultScreensaverOnBatterySeconds: 150
  readonly property int defaultLockSeconds: 300
  readonly property int defaultDimSeconds: 0
  readonly property int defaultSleepSeconds: 0
  readonly property var idleConfig: shell && shell.shellConfig && shell.shellConfig.idle
    ? shell.shellConfig.idle : (shell && shell.idleConfig ? shell.idleConfig : ({}))
  readonly property int screensaverOnAcSeconds: secondsFromConfig(idleConfig.screensaver, defaultScreensaverOnAcSeconds)
  readonly property int screensaverOnBatterySeconds: secondsFromConfig(idleConfig.screensaverBattery, defaultScreensaverOnBatterySeconds)
  readonly property bool onBattery: UPower.onBattery
  readonly property int screensaverTimeoutSeconds: onBattery ? screensaverOnBatterySeconds : screensaverOnAcSeconds
  readonly property int lockTimeoutSeconds: secondsFromConfig(idleConfig.lock, defaultLockSeconds)
  readonly property int dimTimeoutSeconds: secondsFromConfig(idleConfig.dim, defaultDimSeconds)
  // Absolute idle→suspend (0 disables). Separate from dim/lock so it still
  // fires after the session is already locked.
  readonly property int sleepTimeoutSeconds: secondsFromConfig(idleConfig.sleep, defaultSleepSeconds)
  readonly property int firstIdleTimeoutSeconds: visualFirstIdleTimeout()
  readonly property int dimDelaySeconds: dimTimeoutSeconds > 0 ? Math.max(0, dimTimeoutSeconds - firstIdleTimeoutSeconds) : -1
  readonly property int screensaverDelaySeconds: screensaverTimeoutSeconds > 0 ? Math.max(0, screensaverTimeoutSeconds - firstIdleTimeoutSeconds) : 0
  readonly property int lockDelaySeconds: Math.max(0, lockTimeoutSeconds - firstIdleTimeoutSeconds)
  readonly property bool idleEnabled: stayAwakeStateLoaded && !stayAwake
  readonly property string screensaverClass: "org.omarchy.screensaver"

  property bool stayAwake: false
  property bool stayAwakeStateLoaded: false
  property bool hasPendingStayAwakePersist: false
  property bool pendingStayAwakePersist: false
  property bool idledThisCycle: false
  property bool screensaverStartedThisCycle: false
  property bool screensaverPlayedThrough: false
  property double cycleStartedMs: 0
  property bool dimmedThisCycle: false
  property bool restoreDimPending: false
  property var boundLock: null
  property string lastEvent: "starting"
  property string lastEventAt: ""
  property double stillSinceMs: 0
  property var screensaverWindows: ({})
  property int screensaverWindowCount: 0

  function secondsFromConfig(value, fallback) {
    return IdleModel.secondsFromConfig(value, fallback)
  }

  // Dim, screensaver, and lock all count, so the idle monitor starts at the
  // earliest of them. When a screensaver is configured, the lock timer does
  // not fire on its own: the lock waits until that animation finishes.
  function visualFirstIdleTimeout() {
    var timeouts = [lockTimeoutSeconds, dimTimeoutSeconds, screensaverTimeoutSeconds]
    var first = 0
    for (var i = 0; i < timeouts.length; i++) {
      if (timeouts[i] > 0 && (first === 0 || timeouts[i] < first)) first = timeouts[i]
    }
    return Math.max(1, first)
  }

  function lockDeadlinePassed() {
    if (root.cycleStartedMs <= 0) return false
    var idleMs = root.firstIdleTimeoutSeconds * 1000 + (Date.now() - root.cycleStartedMs)
    return idleMs >= root.lockTimeoutSeconds * 1000
  }

  function nowIso() {
    return new Date().toISOString()
  }

  function logEvent(event, details) {
    var suffix = details === undefined || details === null || details === "" ? "" : ": " + String(details)
    root.lastEventAt = nowIso()
    root.lastEvent = event + suffix
    console.log("omarchy idle " + root.lastEventAt + " " + root.lastEvent)
  }

  function runProcess(process, label, command) {
    if (process.running) {
      logEvent("process-skip", label + " already running")
      return false
    }
    logEvent("process-start", label + " " + command)
    process.command = ["bash", "-lc", command]
    process.running = true
    return true
  }

  function lockService() {
    if (!root.shell) return null
    var services = root.shell._services || {}
    var id = "hurly.lock"
    if (root.shell.pluginRegistry && typeof root.shell.pluginRegistry.resolveEnabledId === "function")
      id = root.shell.pluginRegistry.resolveEnabledId("omarchy.lock") || id
    return services[id] || services["hurly.lock"] || services["omarchy.lock"] || null
  }

  function lockAlreadyUp() {
    var svc = lockService()
    return !!(svc && (svc.locked || svc.lockRequested || svc.strandedLock))
  }

  function refreshLockBinding() {
    root.boundLock = lockService()
  }

  function launchScreensaver() {
    if (root.lockAlreadyUp()) return
    root.screensaverPlayedThrough = false
    root.screensaverStartedThisCycle = true
    screensaverLaunchGraceTimer.restart()
    screensaverStartFallbackTimer.restart()
    runProcess(screensaverProcess, "screensaver", "omarchy-shell lock isLocked 2>/dev/null | grep -qx true || " + root.launchScreensaverBin)
  }

  // The animation exited on its own. Lock now; this also closes the screensaver window.
  function screensaverFinished(): string {
    if (!root.idleEnabled || !root.idledThisCycle || !root.screensaverStartedThisCycle) return "ignored"
    if (root.lockAlreadyUp()) return "locked"
    root.screensaverPlayedThrough = true
    logEvent("screensaver-played")
    root.lockSystem("screensaver-played")
    return "ok"
  }

  // A key or click dismissed the animation before it finished.
  function screensaverDismissed(): string {
    if (!root.idledThisCycle) return "ignored"
    root.screensaverPlayedThrough = false
    root.cancelIdleCycle("screensaver-dismissed")
    return "cancelled"
  }

  function dimDisplay() {
    if (root.dimmedThisCycle) return
    if (root.dimTimeoutSeconds <= 0) return
    root.dimmedThisCycle = true
    runProcess(dimProcess, "dim", root.home + "/.local/bin/omarchy-idle-dim dim")
  }

  function restoreDisplay(reason) {
    dimTimer.stop()
    var shouldRestore = root.dimmedThisCycle
    root.dimmedThisCycle = false
    if (!shouldRestore) return
    logEvent("restore-dim", reason || "requested")
    if (!runProcess(restoreProcess, "restore-dim", root.home + "/.local/bin/omarchy-idle-dim restore"))
      root.restoreDimPending = true
  }

  function stopScreensaver() {
    runProcess(screensaverKillProcess, "screensaver-stop", root.home + "/.local/bin/omarchy-screensaver-touchpad on >/dev/null 2>&1; pkill -x ttfx; pkill -f '[o]rg.omarchy.screensaver' || true")
  }

  // A finished screensaver locks from screensaverFinished(). Until then the
  // animation stays up and covers the desktop.
  function abandonForLock(reason) {
    logEvent("idle-abandon-for-lock", reason || "lock")
    screensaverTimer.stop()
    lockTimer.stop()
    dimTimer.stop()
    screensaverLaunchGraceTimer.stop()
    restoreDisplay(reason || "lock")
    root.idledThisCycle = false
    root.screensaverStartedThisCycle = false
    root.screensaverPlayedThrough = false
    root.cycleStartedMs = 0
    screensaverStartFallbackTimer.stop()
    resetScreensaverWindows()
  }

  function lockSystem(reason) {
    logEvent("lock-system", reason || "requested")
    screensaverTimer.stop()
    lockTimer.stop()
    dimTimer.stop()
    screensaverLaunchGraceTimer.stop()
    screensaverStartFallbackTimer.stop()
    restoreDisplay(reason || "lock")
    root.idledThisCycle = false
    root.screensaverStartedThisCycle = false
    root.screensaverPlayedThrough = false
    root.cycleStartedMs = 0
    resetScreensaverWindows()

    if (root.lockAlreadyUp()) return

    var svc = lockService()
    if (svc && typeof svc.beginLock === "function") {
      var ok = svc.beginLock(false)
      if (!ok) logEvent("lock-failed", "beginLock")
      return
    }
    runProcess(lockProcess, "lock", "omarchy-shell lock lock >/dev/null")
  }

  function sleepSystem(reason) {
    if (!root.idleEnabled || root.sleepTimeoutSeconds <= 0) return
    // Seat must still be idle; a second IdleMonitor was removed because two
    // ext-idle-notify registrations starved screensaver idle detection.
    if (!idleMonitor.isIdle) return
    logEvent("sleep-system", reason || "idle-sleep-timeout")
    // Always lock before sleep; lid-close and PrepareForSleep share this rule.
    // Check logind CanSuspend first so a leftover block inhibitor (e.g. a
    // stuck omarchy-update) surfaces a clear notice instead of a silent fail.
    var sleepLock = root.home + "/.local/bin/omarchy-system-sleep-lock"
    runProcess(
      sleepProcess,
      "sleep",
      "set -euo pipefail; "
        + "can=$(busctl call org.freedesktop.login1 /org/freedesktop/login1 "
        + "org.freedesktop.login1.Manager CanSuspend 2>/dev/null || true); "
        + "case \"$can\" in *na*|*no*) "
        + "omarchy-notification-send -u critical -g '󰒲' 'Idle sleep blocked' "
        + "'Suspend is disabled on this machine.' >/dev/null 2>&1 || true; exit 1;; "
        + "*inhibited*) "
        + "omarchy-notification-send -u critical -g '󰒲' 'Idle sleep blocked' "
        + "'Something is blocking suspend (often a stuck omarchy-update inhibit).' "
        + ">/dev/null 2>&1 || true; exit 1;; esac; "
        + "omarchy-shell lock lock >/dev/null 2>&1 || true; "
        + "if [[ -x '" + sleepLock + "' ]]; then timeout 30s '" + sleepLock + "' 25000 >/dev/null 2>&1 || true; "
        + "else timeout 20s omarchy-system-sleep-lock >/dev/null 2>&1 || true; fi; "
        + "if ! systemctl suspend; then "
        + "omarchy-notification-send -u critical -g '󰒲' 'Idle sleep failed' "
        + "'systemctl suspend was denied.' >/dev/null 2>&1 || true; exit 1; fi"
    )
  }

  // Arm after the shared IdleMonitor fires. Remaining time is sleepTimeout
  // minus firstIdle (already waited). Survives lock; cancelled on activity.
  function armSleepTimer() {
    sleepTimer.stop()
    if (!root.idleEnabled || root.sleepTimeoutSeconds <= 0) return
    var remaining = root.sleepTimeoutSeconds - root.firstIdleTimeoutSeconds
    if (remaining <= 0) {
      Qt.callLater(function() { root.sleepSystem("idle-sleep-timeout") })
      return
    }
    sleepTimer.interval = remaining * 1000
    sleepTimer.restart()
    logEvent("sleep-timer-armed", remaining + "s")
  }

  function startIdleCycle() {
    if (!root.idleEnabled) return

    // Sleep is independent of dim/lock UI; arm even if already locked.
    armSleepTimer()

    if (root.lockAlreadyUp()) return
    if (root.idledThisCycle) {
      logEvent("idle-cycle-already-running")
      return
    }

    logEvent("idle-cycle-start", "dim=" + root.dimTimeoutSeconds + " screensaver=" + root.screensaverTimeoutSeconds + " lock=" + root.lockTimeoutSeconds + " sleep=" + root.sleepTimeoutSeconds)
    root.idledThisCycle = true
    root.screensaverStartedThisCycle = false
    root.screensaverPlayedThrough = false
    root.cycleStartedMs = Date.now()
    resetScreensaverWindows()

    if (root.dimTimeoutSeconds > 0) {
      if (root.dimDelaySeconds === 0) dimDisplay()
      else dimTimer.restart()
    }

    if (root.screensaverDelaySeconds === 0) launchScreensaver()
    else screensaverTimer.restart()

    if (root.lockDelaySeconds === 0) lockSystem("lock-timeout-immediate")
    else lockTimer.restart()
  }

  function cancelIdleCycle(reason) {
    logEvent("idle-cycle-cancel", reason || "requested")
    screensaverTimer.stop()
    lockTimer.stop()
    dimTimer.stop()
    sleepTimer.stop()
    screensaverLaunchGraceTimer.stop()
    screensaverStartFallbackTimer.stop()

    restoreDisplay(reason || "idle-cycle-cancel")
    if (root.idledThisCycle) runProcess(wakeProcess, "wake", "omarchy-system-wake")
    stopScreensaver()

    root.idledThisCycle = false
    root.screensaverStartedThisCycle = false
    root.screensaverPlayedThrough = false
    root.cycleStartedMs = 0
    resetScreensaverWindows()
  }

  function resetScreensaverWindows() {
    root.screensaverWindows = ({})
    root.screensaverWindowCount = 0
  }

  function setScreensaverWindow(address, visible) {
    var next = IdleModel.screensaverWindowsAfter(root.screensaverWindows, address, visible)
    root.screensaverWindows = next.windows
    root.screensaverWindowCount = next.count
  }

  function handleScreensaverWindowOpened(address) {
    setScreensaverWindow(address, true)
    screensaverLaunchGraceTimer.stop()
    screensaverStartFallbackTimer.stop()
  }

  function handleScreensaverWindowClosed(address) {
    setScreensaverWindow(address, false)

    if (!root.idleEnabled || !root.idledThisCycle || !root.screensaverStartedThisCycle) return
    if (root.screensaverWindowCount > 0) return

    restoreDisplay("screensaver-dismissed")

    if (root.lockAlreadyUp()) {
      root.abandonForLock("screensaver-closed-while-locked")
      return
    }

    if (root.screensaverPlayedThrough) {
      root.lockSystem("screensaver-played")
      return
    }
    root.cancelIdleCycle("screensaver-dismissed")
  }

  function eventParts(event, count) {
    return IdleModel.eventParts(event, count)
  }

  function handleHyprlandEvent(event) {
    var name = String(event && event.name ? event.name : "")
    if (name === "openwindow") {
      var open = eventParts(event, 4)
      if (String(open[2] || "") === root.screensaverClass) root.handleScreensaverWindowOpened(open[0])
    } else if (name === "closewindow") {
      var close = eventParts(event, 1)
      var address = String(close[0] || "")
      if (root.screensaverWindows[address]) root.handleScreensaverWindowClosed(address)
    }
  }

  function handleActiveSignal() {
    root.stillSinceMs = Date.now()
    restoreDisplay("activity")
    // Always drop the sleep countdown on real activity, including when the
    // dim/lock cycle already ended after lock.
    if (!(root.screensaverStartedThisCycle && (root.screensaverWindowCount > 0 || screensaverLaunchGraceTimer.running)))
      sleepTimer.stop()
    if (!root.idledThisCycle) return

    // Mapping the screensaver window can look like activity. Keep the lock
    // timer running while the real ttfx window is up, but still undim.
    if (root.screensaverStartedThisCycle && (root.screensaverWindowCount > 0 || screensaverLaunchGraceTimer.running)) {
      logEvent("idle-monitor-active", "screensaver cycle remains armed")
      return
    }

    cancelIdleCycle("activity")
  }

  function handleIdleChanged() {
    logEvent("idle-monitor", idleMonitor.isIdle ? "idle" : "active")
    if (!idleMonitor.isIdle) restoreDisplay("activity")
    if (!root.idleEnabled) return

    if (idleMonitor.isIdle) startIdleCycle()
    else handleActiveSignal()
  }

  function statusJson() {
    return JSON.stringify({
      version: "1.12.1",
      enabled: root.idleEnabled,
      stayAwake: root.stayAwake,
      idle: idleMonitor.isIdle,
      inIdleCycle: root.idledThisCycle,
      screensaverStarted: root.screensaverStartedThisCycle,
      onBattery: root.onBattery,
      screensaver: root.screensaverTimeoutSeconds,
      firstIdle: root.firstIdleTimeoutSeconds,
      screensaverOnAc: root.screensaverOnAcSeconds,
      screensaverOnBattery: root.screensaverOnBatterySeconds,
      lock: root.lockTimeoutSeconds,
      dim: root.dimTimeoutSeconds,
      sleep: root.sleepTimeoutSeconds,
      sleepArmed: !!(sleepTimer && sleepTimer.running),
      screensaverDelay: root.screensaverDelaySeconds,
      lockDelay: root.lockDelaySeconds,
      screensaverWindows: root.screensaverWindowCount,
      stillMs: root.stillSinceMs === 0 ? 0 : Math.round((Date.now() - root.stillSinceMs) / 1000),
      lastEvent: root.lastEvent,
      lastEventAt: root.lastEventAt
    })
  }

  function persistStayAwake(value) {
    var command = value
      ? "mkdir -p \"$HOME/.local/state/omarchy/indicators\" && touch \"$HOME/.local/state/omarchy/indicators/stay-awake\""
      : "rm -f \"$HOME/.local/state/omarchy/indicators/stay-awake\""
    if (stayAwakeStateWriter.running) {
      root.pendingStayAwakePersist = !!value
      root.hasPendingStayAwakePersist = true
      return
    }
    stayAwakeStateWriter.command = ["bash", "-lc", command]
    stayAwakeStateWriter.running = true
  }

  function refreshStayAwakeState() {
    if (!stayAwakeStateProbe.running) stayAwakeStateProbe.running = true
  }

  function applyStayAwake(value, persist, reason) {
    var enabled = !!value
    var changed = !root.stayAwakeStateLoaded || root.stayAwake !== enabled
    if (persist) persistStayAwake(enabled)
    root.stayAwake = enabled
    root.stayAwakeStateLoaded = true
    if (!changed) return enabled ? "disabled" : "enabled"
    logEvent("stay-awake", (enabled ? "enabled" : "disabled") + (reason ? " " + reason : ""))
    if (enabled) cancelIdleCycle("stay-awake")
    else Qt.callLater(root.handleIdleChanged)
    return enabled ? "disabled" : "enabled"
  }

  function setIdleEnabled(value) {
    return applyStayAwake(!value, true, "ipc")
  }

  // Bounce enabled when the timeout changes; otherwise ext-idle-notify keeps
  // the old notification and can sit forever in isIdle=false after a config edit.
  property bool idleMonitorGate: true
  onFirstIdleTimeoutSecondsChanged: {
    idleMonitorGate = false
    Qt.callLater(function() { root.idleMonitorGate = true })
  }

  IdleMonitor {
    id: idleMonitor
    enabled: root.idleEnabled && root.idleMonitorGate
    timeout: Math.max(1, root.firstIdleTimeoutSeconds)
    respectInhibitors: false
    onIsIdleChanged: root.handleIdleChanged()
  }

  // One IdleMonitor only. A second ext-idle-notify registration (used earlier
  // for sleep) left the seat stuck "active" so screensaver never started.
  Timer {
    id: sleepTimer
    interval: 1000
    repeat: false
    onTriggered: root.sleepSystem("idle-sleep-timeout")
  }

  Timer {
    id: screensaverTimer
    interval: root.screensaverDelaySeconds * 1000
    repeat: false
    onTriggered: root.launchScreensaver()
  }

  Timer {
    id: lockTimer
    interval: root.lockDelaySeconds * 1000
    repeat: false
    onTriggered: if (root.idleEnabled && root.idledThisCycle) root.lockSystem("lock-timeout")
  }

  Timer {
    id: dimTimer
    interval: Math.max(0, root.dimDelaySeconds) * 1000
    repeat: false
    onTriggered: if (root.idleEnabled && root.idledThisCycle) root.dimDisplay()
  }

  Timer {
    id: screensaverLaunchGraceTimer
    interval: 3000
    repeat: false
    onTriggered: {
      if (root.idleEnabled && root.idledThisCycle && root.screensaverStartedThisCycle && root.screensaverWindowCount === 0 && !idleMonitor.isIdle) {
        root.cancelIdleCycle("screensaver-not-running")
      }
    }
  }

  // If the animation never appears, lock anyway so idle does not stay unlocked.
  Timer {
    id: screensaverStartFallbackTimer
    interval: 15000
    repeat: false
    onTriggered: {
      if (!root.idleEnabled || !root.idledThisCycle || !root.screensaverStartedThisCycle) return
      if (root.screensaverWindowCount > 0 || root.lockAlreadyUp()) return
      if (!idleMonitor.isIdle) {
        root.cancelIdleCycle("screensaver-not-running")
        return
      }
      root.lockSystem("screensaver-not-running")
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.handleHyprlandEvent(event) }
  }

  Process {
    id: screensaverProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "screensaver exitCode=" + exitCode + " status=" + exitStatus) }
  }
  Process {
    id: screensaverKillProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "screensaver-stop exitCode=" + exitCode + " status=" + exitStatus) }
  }
  Process {
    id: lockProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "lock exitCode=" + exitCode + " status=" + exitStatus) }
  }
  Process {
    id: sleepProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "sleep exitCode=" + exitCode + " status=" + exitStatus) }
  }
  Process {
    id: wakeProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "wake exitCode=" + exitCode + " status=" + exitStatus) }
  }
  Process {
    id: dimProcess
    onExited: function(exitCode, exitStatus) {
      root.logEvent("process-exit", "dim exitCode=" + exitCode + " status=" + exitStatus)
      if (!root.dimmedThisCycle) {
        root.dimmedThisCycle = true
        root.restoreDisplay("dim-finished-while-active")
      }
    }
  }
  Process {
    id: restoreProcess
    onExited: function(exitCode, exitStatus) {
      root.logEvent("process-exit", "restore-dim exitCode=" + exitCode + " status=" + exitStatus)
      if (root.restoreDimPending) {
        root.restoreDimPending = false
        root.dimmedThisCycle = true
        root.restoreDisplay("restore-retry")
      }
    }
  }

  Process {
    id: stayAwakeStateProbe
    command: ["bash", "-c", "mkdir -p \"$HOME/.local/state/omarchy/indicators\"; if [[ -f $HOME/.local/state/omarchy/indicators/stay-awake ]]; then echo yes; else echo no; fi"]
    stdout: SplitParser {
      onRead: function(line) { root.applyStayAwake(String(line).trim() === "yes", false, "state-file") }
    }
    onExited: function() { stayAwakeStateDirWatcher.reload() }
  }

  Process {
    id: stayAwakeStateWriter
    onExited: function() {
      if (root.hasPendingStayAwakePersist) {
        var pending = root.pendingStayAwakePersist
        root.hasPendingStayAwakePersist = false
        root.persistStayAwake(pending)
        return
      }
      root.refreshStayAwakeState()
    }
  }

  FileView {
    id: stayAwakeStateDirWatcher
    path: root.stayAwakeStateDir
    watchChanges: true
    printErrors: false
    onFileChanged: root.refreshStayAwakeState()
  }

  Timer {
    id: lockBindTimer
    interval: 1500
    repeat: false
    running: true
    onTriggered: root.refreshLockBinding()
  }

  Connections {
    target: root.boundLock
    enabled: root.boundLock !== null
    function onLockRequestedChanged() {
      if (!root.boundLock) return
      if (root.boundLock.lockRequested) root.abandonForLock("lock-requested")
    }
  }

  Component.onCompleted: {
    root.stillSinceMs = Date.now()
    logEvent("service-ready", "1.12.1")
    refreshStayAwakeState()
    Qt.callLater(root.refreshLockBinding)
  }

  IpcHandler {
    target: "idle"
    function status(): string { return root.statusJson() }
    function debug(): string { return root.statusJson() }
    function enable(): string { return root.setIdleEnabled(true) }
    function disable(): string { return root.setIdleEnabled(false) }
    function toggle(): string { return root.setIdleEnabled(!root.idleEnabled) }
    function screensaverFinished(): string { return root.screensaverFinished() }
    function screensaverDismissed(): string { return root.screensaverDismissed() }
  }
}
