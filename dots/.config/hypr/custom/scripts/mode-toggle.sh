#!/usr/bin/env bash
# Compatibility wrapper: open the desktop mode selector.

set -euo pipefail

exec qs -c ii ipc call modeSelector toggle
