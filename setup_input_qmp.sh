#!/usr/bin/env bash
# One-shot: add a dedicated input QMP socket to your VM and restart it, so the aimbot/trigger
# can inject mouse input (INPUT_QMP_SOCK). ESP/radar work without this -- it's only needed for
# aim assist and the trigger bot, which have to move the in-game cursor, not just read memory.
#
# Your domain already has one QMP monitor (used by the memory-read side of this tool). QMP
# monitors are single-client, so this adds a SECOND, independent one just for input.
# Needs root: the domain XML is under /etc/libvirt and virsh talks to system libvirt.
#   Run:  sudo bash setup_input_qmp.sh                 (auto-detects your VM if you only have one)
#   Run:  sudo bash setup_input_qmp.sh <YourVMName>     (if you have more than one, or detection fails)
set -euo pipefail

SOCK="/tmp/bc-input-qmp.sock"

[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo bash $0 [DomainName]" >&2; exit 1; }

DOMAIN="${1:-}"
if [[ -z "$DOMAIN" ]]; then
  # No name given -- auto-detect. `virsh list --all --name` prints one domain name per line,
  # with trailing blank lines; grep -v '^$' strips those before counting, same filter used
  # below to actually pick the name, so the count and the pick can never disagree.
  mapfile -t DOMAINS < <(virsh list --all --name | grep -v '^$' || true)
  if [[ ${#DOMAINS[@]} -eq 1 ]]; then
    DOMAIN="${DOMAINS[0]}"
    echo "no VM name given -- found exactly one defined VM, using it: $DOMAIN"
  elif [[ ${#DOMAINS[@]} -eq 0 ]]; then
    echo "no VM name given, and no libvirt domains are defined on this system at all." >&2
    echo "Set up your VM first, then re-run this with its name." >&2
    exit 1
  else
    echo "no VM name given, and more than one is defined -- pick one:" >&2
    printf '  %s\n' "${DOMAINS[@]}" >&2
    echo "Re-run as: sudo bash $0 <name>" >&2
    exit 1
  fi
fi

virsh dominfo "$DOMAIN" >/dev/null || { echo "domain '$DOMAIN' not found (virsh list --all)"; exit 1; }

if virsh dumpxml --inactive "$DOMAIN" | grep -q "bc-input-qmp.sock"; then
  echo "input QMP already present in $DOMAIN — XML left as-is."
else
  TMP="$(mktemp --suffix=.xml)"
  virsh dumpxml --inactive "$DOMAIN" > "$TMP"
  # Inject a second -qmp arg pair right after the <qemu:commandline> open tag.
  python3 - "$TMP" "$SOCK" <<'PY'
import sys
path, sock = sys.argv[1], sys.argv[2]
s = open(path).read()
tag = "<qemu:commandline>"
i = s.find(tag)
if i == -1:
    sys.exit("no <qemu:commandline> block found — is the qemu namespace on <domain>?")
add = ('\n    <qemu:arg value="-qmp"/>'
       '\n    <qemu:arg value="unix:%s,server=on,wait=off"/>' % sock)
j = i + len(tag)
open(path, "w").write(s[:j] + add + s[j:])
print("injected second -qmp ->", sock)
PY
  virsh define "$TMP"
  rm -f "$TMP"
fi

echo "== restarting $DOMAIN (a live reload will NOT add a chardev) =="
if virsh domstate "$DOMAIN" | grep -q running; then
  virsh shutdown "$DOMAIN" || true
  for _ in $(seq 1 30); do virsh domstate "$DOMAIN" | grep -q "shut off" && break; sleep 1; done
  virsh domstate "$DOMAIN" | grep -q "shut off" || { echo "forcing off"; virsh destroy "$DOMAIN" || true; }
fi
virsh start "$DOMAIN"

echo "== waiting for the guest to create $SOCK =="
for _ in $(seq 1 60); do [[ -S "$SOCK" ]] && break; sleep 1; done
if [[ -S "$SOCK" ]]; then
  echo "OK: $SOCK is live. Launch with:"
  echo "    make cap && INPUT_QMP_SOCK=$SOCK ./bluesclues"
else
  echo "FAIL: $SOCK never appeared. Check the guest booted and that the emulator can"
  echo "create /tmp sockets (your barely-metal-qmp.sock is in /tmp, so it should)."
  exit 1
fi
