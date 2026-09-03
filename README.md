# System Monitor for Omarchy

A native top bar widget and popup overview panel for Omarchy Linux displaying live CPU, GPU, RAM, storage, and bandwidth activity with configurable sparkline history timelines.

![System Monitor preview](preview.png)

## ✨ Unique Features & Highlights

- ⚡ **Zero-Dependency Native Collector**: Directly queries Linux `/proc` and `/sys` interfaces with pure POSIX shell and AWK. No Python daemon, Node.js runtime, or background services required (~15–20ms execution per tick).
- 📈 **Real-Time Sparklines & History Timelines**: In-memory sliding window tracking with sub-millisecond rendering. Choose between minimalist monospace block sparklines (` ▂▃▄▅▆▇█`), micro-bars, or smooth area curves.
- 🌐 **Adaptive Bandwidth Scaling & On-Demand Speedtest**: Configure network graph capacity against dynamic sliding-window traffic (`auto`), session peak records (`session-peak`), physical hardware link rates (`link-speed`), or fixed custom ceilings (`fixed`). Includes an integrated one-click `󰓅` Speedtest button with automatic Cloudflare CDN fallback.
- 🎮 **Multi-Vendor GPU Load & VRAM Monitoring**: Supports NVIDIA (`nvidia-smi` with timeout protection), AMD (`gpu_busy_percent`), and Intel (`gt_act_freq_mhz`) graphics adapters in both the top bar and overview panel.
- 📏 **Jitter-Free Fixed Layout (Zero Horizontal Shift)**: Each top bar metric slot uses calibrated fixed-width containers with right-aligned typography. The bar never shifts, bounces, or resizes when metric digits change length (e.g. going from `9%` to `10%` to `100%` or `<1 KB/s` to `12.5 MB/s`).
- 🌡️ **Accurate CPU Package Temperature**: Automatically prioritizes dedicated CPU hardware sensors (Intel `coretemp`, AMD `k10temp`/`zenpower`, ARM SoC) over generic motherboard/ACPI ambient zones to report exact die temperatures matching `btop`.
- 🔀 **Independent Bar vs. Popup Configuration**: Customize what appears in your top bar pill separately from what is displayed in the popup overview panel (e.g. keep the bar minimal while showing all details in the popup).
- 📐 **Full Metric & Section Reordering**: Freely customize the ordering of metric slots in the top bar pill (`barOrder`) and overview panel sections (`panelOrder`) via simple lists or comma-separated strings.
- 🛡️ **Hardened Architecture & Security**: Producer-side bounding (<= 8KB / 128 lines max), consumer-side core caps (<= 64 cores), control-character sanitization, explicit `Text.PlainText` rendering across all sinks, and a 2.0s process watchdog timer to prevent hung subprocesses.
- ⚡ **Interactive Productivity Shortcuts**: Left-click to inspect full metrics, right-click to instantly launch or focus `btop` in a floating terminal, and middle-click to trigger an immediate metrics refresh.

## 📊 Feature Breakdown

### 1. Top Bar Pill
- **Live Metrics**: CPU usage (%), GPU usage (%), RAM usage (%), Storage/Home partition (%), Download bandwidth, and Upload bandwidth (`15%    42% 󰍛   44% (68G) 󰋊   1.2 MB/s 󰇚   340 KB/s 󰕒`).
- **Zero Layout Jitter**: Fixed slot widths guarantee neighboring top bar widgets remain perfectly stationary on every refresh tick.
- **Dynamic Orientation**: Seamlessly adapts between horizontal and vertical bar layouts.
- **Threshold Alert Colors**: Color transitions to warning and urgent accent colors when CPU, GPU, Memory, or Disk cross configured alert thresholds.
- **Customizable Order**: Rearrange pill slots (e.g. `["disk", "cpu", "memory", "network"]` or `"cpu, memory, network"`).

### 2. Overview Popup Panel (Left-Click)
- **Header Summary**: Real-time CPU die temperature, system uptime, and a quick-launch **`btop`** task manager button.
- **CPU Load Section**: Overall utilization percentage, dynamic progress bar, optional timeline history graph, 1m/5m/15m load averages, core count, and per-core mini load bars (supporting up to 64 cores).
- **GPU Section (Optional)**: Embedded GPU load percentage, die temperature, progress bar, optional timeline history graph, and dedicated VRAM used / total metrics.
- **Memory & Swap Section**: Used / total RAM, available RAM, optional timeline history graph, and swap space breakdown with visual progress bar.
- **Storage Section**: Primary `$HOME` partition mount path, used / total disk capacity, free space remaining, optional timeline history graph, and utilization progress bar.
- **Network Section**: Active network interface name, live traffic header, scale mode indicator, real-time download and upload transfer rates with dedicated sparklines directly below live speeds, cumulative session data transfer totals at the bottom, and an interactive **Speedtest button (`󰓅`)**.
- **Section Reordering**: Set any section order you prefer (e.g. `["cpu", "network", "memory", "storage"]`).

### 3. Timeline History Styles & Sizing

The overview panel includes an integrated timeline engine that tracks historical trends across all metric sections.

#### Graph Styles (`historyStyle`)
- **`"sparkline"`** *(Default)*: Minimalist Unicode monospace block character sparkline (` ▂▃▄▅▆▇█`). Zero canvas overhead and ultra-crisp typography.
- **`"bars"`**: Discrete vertical micro-bars with progressive opacity gradients.
- **`"area"`**: Smooth anti-aliased shaded curve graph with subtle accent fill.

#### Height Tiers (`historySize`)
Configure the vertical graph height uniformly across all sections:

| Tier | Height | Multiplier | Best For |
|---|:---:|:---:|---|
| **`"micro"`** | `8 px` | $1.0\times$ | Ultra-compact overview panels |
| **`"small"`** | `14 px` | $1.75\times$ | Compact, subtle timeline visualization |
| **`"normal"`** | `20 px` | $2.5\times$ | **Default** — Balanced clarity and aesthetics |
| **`"big"`** | `30 px` | $3.75\times$ | Expanded trend monitoring |
| **`"huge"`** | `40 px` | $5.0\times$ | Maximum visibility ($5\times$ micro) |

#### Bandwidth Scaling Modes (`networkScaleMode`)
Control how 100% capacity is calculated for the download and upload timeline graphs:
- **`"auto"`** *(Default)*: Auto-scales dynamically to the highest speed in the visible sliding window (best for viewing subtle traffic variations during normal browsing).
- **`"session-peak"`**: Scales against the highest download/upload speed recorded since shell launch or reboot.
- **`"link-speed"`**: Scales against the physical network interface link speed (e.g. `866 Mbps` on Wi-Fi, `1000 Mbps` on Gigabit Ethernet).
- **`"fixed"`**: Scales against a fixed bandwidth limit configured via `networkMaxSpeed` (e.g. `"100M"`, `"500M"`, `"1G"`, `"12.5MB/s"`).
- **Interactive Speedtest (`󰓅`)**: Clicking the speed gauge button in the overview panel runs a fast, non-intrusive 2–3s test and automatically calibrates the timeline scale to your measured connection speed!

### 4. Mouse & Keyboard Shortcuts
- **Left-Click**: Toggle overview popup panel.
- **Right-Click**: Instantly open or focus `btop` in a floating terminal.
- **Middle-Click**: Force immediate metrics refresh.
- **Escape / Tab**: Close popup or cycle between adjacent panels.

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
  "showGpu": false,
  "showMemory": true,
  "showDisk": false,
  "showNetwork": true,
  "showTemp": false,
  "barOrder": ["cpu", "memory", "disk", "network"],
  "panelShowCpu": true,
  "panelShowGpu": false,
  "panelShowMemory": true,
  "panelShowDisk": true,
  "panelShowNetwork": true,
  "historyStyle": "sparkline",
  "historySize": "normal",
  "historyPoints": 20,
  "showCpuHistory": true,
  "showNetworkHistory": true,
  "showMemoryHistory": false,
  "showDiskHistory": false,
  "showGpuHistory": false,
  "networkScaleMode": "auto",
  "networkMaxSpeed": "100M",
  "panelOrder": ["cpu", "memory", "storage", "network"],
  "cpuAlertPercent": 85,
  "gpuAlertPercent": 85,
  "memAlertPercent": 85,
  "diskAlertPercent": 90
}
```

| Setting | Type | Default | Description |
|---|---|---|---|
| `refreshIntervalSec` | integer | `2` | Update interval in seconds (1 to 10). |
| `showCpu` | boolean | `true` | Show or hide CPU load percentage in the top bar pill. |
| `showGpu` | boolean | `false` | Show or hide GPU load percentage in the top bar pill. |
| `showMemory` | boolean | `true` | Show or hide RAM percentage in the top bar pill. |
| `showDisk` | boolean | `false` | Show or hide Storage (Disk) % & free space in the top bar pill. |
| `showNetwork` | boolean | `true` | Show or hide download/upload bandwidth in the top bar pill. |
| `showTemp` | boolean | `false` | Show or hide CPU temperature in the top bar pill alongside CPU %. |
| `barOrder` | list / string | `["cpu", "memory", "disk", "network"]` | Custom order of metric slots on the top bar pill (`cpu`, `gpu`, `memory`, `disk`, `network`). |
| `panelShowCpu` | boolean | `true` | Show or hide the CPU section in the overview popup panel. |
| `panelShowGpu` | boolean | `false` | Show or hide GPU load meter and VRAM inside the CPU panel in the overview. |
| `panelShowMemory` | boolean | `true` | Show or hide the Memory section in the overview popup panel. |
| `panelShowDisk` | boolean | `true` | Show or hide the Storage section in the overview popup panel. |
| `panelShowNetwork` | boolean | `true` | Show or hide the Network section in the overview popup panel. |
| `historyStyle` | string | `"sparkline"` | Style for timeline history graphs (`"sparkline"`, `"bars"`, `"area"`). |
| `historySize` | string | `"normal"` | Height of history graphs (`"micro"` [8px], `"small"` [14px], `"normal"` [20px], `"big"` [30px], `"huge"` [40px]). |
| `historyPoints` | integer | `20` | Number of history sample points to keep in timeline (5 to 60). |
| `showCpuHistory` | boolean | `true` | Show timeline sparkline/graph in the CPU overview section. |
| `showNetworkHistory` | boolean | `true` | Show timeline sparklines for download and upload in Network section. |
| `showMemoryHistory` | boolean | `false` | Show timeline sparkline/graph in the Memory overview section. |
| `showDiskHistory` | boolean | `false` | Show timeline sparkline/graph in the Storage overview section. |
| `showGpuHistory` | boolean | `false` | Show timeline sparkline/graph in the GPU overview section. |
| `networkScaleMode` | string | `"auto"` | Bandwidth scaling mode: `"auto"` (sliding window peak), `"session-peak"` (highest speed since launch), `"link-speed"` (hardware interface link capacity), or `"fixed"` (scaled to `networkMaxSpeed`). |
| `networkMaxSpeed` | string | `"100M"` | Fixed bandwidth ceiling used when `networkScaleMode` is `"fixed"` (e.g. `"100M"`, `"1G"`, `"50M"`, `"12.5MB/s"`). |
| `panelOrder` | list / string | `["cpu", "memory", "storage", "network"]` | Custom order of sections in the popup overview panel. |
| `cpuAlertPercent` | integer | `85` | CPU % threshold to trigger urgent alert color (50 to 99). |
| `gpuAlertPercent` | integer | `85` | GPU % threshold to trigger urgent alert color (50 to 99). |
| `memAlertPercent` | integer | `85` | Memory % threshold to trigger urgent alert color (50 to 99). |
| `diskAlertPercent` | integer | `90` | Disk % threshold to trigger urgent alert color (50 to 99). |

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
