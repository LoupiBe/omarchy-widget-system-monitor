// Model.js - System Monitor calculation & formatting helpers

function sanitizeString(val, maxLen, fallback) {
  if (val === undefined || val === null) {
    return fallback !== undefined ? fallback : "";
  }
  var s = String(val).replace(/[\r\n\x00-\x1f\x7f]/g, "").trim();
  if (maxLen && s.length > maxLen) {
    s = s.slice(0, maxLen);
  }
  return s.length > 0 ? s : (fallback !== undefined ? fallback : "");
}

function safeNumber(val, fallback) {
  if (val === null || val === undefined || (typeof val === "string" && val.trim() === "")) {
    return fallback !== undefined ? fallback : 0;
  }
  var n = Number(val);
  return (isFinite(n) && !isNaN(n)) ? n : (fallback !== undefined ? fallback : 0);
}

function createInitialState() {
  return {
    cpuPercent: 0,
    cpuIdle: 0,
    cpuTotal: 0,
    cpuModel: "",
    cpuTemp: "",
    cores: [],
    coreCount: 0,
    coresMap: {},
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
    diskTotalKb: 0,
    diskUsedKb: 0,
    diskAvailKb: 0,
    diskPercent: 0,
    diskMount: "",
    load1: "0.00",
    load5: "0.00",
    load15: "0.00",
    uptime: "",
    timestamp: 0,
    initialized: false
  };
}

function parseStats(raw, prevState, nowMs) {
  var now = safeNumber(nowMs, Date.now());
  if (now <= 0) now = Date.now();
  var state = (prevState && typeof prevState === "object") ? prevState : createInitialState();
  
  // Bound raw input to max 8KB and 128 lines
  var rawStr = (typeof raw === "string") ? raw : String(raw || "");
  if (rawStr.length > 8192) {
    rawStr = rawStr.slice(0, 8192);
  }
  var lines = rawStr.split("\n").slice(0, 128);
  
  var kv = {};
  var rawCores = {};

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (!line) continue;
    var tabIdx = line.indexOf("\t");
    var key = tabIdx >= 0 ? line.substring(0, tabIdx).trim() : line;
    var rest = tabIdx >= 0 ? line.substring(tabIdx + 1) : "";
    
    if (key.indexOf("core_") === 0) {
      var cidStr = key.substring(5);
      var cidNum = parseInt(cidStr, 10);
      if (!isNaN(cidNum) && cidNum >= 0 && cidNum < 64 && (rawCores[cidNum] !== undefined || Object.keys(rawCores).length < 64)) {
        var parts = line.split(/\s+/);
        if (parts.length >= 3) {
          var cIdle = safeNumber(parts[1], -1);
          var cTotal = safeNumber(parts[2], -1);
          if (cIdle >= 0 && cTotal >= 0) {
            rawCores[cidNum] = {
              idle: cIdle,
              total: cTotal
            };
          }
        }
      }
    } else if (key.length > 0 && key.length <= 64) {
      kv[key] = rest;
    }
  }

  var next = Object.assign({}, state);
  next.timestamp = now;

  // 1. CPU Overall
  var cpuIdle = safeNumber(kv["cpu_idle"], state.cpuIdle || 0);
  var cpuTotal = safeNumber(kv["cpu_total"], state.cpuTotal || 0);

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

  // 2. Per-core CPU (capped at 64 cores)
  if (Object.keys(rawCores).length === 0 && state.initialized && state.cores && state.cores.length > 0) {
    next.coresMap = state.coresMap || {};
    next.cores = state.cores || [];
    next.coreCount = state.coreCount || 0;
  } else {
    var prevCores = state.coresMap || {};
    var nextCoresMap = {};
    var coresList = [];
    var coreIds = Object.keys(rawCores)
      .map(Number)
      .filter(function(n) { return !isNaN(n) && n >= 0 && n < 64; })
      .sort(function(a, b) { return a - b; })
      .slice(0, 64);

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
        id: String(cid),
        label: "C" + (cid + 1),
        percent: pct
      });
    }
    next.coresMap = nextCoresMap;
    next.cores = coresList;
    next.coreCount = coresList.length;
  }

  // 3. Memory & Swap
  var memTotal = safeNumber(kv["mem_total_kb"], state.memTotalKb || 0);
  var memUsed = safeNumber(kv["mem_used_kb"], state.memUsedKb || 0);
  var memAvail = safeNumber(kv["mem_avail_kb"], state.memAvailKb || 0);
  var memPct = (kv["mem_percent"] !== undefined && String(kv["mem_percent"]).trim() !== "")
    ? safeNumber(kv["mem_percent"], state.memPercent || 0)
    : (memTotal > 0 ? (memUsed / memTotal) * 100 : (state.memPercent || 0));
  next.memTotalKb = Math.max(0, memTotal);
  next.memUsedKb = Math.max(0, memUsed);
  next.memAvailKb = Math.max(0, memAvail);
  next.memPercent = Math.max(0, Math.min(100, memPct));

  var swapTotal = safeNumber(kv["swap_total_kb"], state.swapTotalKb || 0);
  var swapUsed = safeNumber(kv["swap_used_kb"], state.swapUsedKb || 0);
  var swapPct = (kv["swap_percent"] !== undefined && String(kv["swap_percent"]).trim() !== "")
    ? safeNumber(kv["swap_percent"], state.swapPercent || 0)
    : (swapTotal > 0 ? (swapUsed / swapTotal) * 100 : (state.swapPercent || 0));
  next.swapTotalKb = Math.max(0, swapTotal);
  next.swapUsedKb = Math.max(0, swapUsed);
  next.swapPercent = Math.max(0, Math.min(100, swapPct));

  // 4. Network
  var netRx = safeNumber(kv["net_rx_bytes"], state.netRxBytes || 0);
  var netTx = safeNumber(kv["net_tx_bytes"], state.netTxBytes || 0);
  next.netIface = sanitizeString(kv["net_iface"] !== undefined ? kv["net_iface"] : state.netIface, 32, (state && state.netIface) || "eth0");

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
  next.netRxBytes = Math.max(0, netRx);
  next.netTxBytes = Math.max(0, netTx);

  // 5. Load, uptime, info
  next.load1 = sanitizeString(kv["load_1m"] !== undefined ? kv["load_1m"] : state.load1, 16, (state && state.load1) || "0.00");
  next.load5 = sanitizeString(kv["load_5m"] !== undefined ? kv["load_5m"] : state.load5, 16, (state && state.load5) || "0.00");
  next.load15 = sanitizeString(kv["load_15m"] !== undefined ? kv["load_15m"] : state.load15, 16, (state && state.load15) || "0.00");
  next.uptime = sanitizeString(kv["uptime"] !== undefined ? kv["uptime"] : state.uptime, 32, (state && state.uptime) || "");
  next.cpuModel = sanitizeString(kv["cpu_model"] !== undefined ? kv["cpu_model"] : state.cpuModel, 64, (state && state.cpuModel) || "CPU");
  next.cpuTemp = sanitizeString(kv["cpu_temp"] !== undefined ? kv["cpu_temp"] : state.cpuTemp, 16, (state && state.cpuTemp) || "");

  // 6. Disk (Home partition)
  var diskTotal = safeNumber(kv["disk_total_kb"], state.diskTotalKb || 0);
  var diskUsed = safeNumber(kv["disk_used_kb"], state.diskUsedKb || 0);
  var diskAvail = safeNumber(kv["disk_avail_kb"], state.diskAvailKb || 0);
  var diskPct = (kv["disk_percent"] !== undefined && String(kv["disk_percent"]).trim() !== "")
    ? safeNumber(kv["disk_percent"], state.diskPercent || 0)
    : (diskTotal > 0 ? (diskUsed / diskTotal) * 100 : (state.diskPercent || 0));
  next.diskTotalKb = Math.max(0, diskTotal);
  next.diskUsedKb = Math.max(0, diskUsed);
  next.diskAvailKb = Math.max(0, diskAvail);
  next.diskPercent = Math.max(0, Math.min(100, Math.round(diskPct)));
  next.diskMount = sanitizeString(kv["disk_mount"] !== undefined ? kv["disk_mount"] : state.diskMount, 32, (state && state.diskMount) || "");

  next.initialized = true;
  return next;
}

function formatSpeed(bytesPerSec) {
  var b = safeNumber(bytesPerSec, 0);
  if (b <= 0) return "0 KB/s";
  if (b < 1024) return "<1 KB/s";
  if (b < 1024 * 1024) return (b / 1024).toFixed(b > 102400 ? 0 : 1) + " KB/s";
  if (b < 1024 * 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + " MB/s";
  return (b / (1024 * 1024 * 1024)).toFixed(2) + " GB/s";
}

function formatSpeedCompact(bytesPerSec) {
  var b = safeNumber(bytesPerSec, 0);
  if (b <= 0) return "0K/s";
  if (b < 1024) return "<1K/s";
  if (b < 1024 * 1024) return (b / 1024).toFixed(0) + "K/s";
  if (b < 1024 * 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + "M/s";
  return (b / (1024 * 1024 * 1024)).toFixed(1) + "G/s";
}

function formatBytes(bytes) {
  var b = safeNumber(bytes, 0);
  if (b <= 0) return "0 KB";
  if (b < 1024) return "<1 KB";
  if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " KB";
  if (b < 1024 * 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + " MB";
  return (b / (1024 * 1024 * 1024)).toFixed(1) + " GB";
}

function formatKb(kb) {
  var k = safeNumber(kb, 0);
  if (k <= 0) return "0 MB";
  if (k < 1024 * 1024) return (k / 1024).toFixed(0) + " MB";
  return (k / (1024 * 1024)).toFixed(1) + " GB";
}

function formatKbCompact(kb) {
  var k = safeNumber(kb, 0);
  if (k <= 0) return "0M";
  if (k < 1024 * 1024) return (k / 1024).toFixed(0) + "M";
  return (k / (1024 * 1024)).toFixed(0) + "G";
}

function parseOrder(val, defaultOrder) {
  var d = Array.isArray(defaultOrder) ? defaultOrder : [];
  if (Array.isArray(val) && val.length > 0) {
    return val.map(function(s) { return String(s).trim().toLowerCase(); }).filter(Boolean);
  }
  if (typeof val === "string" && val.trim().length > 0) {
    return val.split(",").map(function(s) { return s.trim().toLowerCase(); }).filter(Boolean);
  }
  return d;
}

if (typeof module !== "undefined") {
  module.exports = {
    createInitialState: createInitialState,
    parseStats: parseStats,
    formatSpeed: formatSpeed,
    formatSpeedCompact: formatSpeedCompact,
    formatBytes: formatBytes,
    formatKb: formatKb,
    formatKbCompact: formatKbCompact,
    parseOrder: parseOrder,
    sanitizeString: sanitizeString,
    safeNumber: safeNumber
  };
}
