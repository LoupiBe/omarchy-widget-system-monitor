#!/bin/bash
# Fast system metrics collector for Omarchy System Monitor widget
LC_ALL=C

collect_metrics() {
  # 1. CPU metrics from /proc/stat (max 64 cores)
  awk '
    /^cpu / {
      idle = $5 + $6
      total = 0
      for (i = 2; i <= NF; i++) total += $i
      printf "cpu_idle\t%s\ncpu_total\t%s\n", idle, total
    }
    /^cpu[0-9]+/ {
      c_num = substr($1, 4) + 0
      if (core_count < 64 && c_num < 64) {
        core_count++
        c_idle = $5 + $6
        c_total = 0
        for (i = 2; i <= NF; i++) c_total += $i
        printf "core_%d\t%s\t%s\n", c_num, c_idle, c_total
      }
    }
  ' /proc/stat 2>/dev/null

  # 2. Memory metrics from /proc/meminfo
  awk '
    /^MemTotal:/ { total = $2 }
    /^MemAvailable:/ { avail = $2 }
    /^SwapTotal:/ { swapt = $2 }
    /^SwapFree:/ { swapf = $2 }
    END {
      used = total - avail
      swapu = swapt - swapf
      printf "mem_total_kb\t%s\nmem_used_kb\t%s\nmem_avail_kb\t%s\nmem_percent\t%.1f\n", (total ? total : 0), (used ? used : 0), (avail ? avail : 0), (total > 0 ? (used / total) * 100 : 0)
      printf "swap_total_kb\t%s\nswap_used_kb\t%s\nswap_percent\t%.1f\n", (swapt ? swapt : 0), (swapu ? swapu : 0), (swapt > 0 ? (swapu / swapt) * 100 : 0)
    }
  ' /proc/meminfo 2>/dev/null

  # 3. Network metrics from /proc/net/dev (sum non-virtual active interfaces, max 32 chars for iface)
  awk '
    NR > 2 {
      sub(/:/, " ")
      iface = $1
      if (iface != "lo" && index(iface, "docker") != 1 && index(iface, "veth") != 1 && index(iface, "br-") != 1 && index(iface, "virbr") != 1) {
        rx += $2
        tx += $10
        if (active == "" && ($2 > 0 || $10 > 0)) active = substr(iface, 1, 32)
      }
    }
    END {
      if (active == "") active = "eth0"
      printf "net_rx_bytes\t%.0f\nnet_tx_bytes\t%.0f\nnet_iface\t%s\n", (rx ? rx : 0), (tx ? tx : 0), substr(active, 1, 32)
    }
  ' /proc/net/dev 2>/dev/null

  # 4. Load average & Uptime
  awk '{ print "load_1m\t" substr($1, 1, 16) "\nload_5m\t" substr($2, 1, 16) "\nload_15m\t" substr($3, 1, 16) }' /proc/loadavg 2>/dev/null
  awk '{
    s = int($1)
    d = int(s / 86400)
    h = int((s % 86400) / 3600)
    m = int((s % 3600) / 60)
    if (d > 0) printf "uptime\t%dd %dh %dm\n", d, h, m
    else if (h > 0) printf "uptime\t%dh %dm\n", h, m
    else printf "uptime\t%dm\n", m
  }' /proc/uptime 2>/dev/null

  # 5. CPU model (max 64 characters, support x86, ARM, RISC-V)
  awk '/^(model name|Model|Hardware|Processor)[ \t]*:/ { sub(/^[^:]*:[ \t]*/, ""); print "cpu_model\t" substr($0, 1, 64); exit }' /proc/cpuinfo 2>/dev/null

  # 6. CPU Temp (prioritize dedicated CPU hardware sensors over generic ACPI zones)
  temp=""

  # 6a. Check known CPU hwmon drivers (Intel coretemp, AMD k10temp/zenpower, ARM cpu_thermal)
  for hw in /sys/class/hwmon/hwmon*; do
    [ -d "$hw" ] || continue
    hname=""
    [ -f "$hw/name" ] && read -r hname < "$hw/name" 2>/dev/null
    case "$hname" in
      coretemp|k10temp|zenpower|cpu_thermal|soc_thermal)
        # Search for Package id 0, Tctl, Tdie, or Core 0 label
        for lbl in "$hw"/temp*_label; do
          [ -f "$lbl" ] || continue
          label=""
          read -r label < "$lbl" 2>/dev/null
          case "$label" in
            *"Package"*|*"Tctl"*|*"Tdie"*|*"Core 0"*)
              inp="${lbl%_label}_input"
              if [ -f "$inp" ] && read -r -t 0.1 val < "$inp" 2>/dev/null; then
                if [ -n "$val" ] && [ "$val" -gt 1000 ] 2>/dev/null; then
                  temp="$val"
                  break 2
                fi
              fi
              ;;
          esac
        done
        # Fallback within CPU driver if no specific label matched
        if [ -f "$hw/temp1_input" ] && read -r -t 0.1 val < "$hw/temp1_input" 2>/dev/null; then
          if [ -n "$val" ] && [ "$val" -gt 1000 ] 2>/dev/null; then
            temp="$val"
            break
          fi
        fi
        ;;
    esac
  done

  # 6b. Check thermal zones with explicit CPU/x86 package types
  if [ -z "$temp" ]; then
    for tz in /sys/class/thermal/thermal_zone*; do
      [ -d "$tz" ] || continue
      ztype=""
      [ -f "$tz/type" ] && read -r ztype < "$tz/type" 2>/dev/null
      case "$ztype" in
        x86_pkg_temp|cpu-thermal|soc-thermal|cpu_thermal)
          if [ -f "$tz/temp" ] && read -r -t 0.1 val < "$tz/temp" 2>/dev/null; then
            if [ -n "$val" ] && [ "$val" -gt 1000 ] 2>/dev/null; then
              temp="$val"
              break
            fi
          fi
          ;;
      esac
    done
  fi

  # 6c. Generic fallback if no dedicated CPU sensor was identified
  if [ -z "$temp" ]; then
    checked=0
    for f in /sys/class/hwmon/hwmon*/temp1_input /sys/class/thermal/thermal_zone*/temp; do
      [ "$checked" -ge 16 ] && break
      [ -f "$f" ] || continue
      checked=$((checked + 1))
      val=""
      if read -r -t 0.1 val < "$f" 2>/dev/null; then
        if [ -n "$val" ] && [ "$val" -gt 1000 ] 2>/dev/null; then
          temp="$val"
          break
        fi
      fi
    done
  fi

  if [ -n "$temp" ]; then
    awk -v t="$temp" 'BEGIN { printf "cpu_temp\t%.0f°C\n", t / 1000 }'
  fi
}

collect_metrics | head -n 128 | head -c 8192

