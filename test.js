const test = require("node:test");
const assert = require("node:assert");
const { execSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const Model = require("./Model.js");

test("Model.createInitialState returns correct defaults", () => {
  const state = Model.createInitialState();
  assert.strictEqual(state.cpuPercent, 0);
  assert.strictEqual(state.coreCount, 0);
  assert.deepStrictEqual(state.cores, []);
  assert.strictEqual(state.netIface, "eth0");
  assert.strictEqual(state.initialized, false);
});

test("Model.parseStats handles normal stats input", () => {
  const raw = [
    "cpu_idle\t3000\ncpu_total\t10000",
    "core_0\t300\t1000",
    "core_1\t400\t1000",
    "mem_total_kb\t16000000",
    "mem_used_kb\t8000000",
    "mem_avail_kb\t8000000",
    "mem_percent\t50.0",
    "swap_total_kb\t4000000",
    "swap_used_kb\t1000000",
    "swap_percent\t25.0",
    "net_rx_bytes\t100000",
    "net_tx_bytes\t50000",
    "net_iface\twlp2s0",
    "load_1m\t1.20",
    "load_5m\t1.10",
    "load_15m\t0.95",
    "uptime\t2d 4h 10m",
    "cpu_model\tIntel Core i7",
    "cpu_temp\t42°C"
  ].join("\n");

  const s1 = Model.parseStats(raw, null, 1000);
  assert.strictEqual(s1.initialized, true);
  assert.strictEqual(s1.cpuPercent, 0); // first reading has 0%
  assert.strictEqual(s1.memPercent, 50);
  assert.strictEqual(s1.swapPercent, 25);
  assert.strictEqual(s1.netIface, "wlp2s0");
  assert.strictEqual(s1.cpuModel, "Intel Core i7");
  assert.strictEqual(s1.cpuTemp, "42°C");
  assert.strictEqual(s1.uptime, "2d 4h 10m");
  assert.strictEqual(s1.coreCount, 2);

  // Second tick
  const raw2 = [
    "cpu_idle\t3200\ncpu_total\t11000", // delta: total=1000, idle=200 -> 80% usage
    "core_0\t310\t1100", // delta: total=100, idle=10 -> 90%
    "core_1\t450\t1100", // delta: total=100, idle=50 -> 50%
    "net_rx_bytes\t101024", // delta: 1024 bytes in 1s -> 1024 B/s
    "net_tx_bytes\t52048"   // delta: 2048 bytes in 1s -> 2048 B/s
  ].join("\n");

  const s2 = Model.parseStats(raw2, s1, 2000);
  assert.strictEqual(s2.cpuPercent, 80);
  assert.strictEqual(s2.cores[0].percent, 90);
  assert.strictEqual(s2.cores[1].percent, 50);
  assert.strictEqual(s2.rxSpeed, 1024);
  assert.strictEqual(s2.txSpeed, 2048);
});

test("Model.parseStats truncates oversized inputs (>8KB)", () => {
  const hugePadding = "dummy_key\t" + "A".repeat(20000) + "\n";
  const raw = "cpu_idle\t500\ncpu_total\t1000\n" + hugePadding;
  const s = Model.parseStats(raw, null, 1000);
  assert.strictEqual(s.cpuIdle, 500);
  assert.strictEqual(s.cpuTotal, 1000);
});

test("Model.parseStats truncates lines beyond 128 lines", () => {
  let lines = [];
  for (let i = 0; i < 200; i++) {
    lines.push(`key_${i}\tval_${i}`);
  }
  lines.push("cpu_model\tShouldNotBeReachedIfPast128");
  const raw = lines.join("\n");
  const s = Model.parseStats(raw, null, 1000);
  assert.notStrictEqual(s.cpuModel, "ShouldNotBeReachedIfPast128");
});

test("Model.parseStats strictly caps cores to at most 64", () => {
  let lines = [];
  for (let i = 0; i < 120; i++) {
    lines.push(`core_${i}\t100\t1000`);
  }
  const raw = lines.join("\n");
  const s = Model.parseStats(raw, null, 1000);
  assert.ok(s.coreCount <= 64, `coreCount was ${s.coreCount}`);
  assert.strictEqual(s.cores.length, 64);
  assert.strictEqual(s.cores[0].label, "C1");
  assert.strictEqual(s.cores[63].label, "C64");
});

test("Model.parseStats sanitizes and truncates strings and strips control characters", () => {
  const raw = [
    "cpu_model\t" + "M".repeat(100),
    "net_iface\t" + "I".repeat(50),
    "load_1m\t" + "1".repeat(30),
    "uptime\t" + "U".repeat(50),
    "cpu_temp\t" + "T".repeat(30) + "\x00\x1f\r\n"
  ].join("\n");

  const s = Model.parseStats(raw, null, 1000);
  assert.strictEqual(s.cpuModel.length, 64);
  assert.strictEqual(s.netIface.length, 32);
  assert.strictEqual(s.load1.length, 16);
  assert.strictEqual(s.uptime.length, 32);
  assert.strictEqual(s.cpuTemp.length, 16);
  assert.ok(!s.cpuTemp.includes("\x00"));
});

test("Model.parseStats handles HTML / rich text characters safely", () => {
  const raw = [
    "cpu_model\t<script>alert(1)</script><b>CPU</b>",
    "net_iface\t<iframe src=\"evil.com\">eth0</iframe>",
    "cpu_temp\t<span style=\"color:red\">99C</span>"
  ].join("\n");

  const s = Model.parseStats(raw, null, 1000);
  assert.strictEqual(s.cpuModel, "<script>alert(1)</script><b>CPU</b>".slice(0, 64));
  assert.strictEqual(s.netIface, "<iframe src=\"evil.com\">eth0</ifr");
  assert.strictEqual(s.cpuTemp, "<span style=\"col");
});

test("Model.parseStats handles malformed lines, out-of-order cores, and bad types gracefully", () => {
  assert.doesNotThrow(() => Model.parseStats(null));
  assert.doesNotThrow(() => Model.parseStats(undefined));
  assert.doesNotThrow(() => Model.parseStats(12345));
  assert.doesNotThrow(() => Model.parseStats({}));
  assert.doesNotThrow(() => Model.parseStats("\t\n\t\n\t\t\t\ncore_invalid\t\t\nload_1m\tNaN"));

  const rawOutOfOrder = [
    "core_3\t10\t100",
    "core_1\t20\t100",
    "core_0\t30\t100",
    "core_-5\t0\t100",
    "core_999\t0\t100"
  ].join("\n");

  const s = Model.parseStats(rawOutOfOrder, null, 1000);
  assert.strictEqual(s.coreCount, 3);
  assert.strictEqual(s.cores[0].id, "0");
  assert.strictEqual(s.cores[1].id, "1");
  assert.strictEqual(s.cores[2].id, "3");
});

test("Formatting helpers format numbers cleanly and handle edge cases", () => {
  assert.strictEqual(Model.formatSpeed(0), "0 KB/s");
  assert.strictEqual(Model.formatSpeed(-10), "0 KB/s");
  assert.strictEqual(Model.formatSpeed(NaN), "0 KB/s");
  assert.strictEqual(Model.formatSpeed(Infinity), "0 KB/s");
  assert.strictEqual(Model.formatSpeed(500), "<1 KB/s");
  assert.strictEqual(Model.formatSpeed(1024), "1.0 KB/s");
  assert.strictEqual(Model.formatSpeed(1024 * 1024), "1.0 MB/s");
  assert.strictEqual(Model.formatSpeed(1024 * 1024 * 1024 * 2.5), "2.50 GB/s");

  assert.strictEqual(Model.formatSpeedCompact(0), "0K/s");
  assert.strictEqual(Model.formatSpeedCompact(500), "<1K/s");
  assert.strictEqual(Model.formatSpeedCompact(1024 * 1024 * 5), "5.0M/s");

  assert.strictEqual(Model.formatBytes(0), "0 KB");
  assert.strictEqual(Model.formatBytes(500), "<1 KB");
  assert.strictEqual(Model.formatBytes(1024 * 1024 * 10), "10.0 MB");

  assert.strictEqual(Model.formatKb(0), "0 MB");
  assert.strictEqual(Model.formatKb(1024 * 1024 * 2), "2.0 GB");
});

test("Producer script stats.sh produces bounded output and runs quickly", () => {
  const scriptPath = path.join(__dirname, "stats.sh");
  const start = Date.now();
  const output = execSync(`bash "${scriptPath}"`, { timeout: 2000 }).toString();
  const duration = Date.now() - start;

  assert.ok(duration < 2000, `stats.sh took too long: ${duration}ms`);
  assert.ok(Buffer.byteLength(output) <= 8192, `stats.sh output > 8KB: ${Buffer.byteLength(output)} bytes`);

  const lines = output.trim().split("\n");
  assert.ok(lines.length <= 128, `stats.sh lines > 128: ${lines.length}`);

  const parsed = Model.parseStats(output, null, Date.now());
  assert.ok(parsed.coreCount <= 64, `parsed coreCount > 64: ${parsed.coreCount}`);
  assert.ok(parsed.cpuModel.length <= 64, `cpuModel length > 64: ${parsed.cpuModel.length}`);
  assert.ok(parsed.netIface.length <= 32, `netIface length > 32: ${parsed.netIface.length}`);
});

test("BarWidget.qml contains watchdog timer and explicit PlainText on all Text components", () => {
  const qmlPath = path.join(__dirname, "BarWidget.qml");
  const content = fs.readFileSync(qmlPath, "utf8");

  // Check watchdog
  assert.ok(content.includes("interval: 2000"), "Watchdog timer must have 2000ms interval");
  assert.ok(content.includes("running: statsProc.running"), "Watchdog timer must track statsProc.running");
  assert.ok(content.includes("statsProc.running = false"), "Watchdog must terminate statsProc");

  // Check Text elements for PlainText
  const textBlocks = content.split(/\bText\s*\{/g).slice(1);
  assert.ok(textBlocks.length > 0, "Should have Text elements");

  for (let i = 0; i < textBlocks.length; i++) {
    const block = textBlocks[i].split("}")[0];
    assert.ok(
      block.includes("textFormat: Text.PlainText"),
      `Text element #${i + 1} is missing textFormat: Text.PlainText:\n${block}`
    );
  }
});

test("Model.parseStats handles high core counts (>64, 128, 256 cores) and sparse/hotplug cores", () => {
  // 1. 256 cores in input
  const lines = ["cpu_idle\t1000\ncpu_total\t10000"];
  for (let i = 0; i < 256; i++) {
    lines.push(`core_${i}\t${100 + i}\t${1000 + i * 2}`);
  }
  const s1 = Model.parseStats(lines.join("\n"), null, 1000);
  assert.strictEqual(s1.coreCount, 64);
  assert.strictEqual(s1.cores.length, 64);
  assert.strictEqual(s1.cores[0].id, "0");
  assert.strictEqual(s1.cores[63].id, "63");

  // 2. Sparse / out of order cores (e.g. core_0, core_4, core_128)
  const sparseLines = [
    "cpu_idle\t1100\ncpu_total\t11000",
    "core_4\t200\t2000",
    "core_0\t150\t1500",
    "core_128\t500\t5000" // should be ignored (>64)
  ];
  const sSparse = Model.parseStats(sparseLines.join("\n"), null, 1000);
  assert.strictEqual(sSparse.coreCount, 2);
  assert.strictEqual(sSparse.cores[0].id, "0");
  assert.strictEqual(sSparse.cores[0].label, "C1");
  assert.strictEqual(sSparse.cores[1].id, "4");
  assert.strictEqual(sSparse.cores[1].label, "C5");

  // 3. Dynamic core hotplugging between ticks
  const tick1 = "cpu_idle\t100\ncpu_total\t1000\ncore_0\t10\t100\ncore_1\t10\t100\ncore_2\t10\t100\n";
  const st1 = Model.parseStats(tick1, null, 1000);
  assert.strictEqual(st1.coreCount, 3);

  // Core 1 goes offline in tick 2
  const tick2 = "cpu_idle\t110\ncpu_total\t1100\ncore_0\t15\t110\ncore_2\t15\t110\n";
  const st2 = Model.parseStats(tick2, st1, 2000);
  assert.strictEqual(st2.coreCount, 2);
  assert.strictEqual(st2.cores[0].id, "0");
  assert.strictEqual(st2.cores[0].percent, 50);
  assert.strictEqual(st2.cores[1].id, "2");
  assert.strictEqual(st2.cores[1].percent, 50);
});

test("Model.parseStats preserves existing valid metrics on empty or partial inputs and recovers deltas", () => {
  const initial = [
    "cpu_idle\t3000\ncpu_total\t10000",
    "core_0\t300\t1000",
    "core_1\t400\t1000",
    "mem_total_kb\t16000000",
    "mem_used_kb\t8000000",
    "mem_avail_kb\t8000000",
    "mem_percent\t50.0",
    "swap_total_kb\t4000000",
    "swap_used_kb\t1000000",
    "swap_percent\t25.0",
    "net_rx_bytes\t100000",
    "net_tx_bytes\t50000",
    "net_iface\twlp2s0",
    "load_1m\t1.20",
    "load_5m\t1.10",
    "load_15m\t0.95",
    "uptime\t2d 4h 10m",
    "cpu_model\tIntel Core i7",
    "cpu_temp\t42°C"
  ].join("\n");

  const s1 = Model.parseStats(initial, null, 1000);
  assert.strictEqual(s1.memPercent, 50);
  assert.strictEqual(s1.cpuModel, "Intel Core i7");
  assert.strictEqual(s1.coreCount, 2);

  // Subprocess timed out / returned empty string
  const sEmpty = Model.parseStats("", s1, 2000);
  assert.strictEqual(sEmpty.memPercent, 50);
  assert.strictEqual(sEmpty.memTotalKb, 16000000);
  assert.strictEqual(sEmpty.cpuModel, "Intel Core i7");
  assert.strictEqual(sEmpty.netIface, "wlp2s0");
  assert.strictEqual(sEmpty.uptime, "2d 4h 10m");
  assert.strictEqual(sEmpty.coreCount, 2, "Cores should be preserved on empty tick");
  assert.strictEqual(sEmpty.cores.length, 2);

  // Recovery tick: should compute deltas against s1's counters preserved in sEmpty
  const recoveryRaw = [
    "cpu_idle\t3100\ncpu_total\t11000", // delta: total=1000, idle=100 -> 90%
    "core_0\t310\t1100", // delta: total=100, idle=10 -> 90%
    "core_1\t450\t1100", // delta: total=100, idle=50 -> 50%
    "mem_total_kb\t16000000",
    "mem_used_kb\t8000000"
  ].join("\n");
  const s3 = Model.parseStats(recoveryRaw, sEmpty, 3000);
  assert.strictEqual(s3.cpuPercent, 90);
  assert.strictEqual(s3.cores[0].percent, 90);
  assert.strictEqual(s3.cores[1].percent, 50);
});

test("Model.parseStats preserves state when keys contain empty/whitespace values", () => {
  const s1 = Model.parseStats([
    "cpu_model\tAMD Ryzen 9 7950X",
    "net_iface\twlp58s0",
    "uptime\t5d 12h 30m",
    "load_1m\t0.50",
    "cpu_temp\t45°C"
  ].join("\n"), null, 1000);

  assert.strictEqual(s1.cpuModel, "AMD Ryzen 9 7950X");
  assert.strictEqual(s1.netIface, "wlp58s0");

  const s2 = Model.parseStats([
    "cpu_model\t   ",
    "net_iface\t",
    "uptime\t  \t  ",
    "cpu_temp\t"
  ].join("\n"), s1, 2000);

  assert.strictEqual(s2.cpuModel, "AMD Ryzen 9 7950X", "Should keep previous cpuModel on empty key");
  assert.strictEqual(s2.netIface, "wlp58s0", "Should keep previous netIface on empty key");
  assert.strictEqual(s2.uptime, "5d 12h 30m", "Should keep previous uptime on empty key");
  assert.strictEqual(s2.cpuTemp, "45°C", "Should keep previous cpuTemp on empty key");
});

test("Model.parseStats calculates fallback memory and swap percentages if missing", () => {
  const raw = [
    "mem_total_kb\t20000000",
    "mem_used_kb\t5000000",
    "swap_total_kb\t10000000",
    "swap_used_kb\t2500000"
  ].join("\n");

  const s = Model.parseStats(raw, null, 1000);
  assert.strictEqual(s.memPercent, 25);
  assert.strictEqual(s.swapPercent, 25);
});

test("Producer awk bounds correctly cap 256-core /proc/stat and compact /proc/net/dev", () => {
  // Test awk core capping logic on simulated 256-core proc/stat
  let mockProcStat = "cpu  1000 0 500 8000 100 0 0 0 0 0\n";
  for (let i = 0; i < 256; i++) {
    mockProcStat += `cpu${i} 100 0 50 800 10 0 0 0 0 0\n`;
  }

  const awkCpuCmd = `awk '
    /^cpu / {
      idle = $5 + $6
      total = 0
      for (i = 2; i <= NF; i++) total += $i
      printf "cpu_idle\\t%s\\ncpu_total\\t%s\\n", idle, total
    }
    /^cpu[0-9]+/ {
      c_num = substr($1, 4) + 0
      if (core_count < 64 && c_num < 64) {
        core_count++
        c_idle = $5 + $6
        c_total = 0
        for (i = 2; i <= NF; i++) c_total += $i
        printf "core_%d\\t%s\\t%s\\n", c_num, c_idle, c_total
      }
    }
  '`;

  const cpuOutput = execSync(awkCpuCmd, { input: mockProcStat }).toString();
  const coreMatches = cpuOutput.match(/core_\d+/g) || [];
  assert.strictEqual(coreMatches.length, 64);
  assert.ok(!cpuOutput.includes("core_64"));

  // Test awk netdev parsing with compact colons
  const mockNetDev = [
    "Inter-|   Receive                                                |  Transmit",
    " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed",
    "    lo:1000 1 0 0 0 0 0 0 1000 1 0 0 0 0 0 0",
    "enp0s31f6:5000 10 0 0 0 0 0 0 6000 12 0 0 0 0 0 0"
  ].join("\n");

  const awkNetCmd = `awk '
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
      printf "net_rx_bytes\\t%.0f\\nnet_tx_bytes\\t%.0f\\nnet_iface\\t%s\\n", (rx ? rx : 0), (tx ? tx : 0), substr(active, 1, 32)
    }
  '`;

  const netOutput = execSync(awkNetCmd, { input: mockNetDev }).toString();
  assert.ok(netOutput.includes("net_rx_bytes\t5000"));
  assert.ok(netOutput.includes("net_tx_bytes\t6000"));
  assert.ok(netOutput.includes("net_iface\tenp0s31f6"));
});

test("Producer extracts CPU model across x86, ARM, and RISC-V formats including strings with colons", () => {
  const awkCmd = `awk '/^(model name|Model|Hardware|Processor)[ \\t]*:/ { sub(/^[^:]*:[ \\t]*/, ""); print "cpu_model\\t" substr($0, 1, 64); exit }'`;

  const x86Input = "processor\t: 0\nmodel name\t: Intel(R) Core(TM) i7-8665U CPU @ 1.90GHz\n";
  const armPiInput = "processor\t: 0\nModel\t\t: Raspberry Pi 4 Model B Rev 1.4\n";
  const armProcInput = "Processor\t: ARMv8 Processor rev 0 (v8l)\n";
  const colonModelInput = "processor\t: 0\nmodel name\t: Intel(R) Core(TM) i9-13900K: Special Edition @ 5.80GHz\n";

  const x86Out = execSync(awkCmd, { input: x86Input }).toString().trim();
  const armPiOut = execSync(awkCmd, { input: armPiInput }).toString().trim();
  const armProcOut = execSync(awkCmd, { input: armProcInput }).toString().trim();
  const colonModelOut = execSync(awkCmd, { input: colonModelInput }).toString().trim();

  assert.strictEqual(x86Out, "cpu_model\tIntel(R) Core(TM) i7-8665U CPU @ 1.90GHz");
  assert.strictEqual(armPiOut, "cpu_model\tRaspberry Pi 4 Model B Rev 1.4");
  assert.strictEqual(armProcOut, "cpu_model\tARMv8 Processor rev 0 (v8l)");
  assert.strictEqual(colonModelOut, "cpu_model\tIntel(R) Core(TM) i9-13900K: Special Edition @ 5.80GHz");
});

test("Model.safeNumber correctly handles edge cases, empty strings, and fallbacks", () => {
  assert.strictEqual(Model.safeNumber(null, 42), 42);
  assert.strictEqual(Model.safeNumber(undefined, 42), 42);
  assert.strictEqual(Model.safeNumber("", 42), 42);
  assert.strictEqual(Model.safeNumber("   ", 42), 42);
  assert.strictEqual(Model.safeNumber(NaN, 42), 42);
  assert.strictEqual(Model.safeNumber(Infinity, 42), 42);
  assert.strictEqual(Model.safeNumber(-Infinity, 42), 42);
  assert.strictEqual(Model.safeNumber("invalid", 42), 42);
  assert.strictEqual(Model.safeNumber(0, 42), 0);
  assert.strictEqual(Model.safeNumber("0", 42), 0);
  assert.strictEqual(Model.safeNumber(123.45, 42), 123.45);
  assert.strictEqual(Model.safeNumber("123.45", 42), 123.45);
});

test("Model.parseStats preserves numeric metrics when keys contain empty/whitespace values", () => {
  const initial = [
    "cpu_idle\t3000\ncpu_total\t10000",
    "mem_total_kb\t16000000",
    "mem_used_kb\t8000000",
    "mem_avail_kb\t8000000",
    "swap_total_kb\t4000000",
    "swap_used_kb\t1000000",
    "net_rx_bytes\t100000",
    "net_tx_bytes\t50000"
  ].join("\n");

  const s1 = Model.parseStats(initial, null, 1000);
  assert.strictEqual(s1.memTotalKb, 16000000);
  assert.strictEqual(s1.memUsedKb, 8000000);
  assert.strictEqual(s1.memAvailKb, 8000000);
  assert.strictEqual(s1.swapTotalKb, 4000000);
  assert.strictEqual(s1.swapUsedKb, 1000000);
  assert.strictEqual(s1.netRxBytes, 100000);
  assert.strictEqual(s1.netTxBytes, 50000);

  // Send empty / whitespace values for numeric keys
  const emptyKeysRaw = [
    "cpu_idle\t   ",
    "cpu_total\t",
    "mem_total_kb\t ",
    "mem_used_kb\t\t",
    "mem_avail_kb\t",
    "swap_total_kb\t   ",
    "swap_used_kb\t",
    "net_rx_bytes\t",
    "net_tx_bytes\t "
  ].join("\n");

  const s2 = Model.parseStats(emptyKeysRaw, s1, 2000);
  assert.strictEqual(s2.memTotalKb, 16000000, "memTotalKb preserved on empty key");
  assert.strictEqual(s2.memUsedKb, 8000000, "memUsedKb preserved on empty key");
  assert.strictEqual(s2.memAvailKb, 8000000, "memAvailKb preserved on empty key");
  assert.strictEqual(s2.swapTotalKb, 4000000, "swapTotalKb preserved on empty key");
  assert.strictEqual(s2.swapUsedKb, 1000000, "swapUsedKb preserved on empty key");
  assert.strictEqual(s2.netRxBytes, 100000, "netRxBytes preserved on empty key");
  assert.strictEqual(s2.netTxBytes, 50000, "netTxBytes preserved on empty key");
  assert.strictEqual(s2.cpuIdle, 3000, "cpuIdle preserved on empty key");
  assert.strictEqual(s2.cpuTotal, 10000, "cpuTotal preserved on empty key");
});

test("Model.parseStats ignores corrupted core lines without injecting bogus entries", () => {
  const initial = [
    "core_0\t100\t1000",
    "core_1\t200\t1000"
  ].join("\n");

  const s1 = Model.parseStats(initial, null, 1000);
  assert.strictEqual(s1.coreCount, 2);

  const corruptedRaw = [
    "core_0\tbad\tvalues",
    "core_1\t\n",
    "core_2\t-50\t-100",
    "core_3\t100\t1000"
  ].join("\n");

  const s2 = Model.parseStats(corruptedRaw, null, 2000);
  assert.strictEqual(s2.coreCount, 1, "Only valid core_3 should be parsed");
  assert.strictEqual(s2.cores[0].id, "3");
});

test("Model.parseStats parses disk metrics and calculates percent", () => {
  const raw = [
    "disk_total_kb\t100000000",
    "disk_used_kb\t40000000",
    "disk_avail_kb\t60000000",
    "disk_percent\t40",
    "disk_mount\t/home"
  ].join("\n");

  const s = Model.parseStats(raw, null, 1000);
  assert.strictEqual(s.diskTotalKb, 100000000);
  assert.strictEqual(s.diskUsedKb, 40000000);
  assert.strictEqual(s.diskAvailKb, 60000000);
  assert.strictEqual(s.diskPercent, 40);
  assert.strictEqual(s.diskMount, "/home");
});

test("Model.formatKbCompact formats compact values cleanly", () => {
  assert.strictEqual(Model.formatKbCompact(0), "0M");
  assert.strictEqual(Model.formatKbCompact(-10), "0M");
  assert.strictEqual(Model.formatKbCompact(500 * 1024), "500M");
  assert.strictEqual(Model.formatKbCompact(68 * 1024 * 1024), "68G");
  assert.strictEqual(Model.formatKbCompact(120 * 1024 * 1024), "120G");
});

test("Model.parseOrder correctly parses arrays, strings, and fallbacks", () => {
  const d = ["cpu", "memory", "storage", "network"];
  assert.deepStrictEqual(Model.parseOrder(["storage", "cpu"], d), ["storage", "cpu"]);
  assert.deepStrictEqual(Model.parseOrder(["STORAGE", " CPU ", "NET"], d), ["storage", "cpu", "net"]);
  assert.deepStrictEqual(Model.parseOrder("storage, cpu, ram, net", d), ["storage", "cpu", "ram", "net"]);
  assert.deepStrictEqual(Model.parseOrder("  storage ,  cpu  ", d), ["storage", "cpu"]);
  assert.deepStrictEqual(Model.parseOrder(null, d), d);
  assert.deepStrictEqual(Model.parseOrder(undefined, d), d);
  assert.deepStrictEqual(Model.parseOrder("", d), d);
  assert.deepStrictEqual(Model.parseOrder([], d), d);
});

test("Model.parseStats parses GPU metrics accurately", () => {
  const raw = [
    "gpu_percent\t35",
    "gpu_temp\t58°C",
    "gpu_mem_used_mb\t2048",
    "gpu_mem_total_mb\t8192",
    "gpu_name\tNVIDIA GeForce RTX 3080"
  ].join("\n");

  const s = Model.parseStats(raw, null, 1000);
  assert.strictEqual(s.gpuPercent, 35);
  assert.strictEqual(s.gpuTemp, "58°C");
  assert.strictEqual(s.gpuMemUsedMb, 2048);
  assert.strictEqual(s.gpuMemTotalMb, 8192);
  assert.strictEqual(s.gpuName, "NVIDIA GeForce RTX 3080");
});

test("Model.createInitialState includes default GPU fields", () => {
  const init = Model.createInitialState();
  assert.strictEqual(init.gpuPercent, 0);
  assert.strictEqual(init.gpuTemp, "");
  assert.strictEqual(init.gpuMemUsedMb, 0);
  assert.strictEqual(init.gpuMemTotalMb, 0);
  assert.strictEqual(init.gpuName, "");
  assert.deepStrictEqual(init.cpuHistory, []);
  assert.deepStrictEqual(init.memHistory, []);
  assert.deepStrictEqual(init.diskHistory, []);
  assert.deepStrictEqual(init.rxHistory, []);
  assert.deepStrictEqual(init.txHistory, []);
  assert.deepStrictEqual(init.gpuHistory, []);
});

test("Model.generateSparkline accurately formats values into sparkline characters", () => {
  assert.strictEqual(Model.generateSparkline([]), "");
  assert.strictEqual(Model.generateSparkline(null), "");
  const spark = Model.generateSparkline([0, 25, 50, 75, 100], 0, 100);
  assert.strictEqual(spark.length, 5);
  assert.strictEqual(spark[0], " ");
  assert.strictEqual(spark[4], "█");
});

test("Model.updateHistory correctly caps array to max points", () => {
  let hist = [];
  for (let i = 1; i <= 25; i++) {
    hist = Model.updateHistory(hist, i, 10);
  }
  assert.strictEqual(hist.length, 10);
  assert.strictEqual(hist[0], 16);
  assert.strictEqual(hist[9], 25);
});

test("Model.getHistoryHeight returns proportional heights for 5 size tiers", () => {
  assert.strictEqual(Model.getHistoryHeight("micro"), 8);
  assert.strictEqual(Model.getHistoryHeight("small"), 14);
  assert.strictEqual(Model.getHistoryHeight("normal"), 20);
  assert.strictEqual(Model.getHistoryHeight("big"), 30);
  assert.strictEqual(Model.getHistoryHeight("huge"), 40);
  
  // Verify 5x scale relation between huge (40) and micro (8)
  assert.strictEqual(Model.getHistoryHeight("huge"), Model.getHistoryHeight("micro") * 5);
  
  // Fallbacks
  assert.strictEqual(Model.getHistoryHeight(null), 20);
  assert.strictEqual(Model.getHistoryHeight("unknown"), 20);
});

test("Model.parseBandwidthString converts bandwidth strings accurately", () => {
  assert.strictEqual(Model.parseBandwidthString("100M"), 12500000);
  assert.strictEqual(Model.parseBandwidthString("1G"), 125000000);
  assert.strictEqual(Model.parseBandwidthString("500K"), 62500);
  assert.strictEqual(Model.parseBandwidthString("10MB/s"), 10485760);
  assert.strictEqual(Model.parseBandwidthString("1GB/s"), 1073741824);
  assert.strictEqual(Model.parseBandwidthString(""), 0);
  assert.strictEqual(Model.parseBandwidthString(null), 0);
  assert.strictEqual(Model.parseBandwidthString("invalid"), 0);
});

test("Model.resolveNetworkMaxVal computes correct max limits across all modes", () => {
  const history = [1000, 5000, 20000];
  
  // auto: highest in history
  assert.strictEqual(Model.resolveNetworkMaxVal("auto", history, 50000, 1000, "100M", 0), 20000);
  
  // session-peak: highest seen since session start
  assert.strictEqual(Model.resolveNetworkMaxVal("session-peak", history, 50000, 1000, "100M", 0), 50000);
  
  // link-speed: 1000 Mbps = 125,000,000 bytes/sec
  assert.strictEqual(Model.resolveNetworkMaxVal("link-speed", history, 50000, 1000, "100M", 0), 125000000);
  
  // fixed: 100M = 12,500,000 bytes/sec
  assert.strictEqual(Model.resolveNetworkMaxVal("fixed", history, 50000, 1000, "100M", 0), 12500000);
  
  // speedtest: 75,000,000 bytes/sec
  assert.strictEqual(Model.resolveNetworkMaxVal("speedtest", history, 50000, 1000, "100M", 75000000), 75000000);
});

test("Model.parseStats correctly parses link speed and tracks session peaks", () => {
  const raw1 = [
    "net_rx_bytes\t1000000",
    "net_tx_bytes\t500000",
    "net_iface\twlp58s0",
    "net_link_speed_mbps\t866"
  ].join("\n");
  
  const s1 = Model.parseStats(raw1, null, 1000);
  assert.strictEqual(s1.netLinkSpeedMbps, 866);
  assert.strictEqual(s1.sessionPeakRx, 0);

  const raw2 = [
    "net_rx_bytes\t2000000",
    "net_tx_bytes\t1000000",
    "net_iface\twlp58s0",
    "net_link_speed_mbps\t866"
  ].join("\n");
  
  // 1 second later: 1,000,000 bytes/sec
  const s2 = Model.parseStats(raw2, s1, 2000);
  assert.strictEqual(s2.rxSpeed, 1000000);
  assert.strictEqual(s2.sessionPeakRx, 1000000);
  assert.strictEqual(s2.sessionPeakTx, 500000);
});

test("Marketplace Security Review: speedtest.sh is bounded, safe, and adheres to environment constraints", () => {
  const scriptPath = path.join(__dirname, "speedtest.sh");
  assert.ok(fs.existsSync(scriptPath), "speedtest.sh must exist");
  
  const scriptContent = fs.readFileSync(scriptPath, "utf8");
  assert.ok(scriptContent.includes("set -e"), "Must have set -e");
  assert.ok(scriptContent.includes("set -o pipefail"), "Must have set -o pipefail");
  assert.ok(scriptContent.includes("LC_ALL=C"), "Must enforce standard locale LC_ALL=C");
  assert.ok(scriptContent.includes("PATH=/usr/bin:/bin"), "Must specify fixed PATH");
  assert.ok(scriptContent.includes("head -c 1024"), "Must strictly bound output to <= 1024 bytes");
});

test("Marketplace Security Review: BarWidget.qml lifecycle, watchdogs, and 100% PlainText sinks", () => {
  const qmlPath = path.join(__dirname, "BarWidget.qml");
  const content = fs.readFileSync(qmlPath, "utf8");

  // 1. Process watchdogs
  assert.ok(content.includes("id: procWatchdog"), "Must contain procWatchdog for statsProc");
  assert.ok(content.includes("id: speedtestWatchdog"), "Must contain speedtestWatchdog for speedtestProc");
  assert.ok(content.includes("statsProc.running = false"), "Watchdog must be able to cancel statsProc");
  assert.ok(content.includes("speedtestProc.running = false"), "Watchdog must be able to cancel speedtestProc");

  // 2. Component destruction cleanup
  assert.ok(content.includes("Component.onDestruction:"), "Must declare Component.onDestruction");
  assert.ok(
    content.includes("Component.onDestruction:") &&
    content.includes("if (statsProc.running) statsProc.running = false") &&
    content.includes("if (speedtestProc.running) speedtestProc.running = false"),
    "Component.onDestruction must safely stop in-flight child processes"
  );

  // 3. 100% PlainText text sinks
  const textMatches = content.split(/\bText\s*\{/g).slice(1);
  assert.ok(textMatches.length >= 40, `Expected at least 40 Text blocks, found ${textMatches.length}`);

  let missingPlainText = 0;
  for (let i = 0; i < textMatches.length; i++) {
    // Extract up to closing brace of this Text item
    const block = textMatches[i].split("}")[0];
    if (!block.includes("textFormat: Text.PlainText")) {
      missingPlainText++;
      console.error(`Missing PlainText in Text component #${i + 1}:\n${block}`);
    }
  }
  assert.strictEqual(missingPlainText, 0, `All Text blocks in BarWidget.qml must specify textFormat: Text.PlainText`);
});







