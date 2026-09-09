import QtQuick
import Quickshell
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
  readonly property int firstIdleTimeoutSeconds: Math.max(1, screensaverTimeoutSeconds)
  readonly property int dimDelaySeconds: dimTimeoutSeconds > 0 ? Math.max(0, dimTimeoutSeconds - firstIdleTimeoutSeconds) : -1
  readonly property bool idleEnabled: stayAwakeStateLoaded && !stayAwake

  property bool stayAwake: false
  property bool stayAwakeStateLoaded: false
  property bool hasPendingStayAwakePersist: false
  property bool pendingStayAwakePersist: false
  property bool dimmedThisCycle: false
  property bool lockingThisCycle: false
  property string lastEvent: "starting"
  property string lastEventAt: ""
  property string watchLine: ""
  property double stillSinceMs: 0

  function secondsFromConfig(value, fallback) {
    return IdleModel.secondsFromConfig(value, fallback)
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
    return !!(svc && (svc.locked || svc.lockRequested))
  }

  function dimDisplay() {
    if (root.dimmedThisCycle) return
    if (root.dimTimeoutSeconds <= 0) return
    root.dimmedThisCycle = true
    runProcess(dimProcess, "dim", root.home + "/.local/bin/omarchy-idle-dim dim")
  }

  function restoreDisplay(reason) {
    if (!root.dimmedThisCycle) return
    root.dimmedThisCycle = false
    logEvent("restore-dim", reason || "requested")
    runProcess(restoreProcess, "restore-dim", root.home + "/.local/bin/omarchy-idle-dim restore")
  }

  function lockWithScreensaver(reason) {
    if (!root.idleEnabled || root.lockAlreadyUp()) return
    if (root.lockingThisCycle) return
    root.lockingThisCycle = true
    logEvent("lock-screensaver", reason || "idle")
    dimTimer.stop()

    var svc = lockService()
    if (svc && typeof svc.beginLock === "function") {
      var ok = svc.beginLock(true)
      if (!ok) {
        root.lockingThisCycle = false
        logEvent("lock-screensaver-failed", "beginLock")
      }
      return
    }
    runProcess(lockProcess, "lock", "omarchy-shell lock lockIdle >/dev/null")
  }

  function noteUserActivity() {
    root.stillSinceMs = Date.now()
    if (root.lockAlreadyUp()) return
    root.lockingThisCycle = false
    restoreDisplay("activity")
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
      noteUserActivity()
      return
    }
    if (line === "idle") {
      logEvent("idle-watch", "idle")
      lockWithScreensaver("idle-watch")
    }
  }

  function handleIdleChanged() {
    if (idleMonitor.isIdle) {
      logEvent("idle-monitor", "idle")
      lockWithScreensaver("idle-monitor")
      return
    }
    logEvent("idle-monitor", "active")
    noteUserActivity()
  }

  function restartIdleWatch() {
    idleWatch.running = false
    Qt.callLater(function() {
      if (root.idleEnabled && !idleWatch.running) idleWatch.running = true
    })
  }

  function statusJson() {
    return JSON.stringify({
      version: "1.6.0",
      enabled: root.idleEnabled,
      stayAwake: root.stayAwake,
      idle: idleMonitor.isIdle,
      locking: root.lockingThisCycle,
      onBattery: root.onBattery,
      screensaver: root.screensaverTimeoutSeconds,
      firstIdle: root.firstIdleTimeoutSeconds,
      screensaverOnAc: root.screensaverOnAcSeconds,
      screensaverOnBattery: root.screensaverOnBatterySeconds,
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
    if (enabled) {
      root.lockingThisCycle = false
      idleWatch.running = false
      restoreDisplay("stay-awake")
    } else {
      root.stillSinceMs = Date.now()
      restartIdleWatch()
    }
    return enabled ? "disabled" : "enabled"
  }

  function setIdleEnabled(value) {
    return applyStayAwake(!value, true, "ipc")
  }

  onFirstIdleTimeoutSecondsChanged: if (root.idleEnabled) restartIdleWatch()
  onIdleEnabledChanged: {
    if (root.idleEnabled) restartIdleWatch()
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
    id: dimTimer
    interval: Math.max(0, root.dimDelaySeconds) * 1000
    repeat: false
    onTriggered: if (root.idleEnabled) root.dimDisplay()
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
      if (root.idleEnabled)
        Qt.callLater(function() { if (root.idleEnabled && !idleWatch.running) idleWatch.running = true })
    }
  }

  Process {
    id: lockProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "lock exitCode=" + exitCode + " status=" + exitStatus) }
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
    logEvent("service-ready", "1.6.0")
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
