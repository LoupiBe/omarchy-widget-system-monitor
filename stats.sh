#!/bin/bash
# Fast system metrics collector for Omarchy System Monitor widget
LC_ALL=C

# 1. CPU metrics from /proc/stat
awk '
  /^cpu / {
    idle = $5 + $6
    total = 0
    for (i = 2; i <= NF; i++) total += $i
    printf "cpu_idle\t%s\ncpu_total\t%s\n", idle, total
  }
  /^cpu[0-9]+/ {
    c_idle = $5 + $6
    c_total = 0
    for (i = 2; i <= NF; i++) c_total += $i
    printf "core_%s\t%s\t%s\n", substr($1, 4), c_idle, c_total
  }
' /proc/stat

# 2. Memory metrics from /proc/meminfo
awk '
  /^MemTotal:/ { total = $2 }
  /^MemAvailable:/ { avail = $2 }
  /^SwapTotal:/ { swapt = $2 }
  /^SwapFree:/ { swapf = $2 }
  END {
    used = total - avail
    swapu = swapt - swapf
    printf "mem_total_kb\t%s\nmem_used_kb\t%s\nmem_avail_kb\t%s\nmem_percent\t%.1f\n", total, used, avail, (total > 0 ? (used / total) * 100 : 0)
    printf "swap_total_kb\t%s\nswap_used_kb\t%s\nswap_percent\t%.1f\n", swapt, swapu, (swapt > 0 ? (swapu / swapt) * 100 : 0)
  }
' /proc/meminfo

# 3. Network metrics from /proc/net/dev (sum non-virtual active interfaces)
awk '
  NR > 2 {
    iface = $1
    gsub(/:/, "", iface)
    if (iface != "lo" && index(iface, "docker") != 1 && index(iface, "veth") != 1 && index(iface, "br-") != 1 && index(iface, "virbr") != 1) {
      rx += $2
      tx += $10
      if (active == "" && ($2 > 0 || $10 > 0)) active = iface
    }
  }
  END {
    printf "net_rx_bytes\t%s\nnet_tx_bytes\t%s\nnet_iface\t%s\n", (rx ? rx : 0), (tx ? tx : 0), (active ? active : "eth0")
  }
' /proc/net/dev

# 4. Load average & Uptime
awk '{ print "load_1m\t" $1 "\nload_5m\t" $2 "\nload_15m\t" $3 }' /proc/loadavg
awk '{
  s = int($1)
  d = int(s / 86400)
  h = int((s % 86400) / 3600)
  m = int((s % 3600) / 60)
  if (d > 0) printf "uptime\t%dd %dh %dm\n", d, h, m
  else if (h > 0) printf "uptime\t%dh %dm\n", h, m
  else printf "uptime\t%dm\n", m
}' /proc/uptime

# 5. CPU model
awk -F: '/model name/ { gsub(/^[ \t]+/, "", $2); print "cpu_model\t" $2; exit }' /proc/cpuinfo

# 6. CPU Temp (check thermal zones or hwmon)
temp=""
for f in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp1_input; do
  if [ -r "$f" ]; then
    val=$(cat "$f" 2>/dev/null)
    if [ -n "$val" ] && [ "$val" -gt 1000 ] 2>/dev/null; then
      temp="$val"
      break
    fi
  fi
done
if [ -n "$temp" ]; then
  awk -v t="$temp" 'BEGIN { printf "cpu_temp\t%.0f°C\n", t / 1000 }'
fi
