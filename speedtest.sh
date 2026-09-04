#!/usr/bin/env bash
# speedtest.sh - Lightweight, bounded bandwidth measurement helper for System Monitor
set -e
set -o pipefail
LC_ALL=C
PATH=/usr/bin:/bin:$PATH

rx_bytes_sec=0
tx_bytes_sec=0

# 1. Prefer speedtest-cli if installed on system
if command -v speedtest-cli >/dev/null 2>&1; then
  out=$(timeout 10 speedtest-cli --simple 2>/dev/null || true)
  if [ -n "$out" ]; then
    dl_mbit=$(echo "$out" | awk '/Download:/ {print $2}')
    ul_mbit=$(echo "$out" | awk '/Upload:/ {print $2}')
    [ -n "$dl_mbit" ] && rx_bytes_sec=$(awk -v m="$dl_mbit" 'BEGIN { printf "%.0f", (m * 1000000) / 8 }')
    [ -n "$ul_mbit" ] && tx_bytes_sec=$(awk -v m="$ul_mbit" 'BEGIN { printf "%.0f", (m * 1000000) / 8 }')
  fi
fi

# 2. Resilient fallback: fast 2-4s Cloudflare CDN speed check
if [ "$rx_bytes_sec" -le 0 ]; then
  dl_spd=$(curl -w "%{speed_download}" -o /dev/null -s --max-time 4 "https://speed.cloudflare.com/__down?bytes=10000000" 2>/dev/null || echo 0)
  rx_bytes_sec=$(awk -v s="$dl_spd" 'BEGIN { printf "%.0f", +s }')
  
  ul_spd=$(dd if=/dev/zero bs=64k count=16 2>/dev/null | curl -w "%{speed_upload}" -o /dev/null -s --max-time 3 -X POST --data-binary @- "https://speed.cloudflare.com/__up" 2>/dev/null || echo 0)
  tx_bytes_sec=$(awk -v s="$ul_spd" 'BEGIN { printf "%.0f", +s }')
fi

dl_mbps=$(awk -v b="$rx_bytes_sec" 'BEGIN { printf "%.1f", (b * 8) / 1000000 }')
ul_mbps=$(awk -v b="$tx_bytes_sec" 'BEGIN { printf "%.1f", (b * 8) / 1000000 }')

# Strictly bound producer output
{
  printf "speedtest_rx_bytes_sec\t%s\n" "$rx_bytes_sec"
  printf "speedtest_tx_bytes_sec\t%s\n" "$tx_bytes_sec"
  printf "speedtest_summary\t↓%s ↑%s Mbps\n" "$dl_mbps" "$ul_mbps"
} | head -n 8 | head -c 1024
