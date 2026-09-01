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
    stats = Model.parseStats(rawText, stats, Date.now())
  }

  function launchBtop() {
    if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
    root.close()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statsProc
    command: [root.statsScriptPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateStats(text)
    }
  }

  Timer {
    interval: Math.max(1000, root.refreshIntervalSec * 1000)
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
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

      // CPU slot
      Row {
        spacing: Style.space(3)
        anchors.verticalCenter: parent.verticalCenter
        Text {
          width: Style.space(34)
          horizontalAlignment: Text.AlignRight
          text: root.stats.cpuPercent + "%"
          color: root.barForeground
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
          renderType: Text.NativeRendering
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: ""
          color: root.barForeground
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
          renderType: Text.NativeRendering
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // RAM slot
      Row {
        spacing: Style.space(3)
        anchors.verticalCenter: parent.verticalCenter
        Text {
          width: Style.space(34)
          horizontalAlignment: Text.AlignRight
          text: Math.round(root.stats.memPercent) + "%"
          color: root.barForeground
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
          renderType: Text.NativeRendering
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: "󰍛"
          color: root.barForeground
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
          renderType: Text.NativeRendering
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // Download slot
      Row {
        spacing: Style.space(3)
        anchors.verticalCenter: parent.verticalCenter
        Text {
          width: Style.space(76)
          horizontalAlignment: Text.AlignRight
          text: Model.formatSpeed(root.stats.rxSpeed)
          color: root.barForeground
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
          renderType: Text.NativeRendering
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: "󰇚"
          color: root.barForeground
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
          renderType: Text.NativeRendering
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // Upload slot
      Row {
        spacing: Style.space(3)
        anchors.verticalCenter: parent.verticalCenter
        Text {
          width: Style.space(76)
          horizontalAlignment: Text.AlignRight
          text: Model.formatSpeed(root.stats.txSpeed)
          color: root.barForeground
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
          renderType: Text.NativeRendering
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: "󰕒"
          color: root.barForeground
          font.family: root.barFontFamily
          font.pixelSize: Style.font.bodySmall
          renderType: Text.NativeRendering
          anchors.verticalCenter: parent.verticalCenter
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

      Text {
        text: " " + root.stats.cpuPercent + "%"
        color: root.barForeground
        font.family: root.barFontFamily
        font.pixelSize: Style.font.caption
        renderType: Text.NativeRendering
      }
      Text {
        text: "󰍛 " + Math.round(root.stats.memPercent) + "%"
        color: root.barForeground
        font.family: root.barFontFamily
        font.pixelSize: Style.font.caption
        renderType: Text.NativeRendering
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
                color: root.barForeground
                font.family: root.barFontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                text: (root.stats.cpuTemp ? root.stats.cpuTemp + " · " : "") + (root.stats.uptime ? "Uptime " + root.stats.uptime : "")
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

        PanelSeparator { foreground: root.barForeground }

        // --- CPU Section ---
        Column {
          width: parent.width
          spacing: Style.space(6)

          Row {
            width: parent.width
            Text {
              text: "CPU LOAD"
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.barFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth); height: 1 }
            Text {
              text: root.stats.cpuPercent + "%"
              color: root.stats.cpuPercent > 85 ? Color.urgent : (root.stats.cpuPercent > 65 ? Color.accent : root.barForeground)
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
              color: root.stats.cpuPercent > 85 ? Color.urgent : (root.stats.cpuPercent > 65 ? Color.accent : root.barForeground)
              Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
              Behavior on color { ColorAnimation { duration: 200 } }
            }
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
                width: Math.max(Style.space(32), (column.width - (Math.min(8, root.stats.cores.length) - 1) * Style.space(4)) / Math.min(8, root.stats.cores.length))
                height: Style.space(20)

                Column {
                  anchors.fill: parent
                  spacing: Style.space(2)
                  Text {
                    text: modelData.label + " " + modelData.percent + "%"
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
                      color: modelData.percent > 85 ? Color.urgent : (modelData.percent > 65 ? Color.accent : root.barForeground)
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
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.barFontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
            Text {
              text: root.stats.coreCount + " Cores"
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.barFontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        PanelSeparator { foreground: root.barForeground }

        // --- Memory Section ---
        Column {
          width: parent.width
          spacing: Style.space(6)

          Row {
            width: parent.width
            Text {
              text: "MEMORY"
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.barFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth); height: 1 }
            Text {
              text: Math.round(root.stats.memPercent) + "% (" + Model.formatKb(root.stats.memUsedKb) + " / " + Model.formatKb(root.stats.memTotalKb) + ")"
              color: root.stats.memPercent > 85 ? Color.urgent : (root.stats.memPercent > 70 ? Color.accent : root.barForeground)
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
              color: root.stats.memPercent > 85 ? Color.urgent : (root.stats.memPercent > 70 ? Color.accent : root.barForeground)
              Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
              Behavior on color { ColorAnimation { duration: 200 } }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)
            Text {
              text: "Avail: " + Model.formatKb(root.stats.memAvailKb)
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.barFontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
            Text {
              text: "Swap: " + Model.formatKb(root.stats.swapUsedKb) + " / " + Model.formatKb(root.stats.swapTotalKb)
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.barFontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        PanelSeparator { foreground: root.barForeground }

        // --- Network Section ---
        Column {
          width: parent.width
          spacing: Style.space(6)

          Row {
            width: parent.width
            Text {
              text: "NETWORK (" + root.stats.netIface + ")"
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.barFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth); height: 1 }
            Text {
              text: "Live Traffic"
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
                    color: Color.accent
                    font.family: root.barFontFamily
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    text: Model.formatSpeed(root.stats.rxSpeed)
                    color: root.barForeground
                    font.family: root.barFontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }
                Text {
                  text: "Total: " + Model.formatBytes(root.stats.netRxBytes)
                  color: Qt.darker(root.barForeground, 1.4)
                  font.family: root.barFontFamily
                  font.pixelSize: Style.font.bodySmall
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
                    color: Qt.lighter(Color.accent, 1.2)
                    font.family: root.barFontFamily
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    text: Model.formatSpeed(root.stats.txSpeed)
                    color: root.barForeground
                    font.family: root.barFontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }
                Text {
                  text: "Total: " + Model.formatBytes(root.stats.netTxBytes)
                  color: Qt.darker(root.barForeground, 1.4)
                  font.family: root.barFontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }
        }
      }
    }
  }
}
