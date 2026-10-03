.pragma library

function ipc(parts) {
  var cmd = ["omarchy-shell", "-q"]
  var list = parts || []
  for (var i = 0; i < list.length; i++)
    cmd.push(String(list[i]))
  return cmd
}

function serviceFromBar(bar, ids) {
  var sh = bar && bar.shell ? bar.shell : null
  if (!sh) return null
  var names = ids || []
  if (sh._services) {
    for (var i = 0; i < names.length; i++) {
      if (sh._services[names[i]]) return sh._services[names[i]]
    }
  }
  if (typeof sh.serviceFor === "function") {
    for (var j = 0; j < names.length; j++) {
      var own = sh.serviceFor(names[j])
      if (own) return own
    }
  }
  if (typeof sh.firstPartyServiceFor === "function") {
    for (var k = 0; k < names.length; k++) {
      var fp = sh.firstPartyServiceFor(names[k])
      if (fp) return fp
    }
  }
  return null
}
