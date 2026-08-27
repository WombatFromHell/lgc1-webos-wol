# lgc1-webos-wol

Wake an LG TV via WoL and switch its input using the WebSocket SSAP protocol.

Two scripts ship together: `lgc1-wol.py` (one-shot wake + input switch) and
`lgc1-wold.py` (session daemon that wakes the TV on startup and resume from
standby). See `DESIGN.md` for the code map.

## Usage

```sh
# default: 192.168.1.154, HDMI-1
uv run lgc1-wol.py

# override everything
uv run lgc1-wol.py --ip 10.0.0.5 --mac aa:bb:cc:dd:ee:ff --input hdmi2

# or use env vars
TV_IP=10.0.0.5 TV_MAC=aa:bb:cc:dd:ee:ff TV_INPUT=hdmi2 uv run lgc1-wol.py

# wrapper mode: wake TV, switch input, then exec the command
uv run lgc1-wol.py -- mpv --vo=gpu 'http://10.0.0.5:8080/stream'
```

Edit defaults in the `# --- Configuration` block at the top of `lgc1-wol.py`, or skip the file entirely with env vars / `--flags`. Run `--help` for all options.

### Session daemon (`lgc1-wold.py`)

`lgc1-wold.py` wraps a launch chain so the TV wakes at session start and every
time the machine resumes from suspend. The listener is spawned detached and dies
with the chain.

```sh
# wake TV and wait for the input to switch, then run the command
lgc1-wold.py -- steam -tenfoot

# manual wake — blocks until the TV finishes switching inputs
lgc1-wold.py poke
```

```sh
# in ~/.local/bin/scripts/bazzified-steam.sh (nested, LG C1 connected)
WRAPPERS+=("$HOME/.local/bin/scripts/lgc1-wold.py --")
```

It expects `lgc1-wold.py` (and `lgc1-wol.py`) installed at
`~/.local/bin/scripts/` — see Install below. Tuning knobs: `LG_WOL_SOCK`,
`LG_WOL_LOG`, `LG_WOL_DEBUG`, `LG_WOL_DBUS_CMD`, `LGC1_WOLD_POKE_ON_STARTUP=0`.

## Install

`install.sh` copies `lgc1-wol*.py` into `~/.local/bin/scripts/` (mode 0755):

```sh
./install.sh
```

## First run

The TV will show a pairing prompt — accept it. A `client-key` is cached to `~/.cache/.lg-tv-key.json` for subsequent silent runs. Delete that file to re-pair.

## How it works

1. Sends a WoL magic packet to the TV's MAC
2. Polls the TV's WebSocket port (3000) until it's open
3. Connects via raw WebSocket and registers with a full `lgtv2`-style manifest
4. Sends `ssap://system.launcher/launch` with `com.webos.app.<input>` (e.g. `hdmi1`)
5. Caches the `client-key` from registration; auto-deletes and re-pairs if the TV rejects it (401)

Zero dependencies outside the Python stdlib and `ruff` (dev only).

## Build & dev (Nix)

The flake produces a bitwise-deterministic release zip (`lgc1-wol*.py`,
`install.sh`, `LICENSE`, `README.md`) via `flake.nix` + `Makefile`.

```sh
# Enter the dev shell (direnv auto-activates if configured)
nix develop        # or: direnv allow

# Local deterministic build (uses this shell / uv venv)
make build         # -> dist/lgc1-webos-wol-<version>.zip (+ .sha256)

# Reproducible Nix build (no host-python dependency)
make build-nix     # -> dist/lgc1-webos-wol-<version>.zip via `nix build`

# Clean build artifacts
make clean

# Lint + format (ty, ruff, pyright)
make lint
make format
make quality       # lint + format
```

Version is sourced from `pyproject.toml`; Python version from `.python-version`.

## Dev shell (Nix)

```sh
nix develop
```
