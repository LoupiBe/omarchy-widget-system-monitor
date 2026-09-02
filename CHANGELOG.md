# Changelog

All notable changes to the **System Monitor for Omarchy** widget are documented in this file.

## [1.0.0] - 2026-09-02

### ✨ Features
- **Live Metrics Top Bar Pill**: Real-time display for CPU (%), RAM (%), Storage/Home partition (%), GPU (%), and dual-arrow bandwidth activity (`rx` / `tx`).
- **Jitter-Free Zero Layout Shift**: Calibrated fixed-width container slots and right-aligned typography guarantee neighboring top bar widgets remain completely stationary as numbers fluctuate.
- **Dynamic Orientation**: Seamlessly adapts to horizontal and vertical Omarchy desktop top bars.
- **Overview Popup Panel**:
  - CPU load gauge, load averages (1m, 5m, 15m), core count, and per-core mini load bars (up to 64 cores).
  - Optional multi-vendor GPU monitoring (Intel DRM frequency ratios, AMD DRM sysfs, NVIDIA `nvidia-smi`) with VRAM metrics.
  - Memory & Swap usage breakdown with visual progress bar.
  - Storage ($HOME partition) utilization, capacity, and remaining free space.
  - Network throughput with active interface name, live download/upload rates, and cumulative session data transfer totals.
- **Dynamic Reordering**:
  - Full customizable metric order for the top bar via `barOrder` (e.g. `["cpu", "memory", "network"]`).
  - Full customizable section order for the overview popup via `panelOrder` (e.g. `["cpu", "network", "memory", "storage"]`).
- **Zero-Daemon Architecture**: High-speed, non-blocking native bash/awk collector (`stats.sh`) with sub-millisecond QML parser (`Model.js`).
- **Watchdog & Security Hardening**:
  - 2.0s automatic process execution watchdog to prevent stalled runs.
  - Two-sided input bounding (<=8KB, <=128 lines, <=64 cores).
  - Explicit `Text.PlainText` rendering across all hardware-derived text sinks.
- **Power & UX Optimizations**:
  - Instant refresh on popup open (`onOpenedChanged`).
  - Lock screen battery saver slowing polling when Hyprland/Omarchy is locked.
  - Smart active network interface detection picking the highest-volume adapter.
  - One-click `btop` task manager launcher via right-click or popup header button.

### 🧪 Testing & CI
- Comprehensive 25-suite unit test framework covering edge cases, malformed sysfs, high core counts, and string sanitization.
- Automated GitHub Actions CI workflow across Node.js 18, 20, and 22.
