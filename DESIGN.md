# DESIGN.md — Code Navigation Map

Two scripts, one `lgc1-wol` base. The `-d` (daemon) variant wraps the plain one
so the TV wakes once per session and once per resume-from-standby.

- `lgc1-wol.py` — one-shot: WoL magic packet + WebOS input switch.
- `lgc1-wold.py` — session daemon: keeps a listener alive for the lifetime of a
  launch chain; on startup and on resume it calls `lgc1-wol.py` (via `wol_path()`).

---

## lgc1-wol.py (one-shot waker)

| Line  | Symbol                          | Role                                                   |
| ----- | ------------------------------- | ------------------------------------------------------ |
| 11-16 | `CFG_*`                         | Config defaults; all overridable via env vars.         |
| 19    | `wol(mac)`                      | Build + broadcast WoL magic packet (UDP/9).            |
| 26    | `wait_port(ip,port)`            | Poll TV WebSocket port up to 120s (2s steps).          |
| 37    | `class WebSocket`               | Hand-rolled RFC6455 client (no deps).                  |
| 43    | `WebSocket._handshake`          | HTTP upgrade + `101` check.                            |
| 66    | `WebSocket.send`                | Masked client frame (text).                            |
| 84    | `WebSocket.recv`                | Reads one frame; `""` on close/opcode 0x8.             |
| 103   | `WebSocket._read`               | Bounded recv loop.                                     |
| 112   | `WebSocket.close`               | Send close frame, drop socket.                         |
| 119   | `_load_key(path)`               | Read cached `client-key` (missing/corrupt → `""`).     |
| 127   | `_save_key(path,key)`           | Persist `client-key`.                                  |
| 133   | `_register(ws,key)`             | Sends `register` manifest; returns new `client-key`.   |
| 190   | `_ssap_request(ws,uri,payload)` | Single SSAP request/response.                          |
| 196   | `switch_lg_input(...)`          | Register, switch `com.webos.app.<input>`, 401→re-pair. |
| 219   | `parse_args(argv)`              | argparse; `--` strips trailing exec command.           |
| 246   | `main()`                        | WoL → wait → switch input → `os.execvp(cmd)`.          |

Flow: `main` (246) → `wol` (19) → `wait_port` (26) → `switch_lg_input` (196)
→ `WebSocket` ctor + `_register` (133) → `_ssap_request` (190). Optional
`os.execvp` runs the trailing `-- cmd`.

---

## lgc1-wold.py (session daemon)

| Line  | Symbol                       | Role                                                                                                                           |
| ----- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ----------- | ----- |
| 22-27 | `GRACE`/`MIN_INTERVAL`/`LOG` | Tunables; log path via `LG_WOL_LOG`.                                                                                           |
| 30    | `rotate_logs(path)`          | Keep 3 backups per session start.                                                                                              |
| 48    | `log(msg)`                   | Append stderr-free timestamped line.                                                                                           |
| 58    | `sock_path()`                | Unix datagram socket; `LG_WOL_SOCK` overrides.                                                                                 |
| 63    | `wol_path()`                 | Absolute path to sibling `lgc1-wol.py`.                                                                                        |
| 67    | `spawn_dbus()`               | `dbus-monitor` for `PrepareForSleep` (override `LG_WOL_DBUS_CMD`).                                                             |
| 87    | `daemon(parent,sock,wol)`    | Main loop; dies when `parent_pid` exits.                                                                                       |
| 93    | `do_wake()`                  | Debounced wake: sleeps `GRACE`, execs `wol`.                                                                                   |
| 110   | `cleanup()`                  | Unlink socket.                                                                                                                 |
| 142   | `on_resume(how)`             | On resume → `sendto(b"wake", sock)`.                                                                                           |
| 148   | loop                         | `select` on socket + dbus; clock-gap → resume; poke → `do_wake`.                                                               |
| 203   | `wrapper(chain)`             | Detached `--_listen` spawn, blocks on the poke until the switch completes, then `os.execvp(chain)` (aborts if the wake fails). |
| 222   | `poke()`                     | Manual wake; blocks until switch completes (daemon acks back).                                                                 |
| 230   | `main()`                     | Dispatch: `poke`                                                                                                               | `--_listen` | `--`. |

Entry points:

- `lgc1-wold.py -- <cmd>` → `wrapper` (203) → blocks until the TV switches
  inputs, then execs `<cmd>`; listener lives for its lifetime (used as a Steam
  wrapper in `bazzified-steam.sh`).
- `lgc1-wold.py poke` → `poke` (222) manual/testing wake.
- `lgc1-wold.py --_listen <pid> <sock> <wol>` → internal `daemon`.

---

## Connection between the two

`lgc1-wold.py` never sends WoL itself — it shells out to `lgc1-wol.py`
(`wol_path()`, line 63) for every actual wake. The daemon owns _timing and
triggers_ (startup poke, dbus resume, clock-gap resume); `lgc1-wol.py` owns the
_TV protocol_.

```
bazzified-steam.sh ──> lgc1-wold.py -- (wrapper)
                          └─ spawned listener (daemon)
                               ├─ startup  ─sendto─> wake ─> lgc1-wol.py  (TV on)
                               ├─ resume   ─sendto─> wake ─> lgc1-wol.py  (TV on)
                               └─ poke     ─sendto─> wake ─> lgc1-wol.py  (TV on)
```

Triggers map: socket `wake` (manual/`poke`/startup) → `do_wake` (93);
`PrepareForSleep=false` (dbus) or loop clock-gap → `on_resume` (142) → socket.

## Tuning knobs (env)

`LG_WOL_SOCK`, `LG_WOL_LOG`, `LG_WOL_DEBUG`, `LG_WOL_DBUS_CMD`,
`LGC1_WOLD_POKE_ON_STARTUP=0` (disable startup wake).
