import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.loupibe.system-monitor"
  ipcTarget: "io.github.loupibe.system-monitor"

  property var stats: Model.createInitialState()
  property int refreshIntervalSec: setting("refreshIntervalSec", 2)
  property bool showCpu: setting("showCpu", true)
  property bool showGpu: setting("showGpu", false)
  property bool showMemory: setting("showMemory", true)
  property bool showDisk: setting("showDisk", false)
  property bool showNetwork: setting("showNetwork", true)
  property bool showTemp: setting("showTemp", false)
  property bool panelShowCpu: setting("panelShowCpu", true)
  property bool panelShowGpu: setting("panelShowGpu", false)
  property bool panelShowMemory: setting("panelShowMemory", true)
  property bool panelShowDisk: setting("panelShowDisk", true)
  property bool panelShowNetwork: setting("panelShowNetwork", true)
  property int cpuAlertPercent: setting("cpuAlertPercent", 85)
  property int gpuAlertPercent: setting("gpuAlertPercent", 85)
  property int memAlertPercent: setting("memAlertPercent", 85)
  property int diskAlertPercent: setting("diskAlertPercent", 90)
  property string historyStyle: setting("historyStyle", "sparkline")
  property int historyPoints: setting("historyPoints", 20)
  property bool showCpuHistory: setting("showCpuHistory", true)
  property bool showNetworkHistory: setting("showNetworkHistory", true)
  property bool showMemoryHistory: setting("showMemoryHistory", false)
  property bool showDiskHistory: setting("showDiskHistory", false)
  property bool showGpuHistory: setting("showGpuHistory", false)
  property var barOrder: setting("barOrder", ["cpu", "memory", "disk", "network"])
  property var panelOrder: setting("panelOrder", ["cpu", "memory", "storage", "network"])

  readonly property var visibleBarSlots: {
    var order = Model.parseOrder(root.barOrder, ["cpu", "memory", "disk", "network"]);
    var list = [];
    for (var i = 0; i < order.length; i++) {
      var key = order[i];
      if (key === "cpu" && root.showCpu) list.push("cpu");
      else if (key === "gpu" && root.showGpu) list.push("gpu");
      else if ((key === "memory" || key === "ram") && root.showMemory) list.push("memory");
      else if ((key === "disk" || key === "storage") && root.showDisk) list.push("disk");
      else if ((key === "network" || key === "net") && root.showNetwork) list.push("network");
      else if ((key === "rx" || key === "download") && root.showNetwork) list.push("rx");
      else if ((key === "tx" || key === "upload") && root.showNetwork) list.push("tx");
    }
    return list;
  }

  readonly property var visiblePanelSections: {
    var order = Model.parseOrder(root.panelOrder, ["cpu", "memory", "storage", "network"]);
    var list = [];
    for (var i = 0; i < order.length; i++) {
      var key = order[i];
      if (key === "cpu" && root.panelShowCpu) list.push("cpu");
      else if ((key === "memory" || key === "ram") && root.panelShowMemory) list.push("memory");
      else if ((key === "storage" || key === "disk") && root.panelShowDisk) list.push("storage");
      else if ((key === "network" || key === "net") && root.panelShowNetwork) list.push("network");
    }
    return list;
  }

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property string statsScriptPath: localPath(Qt.resolvedUrl("stats.sh"))
  readonly property color barForeground: bar ? bar.barForeground : Color.foreground
  readonly property string barFontFamily: bar ? bar.fontFamily : Style.font.family

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.slice(7)
    return decodeURIComponent(value)
  }

  function refresh() {
    if (!statsProc.running) statsProc.running = true
  }

  function updateStats(rawText) {
    stats = Model.parseStats(rawText, stats, Date.now(), root.historyPoints)
  }

  function launchBtop() {
    if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
    root.close()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onOpenedChanged: {
    if (root.opened) {
      root.refresh()
    }
  }

  Process {
    id: statsProc
    command: [root.statsScriptPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateStats(text)
    }
  }

  Timer {
    id: procWatchdog
    interval: 2000
    repeat: false
    running: statsProc.running
    onTriggered: {
      if (statsProc.running) {
        statsProc.running = false
      }
    }
  }

  Timer {
    interval: (root.bar && root.bar.screenLocked) ? 10000 : Math.max(1000, root.refreshIntervalSec * 1000)
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // --- Slot Components for Bar Pill ---
  Component {
    id: cpuSlotComponent
    Row {
      spacing: Style.space(3)
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      Text {
        width: root.showTemp && root.stats.cpuTemp ? Style.space(68) : Style.space(34)
        horizontalAlignment: Text.AlignRight
        text: root.stats.cpuPercent + "%" + (root.showTemp && root.stats.cpuTemp ? " " + root.stats.cpuTemp : "")
        textFormat: Text.PlainText
        color: root.stats.cpuPercent >= root.cpuAlertPercent ? Color.urgent : (root.stats.cpuPercent >= 65 ? Color.accent : root.barForeground)
        font.family: root.barFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: ""
        textFormat: Text.PlainText
        color: root.stats.cpuPercent >= root.cpuAlertPercent ? Color.urgent : (root.stats.cpuPercent >= 65 ? Color.accent : root.barForeground)
        font.family: root.barFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Component {
    id: gpuSlotComponent
    Row {
      spacing: Style.space(3)
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      Text {
        width: Style.space(34)
        horizontalAlignment: Text.AlignRight
        text: root.stats.gpuPercent + "%"
        textFormat: Text.PlainText
        color: root.stats.gpuPercent >= root.gpuAlertPercent ? Color.urgent : (root.stats.gpuPercent >= 65 ? Color.accent : root.barForeground)
        font.family: root.barFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: "󰢮"
        textFormat: Text.PlainText
        color: root.stats.gpuPercent >= root.gpuAlertPercent ? Color.urgent : (root.stats.gpuPercent >= 65 ? Color.accent : root.barForeground)
        font.family: root.barFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Component {
    id: memSlotComponent
    Row {
      spacing: Style.space(3)
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      Text {
        width: Style.space(34)
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.stats.memPercent) + "%"
        textFormat: Text.PlainText
        color: root.stats.memPercent >= root.memAlertPercent ? Color.urgent : (root.stats.memPercent >= 70 ? Color.accent : root.barForeground)
        font.family: root.barFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: "󰍛"
        textFormat: Text.PlainText
        color: root.stats.memPercent >= root.memAlertPercent ? Color.urgent : (root.stats.memPercent >= 70 ? Color.accent : root.barForeground)
        font.family: root.barFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Component {
    id: diskSlotComponent
    Row {
      spacing: Style.space(3)
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      Text {
        width: Style.space(76)
        horizontalAlignment: Text.AlignRight
        text: root.stats.diskPercent + "% (" + Model.formatKbCompact(root.stats.diskAvailKb) + ")"
        textFormat: Text.PlainText
        color: root.stats.diskPercent >= root.diskAlertPercent ? Color.urgent : root.barForeground
        font.family: root.barFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: "󰋊"
        textFormat: Text.PlainText
        color: root.stats.diskPercent >= root.diskAlertPercent ? Color.urgent : root.barForeground
        font.family: root.barFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Component {
    id: netSlotComponent
    Row {
      spacing: Style.space(10)
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      Loader { sourceComponent: dlSlotComponent; anchors.verticalCenter: parent.verticalCenter }
      Loader { sourceComponent: ulSlotComponent; anchors.verticalCenter: parent.verticalCenter }
    }
  }

  Component {
    id: dlSlotComponent
    Row {
      spacing: Style.space(3)
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      Text {
        width: Style.space(76)
        horizontalAlignment: Text.AlignRight
        text: Model.formatSpeed(root.stats.rxSpeed)
        textFormat: Text.PlainText
        color: root.barForeground
        font.family: root.barFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: "󰇚"
        textFormat: Text.PlainText
        color: root.barForeground
        font.family: root.barFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Component {
    id: ulSlotComponent
    Row {
      spacing: Style.space(3)
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      Text {
        width: Style.space(76)
        horizontalAlignment: Text.AlignRight
        text: Model.formatSpeed(root.stats.txSpeed)
        textFormat: Text.PlainText
        color: root.barForeground
        font.family: root.barFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: "󰕒"
        textFormat: Text.PlainText
        color: root.barForeground
        font.family: root.barFontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // --- Vertical Bar Components ---
  Component {
    id: verticalCpuComponent
    Text {
      text: " " + root.stats.cpuPercent + "%" + (root.showTemp && root.stats.cpuTemp ? " " + root.stats.cpuTemp : "")
      textFormat: Text.PlainText
      color: root.stats.cpuPercent >= root.cpuAlertPercent ? Color.urgent : root.barForeground
      font.family: root.barFontFamily
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering
    }
  }

  Component {
    id: verticalGpuComponent
    Text {
      text: "󰢮 " + root.stats.gpuPercent + "%"
      textFormat: Text.PlainText
      color: root.stats.gpuPercent >= root.gpuAlertPercent ? Color.urgent : root.barForeground
      font.family: root.barFontFamily
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering
    }
  }

  Component {
    id: verticalMemComponent
    Text {
      text: "󰍛 " + Math.round(root.stats.memPercent) + "%"
      textFormat: Text.PlainText
      color: root.stats.memPercent >= root.memAlertPercent ? Color.urgent : root.barForeground
      font.family: root.barFontFamily
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering
    }
  }

  Component {
    id: verticalDiskComponent
    Text {
      text: "󰋊 " + root.stats.diskPercent + "%"
      textFormat: Text.PlainText
      color: root.stats.diskPercent >= root.diskAlertPercent ? Color.urgent : root.barForeground
      font.family: root.barFontFamily
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering
    }
  }

  // --- History Timeline Visualizer Component ---
  component HistoryView: Item {
    id: histRoot
    property var values: []
    property real minVal: 0
    property real maxVal: 100
    property color graphColor: Color.accent
    property string styleMode: root.historyStyle

    width: parent ? parent.width : Style.space(200)
    height: styleMode === "sparkline" ? sparkText.implicitHeight : (styleMode === "bars" ? Style.space(12) : Style.space(16))
    visible: values && values.length > 1

    // 1. Sparkline Style
    Text {
      id: sparkText
      visible: histRoot.styleMode === "sparkline"
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Model.generateSparkline(histRoot.values, histRoot.minVal, histRoot.maxVal)
      textFormat: Text.PlainText
      font.family: root.barFontFamily
      font.pixelSize: Style.font.bodySmall
      color: histRoot.graphColor
      elide: Text.ElideNone
      horizontalAlignment: Text.AlignRight
    }

    // 2. Micro-Bars Style
    Row {
      id: barsRow
      visible: histRoot.styleMode === "bars"
      anchors.fill: parent
      spacing: Style.space(2)

      Repeater {
        model: histRoot.values
        delegate: Item {
          required property var modelData
          required property int index
          width: Math.max(2, (barsRow.width - (histRoot.values.length - 1) * Style.space(2)) / histRoot.values.length)
          height: barsRow.height

          Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            radius: 1
            height: Math.max(2, parent.height * Math.max(0, Math.min(1, (modelData - histRoot.minVal) / Math.max(1, (histRoot.maxVal - histRoot.minVal)))))
            color: histRoot.graphColor
            opacity: 0.4 + 0.6 * (index / Math.max(1, histRoot.values.length - 1))
          }
        }
      }
    }

    // 3. Smooth Area Canvas Style
    Canvas {
      id: areaCanvas
      visible: histRoot.styleMode === "area"
      anchors.fill: parent
      onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (!histRoot.values || histRoot.values.length < 2) return;
        var step = width / (histRoot.values.length - 1);
        var range = Math.max(1, histRoot.maxVal - histRoot.minVal);

        ctx.beginPath();
        ctx.moveTo(0, height);
        for (var i = 0; i < histRoot.values.length; i++) {
          var norm = Math.max(0, Math.min(1, (histRoot.values[i] - histRoot.minVal) / range));
          var y = height - (norm * (height - 2));
          var x = i * step;
          if (i === 0) ctx.lineTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.lineTo(width, height);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(histRoot.graphColor.r, histRoot.graphColor.g, histRoot.graphColor.b, 0.25);
        ctx.fill();

        ctx.beginPath();
        for (var j = 0; j < histRoot.values.length; j++) {
          var n = Math.max(0, Math.min(1, (histRoot.values[j] - histRoot.minVal) / range));
          var py = height - (n * (height - 2));
          var px = j * step;
          if (j === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.strokeStyle = histRoot.graphColor;
        ctx.lineWidth = 1.5;
        ctx.stroke();
      }

      Connections {
        target: root
        function onStatsChanged() {
          if (areaCanvas.visible) areaCanvas.requestPaint();
        }
      }
    }
  }

  // --- Section Components for Overview Panel ---
  Component {
    id: cpuSectionComponent
    Column {
      width: parent ? parent.width : 0
      spacing: Style.space(6)

      Row {
        width: parent.width
        Text {
          text: "CPU LOAD"
          textFormat: Text.PlainText
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth); height: 1 }
        Text {
          text: root.stats.cpuPercent + "%"
          textFormat: Text.PlainText
          color: root.stats.cpuPercent >= root.cpuAlertPercent ? Color.urgent : (root.stats.cpuPercent >= 65 ? Color.accent : root.barForeground)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }
      }

      // CPU Progress Bar
      Item {
        width: parent.width
        height: Style.space(6)
        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.12)
        }
        Rectangle {
          height: parent.height
          radius: height / 2
          width: Math.max(height, parent.width * (root.stats.cpuPercent / 100))
          color: root.stats.cpuPercent >= root.cpuAlertPercent ? Color.urgent : (root.stats.cpuPercent >= 65 ? Color.accent : root.barForeground)
          Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 200 } }
        }
      }

      // CPU History Timeline
      HistoryView {
        values: root.stats.cpuHistory
        minVal: 0
        maxVal: 100
        graphColor: root.stats.cpuPercent >= root.cpuAlertPercent ? Color.urgent : (root.stats.cpuPercent >= 65 ? Color.accent : root.barForeground)
        visible: root.showCpuHistory && root.stats.cpuHistory.length > 1
      }

      // Per-Core Mini Bars
      Flow {
        width: parent.width
        spacing: Style.space(4)
        visible: root.stats.cores.length > 0

        Repeater {
          model: root.stats.cores
          delegate: Item {
            required property var modelData
            width: Math.max(Style.space(32), (parent.width - (Math.min(8, root.stats.cores.length) - 1) * Style.space(4)) / Math.min(8, root.stats.cores.length))
            height: Style.space(20)

            Column {
              anchors.fill: parent
              spacing: Style.space(2)
              Text {
                text: modelData.label + " " + modelData.percent + "%"
                textFormat: Text.PlainText
                font.pixelSize: Style.space(9)
                font.family: root.barFontFamily
                color: Qt.darker(root.barForeground, 1.3)
                elide: Text.ElideRight
                width: parent.width
              }
              Rectangle {
                width: parent.width
                height: Style.space(3)
                radius: height / 2
                color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.12)
                Rectangle {
                  height: parent.height
                  radius: height / 2
                  width: Math.max(height, parent.width * (modelData.percent / 100))
                  color: modelData.percent >= root.cpuAlertPercent ? Color.urgent : (modelData.percent >= 65 ? Color.accent : root.barForeground)
                }
              }
            }
          }
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)
        Text {
          text: "Load: " + root.stats.load1 + ", " + root.stats.load5 + ", " + root.stats.load15
          textFormat: Text.PlainText
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
        Text {
          text: root.stats.coreCount + " Cores"
          textFormat: Text.PlainText
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      // Optional GPU Section inside CPU Panel
      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.panelShowGpu

        Rectangle {
          width: parent.width
          height: 1
          color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.08)
        }

        Row {
          width: parent.width
          Text {
            text: "GPU LOAD" + (root.stats.gpuName ? " (" + root.stats.gpuName + ")" : "")
            textFormat: Text.PlainText
            color: Qt.darker(root.barForeground, 1.4)
            font.family: root.barFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
          Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth); height: 1 }
          Text {
            text: root.stats.gpuPercent + "%" + (root.stats.gpuTemp ? " · " + root.stats.gpuTemp : "")
            textFormat: Text.PlainText
            color: root.stats.gpuPercent >= root.gpuAlertPercent ? Color.urgent : (root.stats.gpuPercent >= 65 ? Color.accent : root.barForeground)
            font.family: root.barFontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
        }

        // GPU Progress Bar
        Item {
          width: parent.width
          height: Style.space(6)
          Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.12)
          }
          Rectangle {
            height: parent.height
            radius: height / 2
            width: Math.max(height, parent.width * (root.stats.gpuPercent / 100))
            color: root.stats.gpuPercent >= root.gpuAlertPercent ? Color.urgent : (root.stats.gpuPercent >= 65 ? Color.accent : root.barForeground)
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 200 } }
          }
        }

        // GPU History Timeline
        HistoryView {
          values: root.stats.gpuHistory
          minVal: 0
          maxVal: 100
          graphColor: root.stats.gpuPercent >= root.gpuAlertPercent ? Color.urgent : (root.stats.gpuPercent >= 65 ? Color.accent : root.barForeground)
          visible: root.showGpuHistory && root.stats.gpuHistory.length > 1
        }

        Row {
          width: parent.width
          visible: root.stats.gpuMemTotalMb > 0
          spacing: Style.space(8)
          Text {
            text: "VRAM: " + root.stats.gpuMemUsedMb + " MB / " + root.stats.gpuMemTotalMb + " MB"
            textFormat: Text.PlainText
            color: Qt.darker(root.barForeground, 1.4)
            font.family: root.barFontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }
    }
  }

  Component {
    id: memSectionComponent
    Column {
      width: parent ? parent.width : 0
      spacing: Style.space(6)

      Row {
        width: parent.width
        Text {
          text: "MEMORY"
          textFormat: Text.PlainText
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth); height: 1 }
        Text {
          text: Math.round(root.stats.memPercent) + "% (" + Model.formatKb(root.stats.memUsedKb) + " / " + Model.formatKb(root.stats.memTotalKb) + ")"
          textFormat: Text.PlainText
          color: root.stats.memPercent >= root.memAlertPercent ? Color.urgent : (root.stats.memPercent >= 70 ? Color.accent : root.barForeground)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }
      }

      // Memory Progress Bar
      Item {
        width: parent.width
        height: Style.space(6)
        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.12)
        }
        Rectangle {
          height: parent.height
          radius: height / 2
          width: Math.max(height, parent.width * (root.stats.memPercent / 100))
          color: root.stats.memPercent >= root.memAlertPercent ? Color.urgent : (root.stats.memPercent >= 70 ? Color.accent : root.barForeground)
          Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 200 } }
        }
      }

      // Memory History Timeline
      HistoryView {
        values: root.stats.memHistory
        minVal: 0
        maxVal: 100
        graphColor: root.stats.memPercent >= root.memAlertPercent ? Color.urgent : (root.stats.memPercent >= 70 ? Color.accent : root.barForeground)
        visible: root.showMemoryHistory && root.stats.memHistory.length > 1
      }

      Row {
        width: parent.width
        spacing: Style.space(8)
        Text {
          text: "Avail: " + Model.formatKb(root.stats.memAvailKb)
          textFormat: Text.PlainText
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
        Text {
          text: "Swap: " + Model.formatKb(root.stats.swapUsedKb) + " / " + Model.formatKb(root.stats.swapTotalKb)
          textFormat: Text.PlainText
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }

  Component {
    id: storageSectionComponent
    Column {
      width: parent ? parent.width : 0
      spacing: Style.space(6)

      Row {
        width: parent.width
        Text {
          text: "STORAGE (" + (root.stats.diskMount || "$HOME") + ")"
          textFormat: Text.PlainText
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth); height: 1 }
        Text {
          text: root.stats.diskPercent + "% (" + Model.formatKb(root.stats.diskUsedKb) + " / " + Model.formatKb(root.stats.diskTotalKb) + ")"
          textFormat: Text.PlainText
          color: root.stats.diskPercent >= root.diskAlertPercent ? Color.urgent : root.barForeground
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }
      }

      // Disk Progress Bar
      Item {
        width: parent.width
        height: Style.space(6)
        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.12)
        }
        Rectangle {
          height: parent.height
          radius: height / 2
          width: Math.max(height, parent.width * (root.stats.diskPercent / 100))
          color: root.stats.diskPercent >= root.diskAlertPercent ? Color.urgent : root.barForeground
          Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 200 } }
        }
      }

      // Storage History Timeline
      HistoryView {
        values: root.stats.diskHistory
        minVal: 0
        maxVal: 100
        graphColor: root.stats.diskPercent >= root.diskAlertPercent ? Color.urgent : root.barForeground
        visible: root.showDiskHistory && root.stats.diskHistory.length > 1
      }

      Row {
        width: parent.width
        spacing: Style.space(8)
        Text {
          text: "Free: " + Model.formatKb(root.stats.diskAvailKb)
          textFormat: Text.PlainText
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
        Text {
          text: "Used: " + Model.formatKb(root.stats.diskUsedKb)
          textFormat: Text.PlainText
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }

  Component {
    id: netSectionComponent
    Column {
      width: parent ? parent.width : 0
      spacing: Style.space(6)

      Row {
        width: parent.width
        Text {
          text: "NETWORK (" + root.stats.netIface + ")"
          textFormat: Text.PlainText
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth); height: 1 }
        Text {
          text: "Live Traffic"
          textFormat: Text.PlainText
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.barFontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(12)

        // Download
        Item {
          width: (parent.width - parent.spacing) / 2
          height: dlCol.implicitHeight
          Column {
            id: dlCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.space(2)
            Row {
              spacing: Style.space(6)
              Text {
                text: "󰇚"
                textFormat: Text.PlainText
                color: Color.accent
                font.family: root.barFontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                text: Model.formatSpeed(root.stats.rxSpeed)
                textFormat: Text.PlainText
                color: root.barForeground
                font.family: root.barFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
            }
            Text {
              text: "Total: " + Model.formatBytes(root.stats.netRxBytes)
              textFormat: Text.PlainText
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.barFontFamily
              font.pixelSize: Style.font.bodySmall
            }
            HistoryView {
              values: root.stats.rxHistory
              minVal: 0
              maxVal: Math.max.apply(null, [1024].concat(root.stats.rxHistory))
              graphColor: Color.accent
              visible: root.showNetworkHistory && root.stats.rxHistory.length > 1
            }
          }
        }

        // Upload
        Item {
          width: (parent.width - parent.spacing) / 2
          height: ulCol.implicitHeight
          Column {
            id: ulCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.space(2)
            Row {
              spacing: Style.space(6)
              Text {
                text: "󰕒"
                textFormat: Text.PlainText
                color: Qt.lighter(Color.accent, 1.2)
                font.family: root.barFontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                text: Model.formatSpeed(root.stats.txSpeed)
                textFormat: Text.PlainText
                color: root.barForeground
                font.family: root.barFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
            }
            Text {
              text: "Total: " + Model.formatBytes(root.stats.netTxBytes)
              textFormat: Text.PlainText
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.barFontFamily
              font.pixelSize: Style.font.bodySmall
            }
            HistoryView {
              values: root.stats.txHistory
              minVal: 0
              maxVal: Math.max.apply(null, [1024].concat(root.stats.txHistory))
              graphColor: Qt.lighter(Color.accent, 1.2)
              visible: root.showNetworkHistory && root.stats.txHistory.length > 1
            }
          }
        }
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: !root.vertical ? (slotsRow.implicitWidth + scaledHorizontalMargin * 2) : root.barSize
    
    tooltipText: "CPU: " + root.stats.cpuPercent + "%"
      + (root.stats.cpuTemp ? " (" + root.stats.cpuTemp + ")" : "")
      + "\nRAM: " + Math.round(root.stats.memPercent) + "% (" + Model.formatKb(root.stats.memUsedKb) + " / " + Model.formatKb(root.stats.memTotalKb) + ")"
      + "\nDisk (" + (root.stats.diskMount || "$HOME") + "): " + root.stats.diskPercent + "% (" + Model.formatKb(root.stats.diskUsedKb) + " / " + Model.formatKb(root.stats.diskTotalKb) + ")"
      + "\nNetwork: 󰇚 " + Model.formatSpeed(root.stats.rxSpeed) + "  󰕒 " + Model.formatSpeed(root.stats.txSpeed)
      + "\n\nLeft-click: Open Overview Panel\nRight-click: Launch btop\nMiddle-click: Refresh"

    onPressed: function(b) {
      if (b === Qt.RightButton) root.launchBtop()
      else if (b === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }

    Row {
      id: slotsRow
      anchors.centerIn: parent
      spacing: Style.space(10)
      visible: !root.vertical

      Repeater {
        model: root.visibleBarSlots
        delegate: Loader {
          required property string modelData
          anchors.verticalCenter: parent.verticalCenter
          sourceComponent: {
            if (modelData === "cpu") return cpuSlotComponent
            if (modelData === "gpu") return gpuSlotComponent
            if (modelData === "memory") return memSlotComponent
            if (modelData === "disk") return diskSlotComponent
            if (modelData === "network") return netSlotComponent
            if (modelData === "rx") return dlSlotComponent
            if (modelData === "tx") return ulSlotComponent
            return null
          }
        }
      }
    }

    // Vertical fallback
    Column {
      id: verticalCol
      anchors.centerIn: parent
      spacing: Style.space(2)
      visible: root.vertical === true
      opacity: root.vertical === true ? 1.0 : 0.0

      Repeater {
        model: root.visibleBarSlots
        delegate: Loader {
          required property string modelData
          anchors.horizontalCenter: parent.horizontalCenter
          sourceComponent: {
            if (modelData === "cpu") return verticalCpuComponent
            if (modelData === "gpu") return verticalGpuComponent
            if (modelData === "memory") return verticalMemComponent
            if (modelData === "disk") return verticalDiskComponent
            return null
          }
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        // Header / Hero Row
        Row {
          width: parent.width
          Item {
            width: parent.width - btopBtn.implicitWidth
            height: Math.max(heroCol.implicitHeight, btopBtn.implicitHeight)
            Column {
              id: heroCol
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)
              Text {
                text: "System Monitor"
                textFormat: Text.PlainText
                color: root.barForeground
                font.family: root.barFontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                text: (root.stats.cpuTemp ? root.stats.cpuTemp + " · " : "") + (root.stats.uptime ? "Uptime " + root.stats.uptime : "")
                textFormat: Text.PlainText
                color: Qt.darker(root.barForeground, 1.4)
                font.family: root.barFontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
          Button {
            id: btopBtn
            iconText: "󰓅"
            text: "btop"
            bordered: true
            fontSize: Style.font.caption
            iconSize: Style.font.caption
            horizontalPadding: Style.space(8)
            verticalPadding: Style.space(4)
            onClicked: root.launchBtop()
          }
        }

        Repeater {
          model: root.visiblePanelSections
          delegate: Column {
            required property string modelData
            required property int index
            width: parent.width
            spacing: Style.space(10)

            PanelSeparator {
              foreground: root.barForeground
            }

            Loader {
              width: parent.width
              sourceComponent: {
                if (modelData === "cpu") return cpuSectionComponent
                if (modelData === "memory") return memSectionComponent
                if (modelData === "storage") return storageSectionComponent
                if (modelData === "network") return netSectionComponent
                return null
              }
            }
          }
        }
      }
    }
  }
}
