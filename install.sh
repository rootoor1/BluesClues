#!/usr/bin/env bash
# FALLBACK ONLY -- you probably don't need this. ./bluesclues grants itself the memory-read
# permission it needs on first launch (a graphical pkexec password prompt pops up once, then
# never again). Run this script yourself only if that self-prompt didn't appear or didn't work
# (no polkit agent running -- common on minimal window managers without a full desktop) and
# the app keeps reporting "guest offline".
# *setcap is on the FILE, not the install -- if you ever replace ./bluesclues with a newer
# build, either self-elevation fires again automatically on its first launch, or re-run this.*
set -e
cd "$(dirname "$0")"
sudo setcap 'cap_sys_ptrace,cap_dac_read_search,cap_dac_override+eip' ./bluesclues
getcap ./bluesclues
echo "done -- run with: ./bluesclues"
