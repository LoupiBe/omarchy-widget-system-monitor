# System Monitor for Omarchy

A native top bar widget and popup overview panel for Omarchy Linux displaying live CPU, RAM, and bandwidth activity.

![System Monitor preview](preview.png)

## Features

- **Top Bar Pill**: Live CPU %, RAM %, Download bandwidth, and Upload bandwidth (`15%    42% 󰍛   1.2 MB/s 󰇚   340 KB/s 󰕒`) with load-based alert colors.
- **Popup Overview Panel (Left-click)**:
  - **CPU**: Total load bar, load averages (1m, 5m, 15m), CPU model, core count, per-core mini meters, and temperature.
  - **Memory & Swap**: RAM used / total, available RAM, and swap breakdown with progress bar.
  - **Network Activity**: Active interface name, live download/upload rates, and total cumulative bytes.
  - **Quick Action**: "btop" button to launch or focus btop in a floating terminal.
- **Mouse Shortcuts**:
  - **Left-click**: Toggle overview popup panel.
  - **Right-click**: Instantly open or focus `btop` in a floating terminal.
  - **Middle-click**: Force immediate metrics refresh.

## Install

```sh
omarchy plugin add https://github.com/LoupiBe/omarchy-widget-system-monitor.git --enable
```

## Usage

- Click the widget on the top bar to open or close the overview panel.
- Press **Escape** while the panel is open to close it.
- Right-click the widget to open `btop`.

## Configure

### Bar Positioning

Place the widget in your preferred bar section (e.g. `left`, `center`, `right`):

```sh
omarchy bar move io.github.loupibe.system-monitor --section left
```

### Options & Customization

The widget can be fully customized in `~/.config/omarchy/shell.json`:

```json
{
  "id": "io.github.loupibe.system-monitor",
  "refreshIntervalSec": 2,
  "showCpu": true,
  "showMemory": true,
  "showNetwork": true,
  "showTemp": false,
  "cpuAlertPercent": 85,
  "memAlertPercent": 85
}
```

| Setting | Type | Default | Description |
|---|---|---|---|
| `refreshIntervalSec` | integer | `2` | Update interval in seconds (1 to 10). |
| `showCpu` | boolean | `true` | Show or hide the CPU load percentage in the top bar pill. |
| `showMemory` | boolean | `true` | Show or hide the RAM percentage in the top bar pill. |
| `showNetwork` | boolean | `true` | Show or hide the download/upload bandwidth in the top bar pill. |
| `showTemp` | boolean | `false` | Show or hide the CPU temperature in the top bar pill alongside CPU %. |
| `cpuAlertPercent` | integer | `85` | CPU % threshold to trigger urgent alert color (50 to 99). |
| `memAlertPercent` | integer | `85` | Memory % threshold to trigger urgent alert color (50 to 99). |

## Remove

```sh
omarchy plugin remove io.github.loupibe.system-monitor
```

## Dependencies

- **Linux `/proc` & `/sys`**: Used by `stats.sh` for lightweight, zero-dependency metrics collection (standard on all Linux systems).
- **`btop`** *(optional)*: For the quick-launch task manager action (standard in Omarchy).
- **Nerd Font**: For bar glyphs and panel icons (standard in Omarchy).

## License

MIT © 2026 LoupiBe
