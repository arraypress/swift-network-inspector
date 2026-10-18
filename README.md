# swift-network-inspector

This Mac's network as data, from Swift and without root: bandwidth per process and per app, every listening socket with its owner and who can reach it, the Wi-Fi link and the channels around it, and macOS's own speed test.

```swift
import NetworkInspector

let window = try Bandwidth.measure(seconds: 1)        // nettop, two samples a second apart
window.apps.first?.name                                // "Google Chrome" — helpers summed in
window.apps.first?.inPerSecond                         // bytes per second

let ports = try Ports.report()                         // every user's listeners, root's included
ports.ports.filter { $0.reach.isExposed }              // bound beyond 127.0.0.1 / ::1
try Ports.report(port: 3000).ports.first?.process     // who is using port 3000

let wifi = try WiFi.status()                           // rssi, noise, snr, channel, mode, security
wifi.quality                                           // .good
try WiFi.scan().advice.advice                          // "channel 153 (5 GHz, 80 MHz) overlaps no other network"

let speed = try SpeedTest.run()                        // networkQuality -c: real traffic, ~20 s
speed.rating                                           // .low / .medium / .high, by networkQuality's own thresholds
```

The `net` CLI is the front end. `mac net` (swift-machine-info) lists the interfaces and their addresses; this library goes past them.

## Where each answer comes from

| Question | Source | Why that one |
|---|---|---|
| Bytes per process | `nettop -P -L 0 -x -J time,bytes_in,bytes_out` | The only public per-process byte counts on macOS; the NetworkStatistics framework it reads is private. It sees every process, root's included, without root. |
| Listening sockets | `netstat -anvl`, else nettop's socket listing joined with `lsof` | See *The netstat trap* below. |
| Who a pid is | `proc_pidpath`, the `kern.proc.pid` sysctl, the enclosing `.app` | Both answer for root's processes without root; `proc_name` and `proc_pidinfo` refuse other users' with EPERM. |
| The Wi-Fi link and scan | CoreWLAN | `airport` is gone; `wdutil` needs sudo. |
| Speed | `networkQuality -c` | macOS's own test, with JSON. |
| Route, DNS, tunnels | SystemConfiguration's dynamic store, `getifaddrs` | |
| Firewall | `socketfilterfw --getglobalstate` and friends | Answers without root, 13 ms each. |

## Measured, not assumed

All on macOS 27.0.1 (a MacBook on Wi-Fi, an ordinary admin user, a VPN up), 2026-10-18.

- **nettop on a pipe takes 4.5 s longer than it needs.** It buffers everything until it exits, and after its last sample it takes about 4.5 s to exit: two one-second samples took 5.0 s. Run on a pseudo-terminal, each line arrives as written, so a sample is used the moment the next header (or 0.35 s of quiet) shows it complete, and SIGTERM ends nettop at once. `Bandwidth.measure(seconds: 1)` returns in about 1.4 s.
- **nettop's counters survive a closed socket.** A process downloaded 3,001,321 bytes and closed the socket; its total stayed at 3,001,321 in the next samples. So the difference between two samples is what moved in the window. A pid first seen in the window counts from zero; one whose counter went down is a reused pid and counts from zero; one that exited inside the window loses its last bytes.
- **nettop's rows are not quoted.** Process names hold dots (Claude Code's binary is called `2.1.302`, so the row reads `2.1.302.5091`) and may hold commas, so the pid is the part after the last dot and the name takes every field beyond the header's count. Columns are found by name in the header, since nettop's help warns that their order may change. Names are cut to 15 characters (`Google Chrome H`); the full name comes from the executable's path.
- **`-s` takes whole seconds.** `-s 0.5` prints nothing.
- **Loopback is excluded by default** (`-t external`). A VPN client moved 2.7 GB each way over loopback here, which is this Mac talking to itself. With a VPN up, its process also carries every app's traffic a second time, encrypted; that is real traffic on the interface and is counted.
- **Helpers belong to their app.** NSRunningApplication answers nil for Chrome's helpers, Dropbox's file-provider extension and a VPN's daemon. Their executables live inside the app (`Google Chrome.app/…/Google Chrome Helper (Aperitif).app/…`), so the outermost `.app` in the path names the app.
- **The rating thresholds are networkQuality's own.** They come from `+[NetworkQualityResult ratingForResponsivenessScore:]` in the private NetworkQuality framework, called for every score from 0 to 5,000: Low up to 200 RPM, Medium from 201 to 1,000, High from 1,001. It takes whole RPM.
- **networkQuality can hang without a word.** Bound to an interface that does not exist (`-I nosuch0`), it printed nothing for over 160 s, and `-M 5` did not bound it either. So `SpeedTest` checks the interface first and stops the run after `timeout` (90 s by default). A run that fails for any other reason exits 0 and prints JSON with `error_code` and `error_domain`, so the error is read from the document.
- **Speed tests cost real data.** Two default runs here: 19.8 s moving 715 MB, and 26.8 s moving 1.15 GB. A sequential run capped with `-M 10` took 10.8 s.
- **CoreWLAN without Location Services**, from a command-line tool whose terminal has no location permission: signal, noise, channel, band, width, PHY mode, transmit rate and security all come back; the SSID, BSSID and country code come back nil. A scan works too, with channels and signal but no names (7 networks in 4.8 s; 5 in 5.0 s on another run). The library never asks for the permission. CoreWLAN's `transmitPower()` read 1496, which as the milliwatts its header promises would be 1.5 W, so it is not reported.

## The netstat trap

`netstat -anvl` reads the kernel's socket tables and prints a pid for every socket. From a shell it lists everyone's sockets, root's included: 13 TCP listeners here, against 11 for an unprivileged `lsof` (the two `lsof` missed were root's `remoted`).

On macOS 27.0.1 the same command lists **no Internet sockets at all** (exit 0, only Unix-domain sockets) when a non-Apple program is among its ancestors. That happened run from Python's `subprocess`, from a compiled Swift binary, and through `/bin/sh` started by either, with or without the agent sandbox. It worked when the shell, `perl` or `env` ran it, or when Python `exec`ed into it. That rules out every way a library or CLI would run it, so `Ports.sockets()` uses netstat only when it actually returns sockets, and otherwise:

1. **nettop's per-socket listing** (`nettop -L 1 -n -x -J state`), which answers from a program like this one and includes root's sockets with their pids. It lists the sockets it has statistics for: all 13 TCP listeners netstat showed, but 15 of 19 UDP listeners, and the four it missed were idle sockets of one process.
2. **joined with `lsof`** for the caller's own processes, which filled exactly those four.
3. **`lsof` alone** when nettop fails. The report then says it is incomplete (`complete == false`) and counts the other users' processes it could not look at (`hiddenProcesses`).

The report's `source` and `notes` say which path was taken. So, without root, the only sockets that can go unseen are idle UDP sockets of other users' processes.

## Reach

`Reach` comes from the address a socket is bound to, which is what decides exposure:

| Bound to | Reach | Exposed |
|---|---|---|
| `127.0.0.0/8`, `::1` | `loopback` | no |
| `fe80::/10`, `169.254.0.0/16` | `link-local` | yes, to the same link |
| one address | `address` (with its interface) | yes, to that interface's network |
| `*`, `0.0.0.0`, `::` | `all` | yes, on every interface, present and future |

The application firewall can still refuse a connection; `Firewall.current()` says whether it is on. A UDP socket bound to a port with no remote end counts as listening; many are clients waiting for replies (mDNS on 5353, DHCP on 68, a VPN's tunnel ports).

## Wi-Fi verdicts and channels

`SignalQuality` is the worse of two rules of thumb, not a measurement of this library's: signal (excellent at -50 dBm and up, good to -67, fair to -75) and signal-to-noise (excellent at 40 dB, good at 25, fair at 15). `ChannelRules` knows which channels share air. On 2.4 GHz that's a 22 MHz mask, so channels within four overlap and 1, 6 and 11 don't. On 5 and 6 GHz a wide channel is a fixed block (80 MHz 149–161, 160 MHz 100–128…), worked out from the primary channel CoreWLAN reports and its width. The Mac's own access point is taken to be the loudest network on exactly its channel; without BSSIDs that is the best available tell.

## Tests

43 tests. The parsers run on real nettop, netstat, lsof and networkQuality output captured on this Mac (in `Tests/…/Fixtures`), with every address replaced by a documentation value (192.0.2.x, 198.51.100.x, 203.0.113.x, 2001:db8::n, fe80::n) and the login name by `me`. Expected counts were worked out from the fixtures separately in Python, not by running the parsers. Edge cases cover names with dots and commas, a socket whose process has exited (`:71051`), IPv6 with zones, wildcards, short and broken rows, a reused pid, and midnight between samples. Live tests stay on this Mac: a loopback listener the test opens is found with its pid and called loopback, and 8 MB the test sends itself over loopback shows up in `Bandwidth.measure(includeLoopback: true)`. Every test was mutation-checked: the code it covers was broken on purpose, the test failed, and the code was restored.

## Layout

`Core/` Bandwidth, Ports, WiFi, SpeedTest, Route, Firewall, ProcessLookup, Interfaces, NettopStream, ToolRunner · `Support/` NettopCSV, NettopSockets, NetstatText, LsofText, EndpointText, TrafficMath, PortMerge, ReachRules, SignalRules, ChannelRules, WiFiNames, SpeedJSON, ResponsivenessRules, FirewallText, AppBundles · `Models/` · `Enums/` · `Errors/` NetworkInspectorError.

## Requirements

macOS 14+, Swift 6.2. No dependencies. Measured on macOS 27.0.1.

## License

MIT — see [LICENSE](LICENSE).
