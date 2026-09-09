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
  readonly property string idleWatchBin: home + "/.local/bin/omarchy-idle-watch"
  readonly property string launchScreensaverBin: home + "/.local/bin/omarchy-launch-screensaver"
  readonly property int defaultScreensaverOnAcSeconds: 900
  readonly property int defaultScreensaverOnBatterySeconds: 300
  readonly property int defaultLockSeconds: 300
  readonly property int defaultDimSeconds: 0
  readonly property var idleConfig: shell && shell.shellConfig && shell.shellConfig.idle ? shell.shellConfig.idle : ({})
  readonly property int screensaverOnAcSeconds: secondsFromConfig(idleConfig.screensaver, defaultScreensaverOnAcSeconds)
  readonly property int screensaverOnBatterySeconds: secondsFromConfig(idleConfig.screensaverBattery, defaultScreensaverOnBatterySeconds)
  readonly property bool onBattery: UPower.onBattery
  readonly property int screensaverTimeoutSeconds: onBattery ? screensaverOnBatterySeconds : screensaverOnAcSeconds
  readonly property int lockTimeoutSeconds: secondsFromConfig(idleConfig.lock, defaultLockSeconds)
  readonly property int dimTimeoutSeconds: secondsFromConfig(idleConfig.dim, defaultDimSeconds)
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
  property bool pendingLock: false
  property double cycleStartedMs: 0
  property bool dimmedThisCycle: false
  property string lastEvent: "starting"
  property string lastEventAt: ""
  property string watchLine: ""
  property double stillSinceMs: 0
  property var screensaverWindows: ({})
  property int screensaverWindowCount: 0

  function secondsFromConfig(value, fallback) {
    return IdleModel.secondsFromConfig(value, fallback)
  }

  // Lock is not in this min: a shorter lock timeout must not skip or kill the saver.
  function visualFirstIdleTimeout() {
    if (dimTimeoutSeconds > 0 && screensaverTimeoutSeconds > 0)
      return Math.min(dimTimeoutSeconds, screensaverTimeoutSeconds)
    if (screensaverTimeoutSeconds > 0) return screensaverTimeoutSeconds
    if (dimTimeoutSeconds > 0) return dimTimeoutSeconds
    return Math.max(1, lockTimeoutSeconds)
  }

  function screensaverBlocksLock() {
    if (screensaverTimeoutSeconds <= 0) return false
    if (screensaverTimer.running) return true
    if (root.screensaverStartedThisCycle && (root.screensaverWindowCount > 0 || screensaverLaunchGraceTimer.running))
      return true
    if (root.idledThisCycle && !root.screensaverStartedThisCycle)
      return true
    return false
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

  function launchScreensaver() {
    if (root.lockAlreadyUp()) return
    root.screensaverStartedThisCycle = true
    screensaverLaunchGraceTimer.restart()
    runProcess(screensaverProcess, "screensaver", "omarchy-shell lock isLocked 2>/dev/null | grep -qx true || " + root.launchScreensaverBin)
  }

  function dimDisplay() {
    if (root.dimmedThisCycle) return
    if (root.dimTimeoutSeconds <= 0) return
    root.dimmedThisCycle = true
    runProcess(dimProcess, "dim", root.home + "/.local/bin/omarchy-idle-dim dim")
  }

  function restoreDisplay(reason) {
    dimTimer.stop()
    if (!root.dimmedThisCycle) return
    root.dimmedThisCycle = false
    logEvent("restore-dim", reason || "requested")
    runProcess(restoreProcess, "restore-dim", root.home + "/.local/bin/omarchy-idle-dim restore")
  }

  function stopScreensaver() {
    runProcess(screensaverKillProcess, "screensaver-stop", root.home + "/.local/bin/omarchy-screensaver-touchpad on >/dev/null 2>&1; pkill -x ttfx; pkill -f '[o]rg.omarchy.screensaver' || true")
  }

  function lockSystem(reason) {
    if (screensaverBlocksLock()) {
      root.pendingLock = true
      logEvent("lock-deferred", reason || "screensaver")
      return
    }

    logEvent("lock-system", reason || "requested")
    screensaverTimer.stop()
    lockTimer.stop()
    dimTimer.stop()
    screensaverLaunchGraceTimer.stop()
    idleWatch.running = false
    root.idledThisCycle = false
    root.screensaverStartedThisCycle = false
    root.pendingLock = false
    root.cycleStartedMs = 0
    resetScreensaverWindows()
    stopScreensaver()

    if (root.lockAlreadyUp()) return

    var svc = lockService()
    if (svc && typeof svc.beginLock === "function") {
      var ok = svc.beginLock(false)
      if (!ok) {
        logEvent("lock-failed", "beginLock")
        restartIdleWatch()
      }
      return
    }
    runProcess(lockProcess, "lock", "omarchy-shell lock lock >/dev/null")
  }

  function startIdleCycle() {
    if (!root.idleEnabled || root.lockAlreadyUp()) return
    if (root.idledThisCycle) {
      logEvent("idle-cycle-already-running")
      return
    }

    logEvent("idle-cycle-start", "dim=" + root.dimTimeoutSeconds + " screensaver=" + root.screensaverTimeoutSeconds + " lock=" + root.lockTimeoutSeconds)
    root.idledThisCycle = true
    root.screensaverStartedThisCycle = false
    root.pendingLock = false
    root.cycleStartedMs = Date.now()
    idleWatch.running = false
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
    screensaverLaunchGraceTimer.stop()

    restoreDisplay(reason || "idle-cycle-cancel")
    if (root.idledThisCycle) runProcess(wakeProcess, "wake", "omarchy-system-wake")
    stopScreensaver()

    root.idledThisCycle = false
    root.screensaverStartedThisCycle = false
    root.pendingLock = false
    root.cycleStartedMs = 0
    resetScreensaverWindows()
    if (root.idleEnabled && !root.lockAlreadyUp()) restartIdleWatch()
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
  }

  function handleScreensaverWindowClosed(address) {
    setScreensaverWindow(address, false)

    if (!root.idleEnabled || !root.idledThisCycle || !root.screensaverStartedThisCycle) return
    if (root.screensaverWindowCount > 0) return

    if (root.pendingLock || root.lockDeadlinePassed()) {
      root.pendingLock = false
      root.lockSystem("screensaver-dismissed")
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
    if (!root.idledThisCycle) return

    // Mapping the screensaver window can look like activity. Keep the lock
    // timer running while the real ttfx window is up.
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

  function handleWatchLine(raw) {
    var line = String(raw || "").trim()
    if (!line) return
    root.watchLine = line
    if (line === "watch-start") {
      root.stillSinceMs = Date.now()
      logEvent("idle-watch", "started timeout=" + root.firstIdleTimeoutSeconds)
      return
    }
    if (line === "active") {
      logEvent("idle-watch", "active")
      handleActiveSignal()
      return
    }
    if (line === "idle") {
      logEvent("idle-watch", "idle")
      startIdleCycle()
    }
  }

  function restartIdleWatch() {
    idleWatch.running = false
    Qt.callLater(function() {
      if (root.idleEnabled && !root.idledThisCycle && !root.lockAlreadyUp() && !idleWatch.running)
        idleWatch.running = true
    })
  }

  function statusJson() {
    return JSON.stringify({
      version: "1.8.0",
      enabled: root.idleEnabled,
      stayAwake: root.stayAwake,
      idle: idleMonitor.isIdle,
      inIdleCycle: root.idledThisCycle,
      screensaverStarted: root.screensaverStartedThisCycle,
      pendingLock: root.pendingLock,
      onBattery: root.onBattery,
      screensaver: root.screensaverTimeoutSeconds,
      firstIdle: root.firstIdleTimeoutSeconds,
      screensaverOnAc: root.screensaverOnAcSeconds,
      screensaverOnBattery: root.screensaverOnBatterySeconds,
      lock: root.lockTimeoutSeconds,
      dim: root.dimTimeoutSeconds,
      screensaverDelay: root.screensaverDelaySeconds,
      lockDelay: root.lockDelaySeconds,
      screensaverWindows: root.screensaverWindowCount,
      stillMs: root.stillSinceMs === 0 ? 0 : Math.round((Date.now() - root.stillSinceMs) / 1000),
      watch: idleWatch.running,
      watchLine: root.watchLine,
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

  onFirstIdleTimeoutSecondsChanged: if (root.idleEnabled && !root.idledThisCycle && !root.lockAlreadyUp()) restartIdleWatch()
  onIdleEnabledChanged: {
    if (root.idleEnabled && !root.idledThisCycle && !root.lockAlreadyUp()) restartIdleWatch()
    else idleWatch.running = false
  }

  IdleMonitor {
    id: idleMonitor
    enabled: root.idleEnabled
    timeout: Math.max(1, root.firstIdleTimeoutSeconds)
    respectInhibitors: false
    onIsIdleChanged: root.handleIdleChanged()
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

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.handleHyprlandEvent(event) }
  }

  Process {
    id: idleWatch
    command: [root.idleWatchBin, String(root.firstIdleTimeoutSeconds)]
    stdout: SplitParser {
      onRead: function(line) { root.handleWatchLine(line) }
    }
    stderr: SplitParser {
      onRead: function(line) { root.logEvent("idle-watch-err", line) }
    }
    onExited: function(exitCode, exitStatus) {
      root.logEvent("idle-watch-exit", "code=" + exitCode + " status=" + exitStatus)
      if (root.idleEnabled && !root.idledThisCycle && !root.lockAlreadyUp())
        Qt.callLater(function() { if (root.idleEnabled && !idleWatch.running && !root.idledThisCycle && !root.lockAlreadyUp()) idleWatch.running = true })
    }
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
    id: wakeProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "wake exitCode=" + exitCode + " status=" + exitStatus) }
  }
  Process {
    id: dimProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "dim exitCode=" + exitCode + " status=" + exitStatus) }
  }
  Process {
    id: restoreProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "restore-dim exitCode=" + exitCode + " status=" + exitStatus) }
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

  Component.onCompleted: {
    root.stillSinceMs = Date.now()
    logEvent("service-ready", "1.8.0")
    refreshStayAwakeState()
  }

  IpcHandler {
    target: "idle"
    function status(): string { return root.statusJson() }
    function debug(): string { return root.statusJson() }
    function enable(): string { return root.setIdleEnabled(true) }
    function disable(): string { return root.setIdleEnabled(false) }
    function toggle(): string { return root.setIdleEnabled(!root.idleEnabled) }
  }
}
