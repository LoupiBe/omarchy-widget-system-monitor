// Model.js - System Monitor calculation & formatting helpers

function createInitialState() {
  return {
    cpuPercent: 0,
    cpuIdle: 0,
    cpuTotal: 0,
    cpuModel: "",
    cpuTemp: "",
    cores: [],
    coreCount: 0,
    memTotalKb: 0,
    memUsedKb: 0,
    memAvailKb: 0,
    memPercent: 0,
    swapTotalKb: 0,
    swapUsedKb: 0,
    swapPercent: 0,
    netRxBytes: 0,
    netTxBytes: 0,
    rxSpeed: 0,
    txSpeed: 0,
    netIface: "eth0",
    load1: "0.00",
    load5: "0.00",
    load15: "0.00",
    uptime: "",
    timestamp: 0,
    initialized: false
  };
}

function parseStats(raw, prevState, nowMs) {
  var now = Number(nowMs) || Date.now();
  var state = prevState || createInitialState();
  var lines = String(raw || "").split("\n");
  
  var kv = {};
  var rawCores = {};

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (!line) continue;
    var parts = line.split("\t");
    var key = parts[0];
    if (key.indexOf("core_") === 0) {
      var coreId = key.substring(5);
      rawCores[coreId] = {
        idle: parseFloat(parts[1]) || 0,
        total: parseFloat(parts[2]) || 0
      };
    } else {
      kv[key] = parts[1];
    }
  }

  var next = Object.assign({}, state);
  next.timestamp = now;

  // 1. CPU Overall
  var cpuIdle = parseFloat(kv["cpu_idle"]) || 0;
  var cpuTotal = parseFloat(kv["cpu_total"]) || 0;

  if (state.initialized && state.cpuTotal > 0 && cpuTotal > state.cpuTotal) {
    var totalDelta = cpuTotal - state.cpuTotal;
    var idleDelta = cpuIdle - state.cpuIdle;
    var usage = totalDelta > 0 ? (1 - (idleDelta / totalDelta)) * 100 : 0;
    next.cpuPercent = Math.max(0, Math.min(100, Math.round(usage)));
  } else if (!state.initialized) {
    next.cpuPercent = 0;
  }
  next.cpuIdle = cpuIdle;
  next.cpuTotal = cpuTotal;

  // 2. Per-core CPU
  var prevCores = state.coresMap || {};
  var nextCoresMap = {};
  var coresList = [];
  var coreIds = Object.keys(rawCores).sort(function(a, b) { return Number(a) - Number(b); });

  for (var c = 0; c < coreIds.length; c++) {
    var cid = coreIds[c];
    var cur = rawCores[cid];
    var prev = prevCores[cid];
    var pct = 0;
    if (state.initialized && prev && cur.total > prev.total) {
      var cDelta = cur.total - prev.total;
      var cIdleDelta = cur.idle - prev.idle;
      var cUsage = cDelta > 0 ? (1 - (cIdleDelta / cDelta)) * 100 : 0;
      pct = Math.max(0, Math.min(100, Math.round(cUsage)));
    }
    nextCoresMap[cid] = cur;
    coresList.push({
      id: cid,
      label: "C" + (Number(cid) + 1),
      percent: pct
    });
  }
  next.coresMap = nextCoresMap;
  next.cores = coresList;
  next.coreCount = coresList.length;

  // 3. Memory & Swap
  next.memTotalKb = parseFloat(kv["mem_total_kb"]) || 0;
  next.memUsedKb = parseFloat(kv["mem_used_kb"]) || 0;
  next.memAvailKb = parseFloat(kv["mem_avail_kb"]) || 0;
  next.memPercent = parseFloat(kv["mem_percent"]) || 0;
  next.swapTotalKb = parseFloat(kv["swap_total_kb"]) || 0;
  next.swapUsedKb = parseFloat(kv["swap_used_kb"]) || 0;
  next.swapPercent = parseFloat(kv["swap_percent"]) || 0;

  // 4. Network
  var netRx = parseFloat(kv["net_rx_bytes"]) || 0;
  var netTx = parseFloat(kv["net_tx_bytes"]) || 0;
  next.netIface = kv["net_iface"] || state.netIface || "eth0";

  if (state.initialized && state.timestamp > 0 && now > state.timestamp) {
    var timeDeltaSec = (now - state.timestamp) / 1000;
    if (timeDeltaSec > 0.2) {
      var rxDelta = netRx >= state.netRxBytes ? netRx - state.netRxBytes : 0;
      var txDelta = netTx >= state.netTxBytes ? netTx - state.netTxBytes : 0;
      next.rxSpeed = Math.max(0, rxDelta / timeDeltaSec);
      next.txSpeed = Math.max(0, txDelta / timeDeltaSec);
    }
  } else {
    next.rxSpeed = 0;
    next.txSpeed = 0;
  }
  next.netRxBytes = netRx;
  next.netTxBytes = netTx;

  // 5. Load, uptime, info
  next.load1 = kv["load_1m"] || state.load1 || "0.00";
  next.load5 = kv["load_5m"] || state.load5 || "0.00";
  next.load15 = kv["load_15m"] || state.load15 || "0.00";
  next.uptime = kv["uptime"] || state.uptime || "";
  next.cpuModel = kv["cpu_model"] || state.cpuModel || "CPU";
  next.cpuTemp = kv["cpu_temp"] || state.cpuTemp || "";

  next.initialized = true;
  return next;
}

function formatSpeed(bytesPerSec) {
  var b = Number(bytesPerSec) || 0;
  if (b <= 0) return "0 KB/s";
  if (b < 1024) return "<1 KB/s";
  if (b < 1024 * 1024) return (b / 1024).toFixed(b > 102400 ? 0 : 1) + " KB/s";
  if (b < 1024 * 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + " MB/s";
  return (b / (1024 * 1024 * 1024)).toFixed(2) + " GB/s";
}

function formatSpeedCompact(bytesPerSec) {
  var b = Number(bytesPerSec) || 0;
  if (b <= 0) return "0K/s";
  if (b < 1024) return "<1K/s";
  if (b < 1024 * 1024) return (b / 1024).toFixed(0) + "K/s";
  if (b < 1024 * 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + "M/s";
  return (b / (1024 * 1024 * 1024)).toFixed(1) + "G/s";
}

function formatBytes(bytes) {
  var b = Number(bytes) || 0;
  if (b <= 0) return "0 KB";
  if (b < 1024) return "<1 KB";
  if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " KB";
  if (b < 1024 * 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + " MB";
  return (b / (1024 * 1024 * 1024)).toFixed(1) + " GB";
}

function formatKb(kb) {
  var k = Number(kb) || 0;
  if (k < 1024 * 1024) return (k / 1024).toFixed(0) + " MB";
  return (k / (1024 * 1024)).toFixed(1) + " GB";
}

if (typeof module !== "undefined") {
  module.exports = {
    createInitialState: createInitialState,
    parseStats: parseStats,
    formatSpeed: formatSpeed,
    formatSpeedCompact: formatSpeedCompact,
    formatBytes: formatBytes,
    formatKb: formatKb
  };
}
