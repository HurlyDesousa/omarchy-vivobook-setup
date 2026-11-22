import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root
  property var bar: null
  property var settings: ({})
  property string moduleName: "worldClock"

  property bool popupOpen: false
  property bool editing: false
  property string searchQuery: ""
  property var searchHits: []
  property var storedCities: []
  property bool citiesLoaded: false
  property string localPlace: ""
  property string localZone: ""
  property var snapshot: ({
    homeClock: "--:--:--",
    homeDate: "",
    homeTime: "--:--",
    cities: []
  })

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy"
  readonly property string statePath: stateDir + "/world-clock.json"
  readonly property bool opened: popupOpen
  readonly property bool popoutSwitchClosing: false

  readonly property var defaultCities: [
    { id: "home", label: "Local", zone: "", short: "Local" },
    { id: "tokyo", label: "Tokyo", zone: "Asia/Tokyo", short: "TYO" },
    { id: "cape-town", label: "Cape Town", zone: "Africa/Johannesburg", short: "CPT" },
    { id: "panama", label: "Panama City", zone: "America/Panama", short: "PTY" },
    { id: "la", label: "Los Angeles", zone: "America/Los_Angeles", short: "LAX" }
  ]

  readonly property var cityCatalog: [
    { label: "Tokyo", zone: "Asia/Tokyo", short: "TYO" },
    { label: "Cape Town", zone: "Africa/Johannesburg", short: "CPT" },
    { label: "Panama City", zone: "America/Panama", short: "PTY" },
    { label: "Los Angeles", zone: "America/Los_Angeles", short: "LAX" },
    { label: "New York", zone: "America/New_York", short: "NYC" },
    { label: "Chicago", zone: "America/Chicago", short: "CHI" },
    { label: "Denver", zone: "America/Denver", short: "DEN" },
    { label: "Toronto", zone: "America/Toronto", short: "YYZ" },
    { label: "Mexico City", zone: "America/Mexico_City", short: "MEX" },
    { label: "São Paulo", zone: "America/Sao_Paulo", short: "SAO" },
    { label: "Buenos Aires", zone: "America/Argentina/Buenos_Aires", short: "BUE" },
    { label: "London", zone: "Europe/London", short: "LON" },
    { label: "Dublin", zone: "Europe/Dublin", short: "DUB" },
    { label: "Paris", zone: "Europe/Paris", short: "PAR" },
    { label: "Berlin", zone: "Europe/Berlin", short: "BER" },
    { label: "Amsterdam", zone: "Europe/Amsterdam", short: "AMS" },
    { label: "Madrid", zone: "Europe/Madrid", short: "MAD" },
    { label: "Rome", zone: "Europe/Rome", short: "ROM" },
    { label: "Zurich", zone: "Europe/Zurich", short: "ZRH" },
    { label: "Stockholm", zone: "Europe/Stockholm", short: "STO" },
    { label: "Moscow", zone: "Europe/Moscow", short: "MOW" },
    { label: "Istanbul", zone: "Europe/Istanbul", short: "IST" },
    { label: "Dubai", zone: "Asia/Dubai", short: "DXB" },
    { label: "Mumbai", zone: "Asia/Kolkata", short: "BOM" },
    { label: "Singapore", zone: "Asia/Singapore", short: "SIN" },
    { label: "Hong Kong", zone: "Asia/Hong_Kong", short: "HKG" },
    { label: "Shanghai", zone: "Asia/Shanghai", short: "SHA" },
    { label: "Seoul", zone: "Asia/Seoul", short: "SEL" },
    { label: "Bangkok", zone: "Asia/Bangkok", short: "BKK" },
    { label: "Jakarta", zone: "Asia/Jakarta", short: "JKT" },
    { label: "Sydney", zone: "Australia/Sydney", short: "SYD" },
    { label: "Melbourne", zone: "Australia/Melbourne", short: "MEL" },
    { label: "Auckland", zone: "Pacific/Auckland", short: "AKL" },
    { label: "Honolulu", zone: "Pacific/Honolulu", short: "HNL" },
    { label: "Anchorage", zone: "America/Anchorage", short: "ANC" },
    { label: "Cairo", zone: "Africa/Cairo", short: "CAI" },
    { label: "Lagos", zone: "Africa/Lagos", short: "LOS" },
    { label: "Nairobi", zone: "Africa/Nairobi", short: "NBO" },
    { label: "Tel Aviv", zone: "Asia/Jerusalem", short: "TLV" },
    { label: "Riyadh", zone: "Asia/Riyadh", short: "RUH" }
  ]

  readonly property var citiesConfig: {
    if (citiesLoaded && storedCities && storedCities.length)
      return storedCities
    if (settings && settings.cities && settings.cities.length)
      return settings.cities
    return defaultCities
  }

  readonly property color foreground: bar ? bar.foreground : OmColor.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : "monospace"
  readonly property int iconSize: 11
  readonly property var cities: snapshot.cities && snapshot.cities.length ? snapshot.cities : []
  readonly property string currentLocationLabel: {
    if (localPlace && localPlace.length) return localPlace
    if (localZone && localZone.indexOf("/") !== -1)
      return String(localZone.split("/").pop()).replace(/_/g, " ")
    return "Local"
  }
  readonly property var homeCity: {
    for (var i = 0; i < cities.length; i++) {
      if (cities[i] && cities[i].id === "home") {
        var c = cities[i]
        return {
          id: c.id,
          label: root.currentLocationLabel,
          zone: c.zone || root.localZone,
          short: c.short,
          time: c.time,
          offset: c.offset
        }
      }
    }
    return {
      id: "home",
      label: root.currentLocationLabel,
      zone: root.localZone,
      short: "",
      time: snapshot.homeTime || "--:--",
      offset: ""
    }
  }
  readonly property var locationCities: {
    var out = []
    for (var i = 0; i < cities.length; i++) {
      if (cities[i] && cities[i].id !== "home") out.push(cities[i])
    }
    return out
  }
  readonly property var browseCities: {
    var out = []
    for (var i = 0; i < cityCatalog.length; i++) {
      var c = cityCatalog[i]
      if (!c || hasZone(c.zone)) continue
      out.push(c)
      if (out.length >= 8) break
    }
    return out
  }
  readonly property var visibleSearchResults: {
    if (String(searchQuery || "").trim().length)
      return searchHits && searchHits.length ? searchHits : []
    return browseCities
  }

  implicitWidth: (bar && bar.vertical) ? (bar.barSize || 28) : (iconSize + 12)
  implicitHeight: bar ? bar.barSize : 26

  function open() { popupOpen = true }
  function close() {
    popupOpen = false
    editing = false
    searchQuery = ""
    searchHits = []
  }
  function toggle() { popupOpen ? close() : open() }
  function closeForPopoutSwitch() { close() }

  function refresh() {
    if (!probe.running) probe.running = true
  }

  function citiesJson() {
    return JSON.stringify(citiesConfig)
  }

  function cloneCities(list) {
    var src = list && list.length ? list : defaultCities
    var out = []
    for (var i = 0; i < src.length; i++) {
      var c = src[i]
      if (!c) continue
      out.push({
        id: String(c.id || ""),
        label: String(c.label || ""),
        zone: String(c.zone || ""),
        short: String(c.short || "")
      })
    }
    return out
  }

  function hasZone(zone) {
    var z = String(zone || "")
    if (!z.length) return false
    var list = citiesConfig
    for (var i = 0; i < list.length; i++) {
      if (list[i] && String(list[i].zone || "") === z) return true
    }
    return false
  }

  function slugify(label, zone) {
    var base = String(label || zone || "city").toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
    return base || "city"
  }

  function ensureUniqueId(id, list) {
    var base = String(id || "city")
    var candidate = base
    var n = 2
    while (true) {
      var taken = false
      for (var i = 0; i < list.length; i++) {
        if (list[i] && String(list[i].id) === candidate) {
          taken = true
          break
        }
      }
      if (!taken) return candidate
      candidate = base + "-" + n
      n++
    }
  }

  function persistCities(list) {
    var next = cloneCities(list)
    if (!next.length) next = cloneCities(defaultCities)
    storedCities = next
    citiesLoaded = true
    stateFile.setText(JSON.stringify({ version: 1, cities: next }, null, 2) + "\n")
    refresh()
  }

  function applyLoadedCities(raw) {
    try {
      var data = JSON.parse(String(raw || "").trim() || "{}")
      if (data && data.cities && data.cities.length) {
        storedCities = cloneCities(data.cities)
        citiesLoaded = true
        refresh()
        return
      }
    } catch (e) {
    }
    if (!citiesLoaded) {
      storedCities = cloneCities(
        (settings && settings.cities && settings.cities.length) ? settings.cities : defaultCities
      )
      citiesLoaded = true
      refresh()
    }
  }

  function locationIndexInConfig(cityId) {
    var list = citiesConfig
    for (var i = 0; i < list.length; i++) {
      if (list[i] && String(list[i].id) === String(cityId)) return i
    }
    return -1
  }

  function moveCity(cityId, delta) {
    var list = cloneCities(citiesConfig)
    var idx = locationIndexInConfig(cityId)
    if (idx < 0) return
    if (list[idx] && list[idx].id === "home") return
    var target = idx + delta
    if (target < 0 || target >= list.length) return
    if (list[target] && list[target].id === "home") return
    var tmp = list[idx]
    list[idx] = list[target]
    list[target] = tmp
    persistCities(list)
  }

  function removeCity(cityId) {
    if (String(cityId) === "home") return
    var list = []
    var src = citiesConfig
    for (var i = 0; i < src.length; i++) {
      if (!src[i] || String(src[i].id) === String(cityId)) continue
      list.push(src[i])
    }
    persistCities(list)
  }

  function addCity(entry) {
    if (!entry || !entry.zone) return
    if (hasZone(entry.zone)) return
    var list = cloneCities(citiesConfig)
    var id = ensureUniqueId(slugify(entry.label, entry.zone), list)
    list.push({
      id: id,
      label: String(entry.label || entry.zone),
      zone: String(entry.zone),
      short: String(entry.short || "")
    })
    searchQuery = ""
    searchHits = []
    if (searchField) searchField.text = ""
    persistCities(list)
  }

  function canMoveUp(cityId) {
    var idx = locationIndexInConfig(cityId)
    if (idx <= 0) return false
    var list = citiesConfig
    return !(list[idx - 1] && list[idx - 1].id === "home")
  }

  function canMoveDown(cityId) {
    var idx = locationIndexInConfig(cityId)
    var list = citiesConfig
    return idx >= 0 && idx < list.length - 1
  }

  function startEditing() {
    editing = true
    searchQuery = ""
    searchHits = []
    Qt.callLater(function() {
      if (searchField) {
        searchField.text = ""
        searchField.forceActiveFocus()
        searchField.selectAll()
      }
    })
  }

  function stopEditing() {
    editing = false
    searchQuery = ""
    searchHits = []
    if (searchField) searchField.text = ""
    if (keyCatcher) keyCatcher.forceActiveFocus()
  }

  function requestSearch(query) {
    searchQuery = String(query || "")
    searchDebounce.restart()
  }

  function runSearch() {
    var q = String(searchQuery || "").trim()
    if (!q.length) {
      searchHits = []
      return
    }
    if (!searchProc.running) searchProc.running = true
  }

  Component.onCompleted: {
    mkdirProc.running = true
    placeProc.running = true
    zoneProc.running = true
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.stateDir]
  }

  Process {
    id: placeProc
    command: ["curl", "-fsS", "--max-time", "5", "https://wttr.in/?format=%l"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw.length) return
        root.localPlace = raw.split(",")[0].trim()
      }
    }
  }

  Process {
    id: zoneProc
    command: ["timedatectl", "show", "-p", "Timezone", "--value"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw.length) root.localZone = raw
      }
    }
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyLoadedCities(text())
    onFileChanged: reload()
  }

  Process {
    id: probe
    command: [
      "python3", "-c",
      "import json,sys\n"
      + "from datetime import datetime\n"
      + "from zoneinfo import ZoneInfo\n"
      + "cities=json.loads(sys.argv[1])\n"
      + "home=datetime.now().astimezone()\n"
      + "out=[]\n"
      + "for c in cities:\n"
      + "  z=str(c.get('zone') or '').strip()\n"
      + "  dt=home if not z else home.astimezone(ZoneInfo(z))\n"
      + "  offset=''\n"
      + "  if z:\n"
      + "    delta=int((dt.utcoffset()-home.utcoffset()).total_seconds()//60)\n"
      + "    if delta:\n"
      + "      sign='+' if delta>0 else '-'\n"
      + "      ah,am=divmod(abs(delta),60)\n"
      + "      offset=f'{sign}{ah}h'\n"
      + "      if am: offset+=f'{am:02d}'\n"
      + "      hd=home.date(); od=dt.date()\n"
      + "      if od<hd: offset+=' yesterday'\n"
      + "      elif od>hd: offset+=' tomorrow'\n"
      + "  out.append({\n"
      + "    'id': c.get('id') or c.get('label') or z or 'local',\n"
      + "    'label': c.get('label') or c.get('id') or z or 'Local',\n"
      + "    'short': c.get('short') or c.get('label') or c.get('id') or '',\n"
      + "    'zone': z,\n"
      + "    'time': dt.strftime('%H:%M'),\n"
      + "    'offset': offset,\n"
      + "  })\n"
      + "print(json.dumps({\n"
      + "  'homeClock': home.strftime('%H:%M:%S'),\n"
      + "  'homeDate': home.strftime('%a, %b %-d'),\n"
      + "  'homeTime': home.strftime('%H:%M'),\n"
      + "  'cities': out,\n"
      + "}))",
      citiesJson()
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(String(text || "").trim())
          if (data && typeof data === "object") root.snapshot = data
        } catch (e) {
        }
      }
    }
  }

  Timer {
    id: searchDebounce
    interval: 180
    onTriggered: root.runSearch()
  }

  Process {
    id: searchProc
    command: [
      "python3", "-c",
      "import json,sys,re\n"
      + "from zoneinfo import available_timezones\n"
      + "q=sys.argv[1].strip().lower()\n"
      + "catalog=json.loads(sys.argv[2])\n"
      + "taken=set(json.loads(sys.argv[3]))\n"
      + "out=[]; seen=set()\n"
      + "def add(label, zone, short=''):\n"
      + "  if not zone or zone in taken or zone in seen: return\n"
      + "  seen.add(zone)\n"
      + "  out.append({'label': label, 'zone': zone, 'short': short})\n"
      + "for c in catalog:\n"
      + "  hay=(str(c.get('label',''))+' '+str(c.get('zone',''))+' '+str(c.get('short',''))).lower()\n"
      + "  if q in hay: add(c.get('label') or c.get('zone'), c.get('zone'), c.get('short') or '')\n"
      + "if len(out)<8:\n"
      + "  for z in sorted(available_timezones()):\n"
      + "    if z.startswith('Etc/'): continue\n"
      + "    city=z.split('/')[-1].replace('_',' ')\n"
      + "    hay=(z+' '+city).lower()\n"
      + "    if q in hay: add(city, z, city[:3].upper())\n"
      + "    if len(out)>=8: break\n"
      + "print(json.dumps(out))",
      String(searchQuery || "").trim(),
      JSON.stringify(cityCatalog),
      JSON.stringify((function() {
        var zones = []
        var list = citiesConfig
        for (var i = 0; i < list.length; i++) {
          if (list[i] && list[i].zone) zones.push(String(list[i].zone))
        }
        return zones
      })())
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(String(text || "").trim() || "[]")
          root.searchHits = Array.isArray(data) ? data : []
        } catch (e) {
          root.searchHits = []
        }
      }
    }
  }

  Timer {
    interval: root.popupOpen ? 1000 : 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 30 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: {
      if (!placeProc.running) placeProc.running = true
    }
  }

  onPopupOpenChanged: {
    if (popupOpen) root.refresh()
    else stopEditing()
  }

  Text {
    id: icon
    anchors.centerIn: parent
    text: "󰖐"
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.iconSize
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: {
      if (!root.popupOpen && root.bar)
        root.bar.showTooltip(root, "World clock")
    }
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: {
      if (root.bar) root.bar.hideTooltip(root)
      root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.popupOpen
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(root.editing ? 380 : 320))
    contentHeight: panel.fittedContentHeight(Math.min(popupColumn.implicitHeight, Style.space(520)))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editing && searchField.activeFocus
      onCloseRequested: root.close()

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: popupColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: popupColumn
          width: scroll.width
          spacing: Style.space(10)

          Row {
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width - editBtn.width - parent.spacing
              anchors.verticalCenter: parent.verticalCenter
              text: "World Clock"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Button {
              id: editBtn
              anchors.verticalCenter: parent.verticalCenter
              text: root.editing ? "Done" : "Edit"
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(4)
              bordered: true
              onClicked: root.editing ? root.stopEditing() : root.startEditing()
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(2)
            visible: !root.editing

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.snapshot.homeClock || "--:--:--"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: 28
              font.bold: true
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.snapshot.homeDate || ""
              color: Qt.darker(root.foreground, 1.35)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Rectangle {
            width: popupColumn.width
            height: homeRow.implicitHeight + Style.space(12)
            radius: Style.space(8)
            color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)

            Row {
              id: homeRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)

              Column {
                width: parent.width - homeTime.width - Style.space(12)
                spacing: 2

                Text {
                  text: root.homeCity.label
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  visible: !!(root.localZone && root.localZone.length)
                  text: root.localZone
                  color: Qt.darker(root.foreground, 1.45)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                }
              }

              Text {
                id: homeTime
                anchors.verticalCenter: parent.verticalCenter
                text: root.homeCity.time || "--:--"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 18
                font.bold: true
              }
            }
          }

          Text {
            visible: root.locationCities.length > 0 || root.editing
            text: "Locations"
            color: Qt.darker(root.foreground, 1.45)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Repeater {
            model: root.locationCities

            delegate: Rectangle {
              required property var modelData
              width: popupColumn.width
              height: row.implicitHeight + Style.space(12)
              radius: Style.space(8)
              color: Qt.rgba(1, 1, 1, 0.04)
              border.width: 1
              border.color: Qt.rgba(1, 1, 1, 0.06)

              Row {
                id: row
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                spacing: Style.space(6)

                Column {
                  width: {
                    var controls = root.editing ? (editControls.width + Style.space(6)) : 0
                    return parent.width - timeLabel.width - controls - Style.space(12)
                  }
                  spacing: 2

                  Text {
                    text: modelData.label || modelData.id
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                    width: parent.width
                  }

                  Text {
                    visible: !!(modelData.offset && String(modelData.offset).length)
                    text: modelData.offset || ""
                    color: Qt.darker(root.foreground, 1.45)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Row {
                  id: editControls
                  visible: root.editing
                  spacing: 2
                  anchors.verticalCenter: parent.verticalCenter

                  Button {
                    text: "↑"
                    enabled: root.canMoveUp(modelData.id)
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(6)
                    verticalPadding: Style.space(2)
                    bordered: true
                    opacity: enabled ? 1 : 0.35
                    onClicked: root.moveCity(modelData.id, -1)
                  }

                  Button {
                    text: "↓"
                    enabled: root.canMoveDown(modelData.id)
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(6)
                    verticalPadding: Style.space(2)
                    bordered: true
                    opacity: enabled ? 1 : 0.35
                    onClicked: root.moveCity(modelData.id, 1)
                  }

                  Button {
                    text: "×"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(6)
                    verticalPadding: Style.space(2)
                    bordered: true
                    onClicked: root.removeCity(modelData.id)
                  }
                }

                Text {
                  id: timeLabel
                  anchors.verticalCenter: parent.verticalCenter
                  visible: !root.editing
                  text: modelData.time || "--:--"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: 18
                  font.bold: true
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: root.editing

            TextField {
              id: searchField
              width: parent.width
              foreground: root.foreground
              placeholderText: "Search city or timezone…"
              onTextChanged: root.requestSearch(text)
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  if (text.length) {
                    text = ""
                    root.requestSearch("")
                  } else {
                    root.stopEditing()
                  }
                  event.accepted = true
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                           && root.visibleSearchResults.length > 0) {
                  root.addCity(root.visibleSearchResults[0])
                  event.accepted = true
                }
              }
            }

            Text {
              visible: String(root.searchQuery || "").trim().length === 0
              text: "Suggestions"
              color: Qt.darker(root.foreground, 1.45)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Repeater {
              model: root.visibleSearchResults

              delegate: Rectangle {
                required property var modelData
                width: popupColumn.width
                height: addRow.implicitHeight + Style.space(10)
                radius: Style.space(8)
                color: addArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                Row {
                  id: addRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(12)
                  anchors.rightMargin: Style.space(12)

                  Column {
                    width: parent.width - addLabel.width - Style.space(8)
                    spacing: 2

                    Text {
                      text: modelData.label
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    Text {
                      text: modelData.zone
                      color: Qt.darker(root.foreground, 1.45)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      width: parent.width
                    }
                  }

                  Text {
                    id: addLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }

                MouseArea {
                  id: addArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.addCity(modelData)
                }
              }
            }

            Text {
              visible: String(root.searchQuery || "").trim().length > 0 && root.visibleSearchResults.length === 0
              text: searchProc.running ? "Searching…" : "No matching cities"
              color: Qt.darker(root.foreground, 1.45)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
