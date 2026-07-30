# androidtv-wol

Wake an LG TV via WoL and switch its input using the WebSocket SSAP protocol.

## Usage

```sh
# default: 192.168.1.154, HDMI-1
uv run lgc1-wol.py

# override everything
uv run lgc1-wol.py --ip 10.0.0.5 --mac aa:bb:cc:dd:ee:ff --input hdmi2

# or use env vars
TV_IP=10.0.0.5 TV_MAC=aa:bb:cc:dd:ee:ff TV_INPUT=hdmi2 uv run lgc1-wol.py
```

Edit defaults in the `# --- Configuration` block at the top of `lgc1-wol.py`, or skip the file entirely with env vars / `--flags`. Run `--help` for all options.

## First run

The TV will show a pairing prompt — accept it. A `client-key` is cached to `~/.cache/.lg-tv-key.json` for subsequent silent runs. Delete that file to re-pair.

## How it works

1. Sends a WoL magic packet to the TV's MAC
2. Polls the TV's WebSocket port (3000) until it's open
3. Connects via raw WebSocket and registers with a full `lgtv2`-style manifest
4. Sends `ssap://system.launcher/launch` with `com.webos.app.<input>` (e.g. `hdmi1`)
5. Caches the `client-key` from registration; auto-deletes and re-pairs if the TV rejects it (401)

Zero dependencies outside the Python stdlib and `ruff` (dev only).

## Dev shell (Nix)

```sh
nix develop
```
