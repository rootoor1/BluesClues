# Aim assist / trigger bot setup

ESP and radar work immediately, no setup needed. Aim assist and the trigger bot need one
extra step first — they have to move your in-game cursor, not just read memory, and that
needs a dedicated input channel into your VM.

## One-command setup (do this first)

```bash
sudo bash setup_input_qmp.sh
```

If you only have one VM defined, this finds it automatically, adds the input channel, and
restarts the VM for you. If you have more than one VM, it'll list them and ask you to
re-run with the right name:

```bash
sudo bash setup_input_qmp.sh <YourVMName>
```

This fully restarts the VM (required — a live reload can't add this). Give it a minute to
come back up.

## Launching with it enabled

```bash
INPUT_QMP_SOCK=/tmp/bc-input-qmp.sock ./bluesclues
```

If you don't set `INPUT_QMP_SOCK`, the overlay still runs fine — ESP, radar, everything
else works — aim assist and the trigger bot just won't have anything to move. No error, no
crash, they simply stay inactive until the socket is set.

## How to tell it worked

- Startup doesn't print `Mouse injection unavailable`.
- Aim assist actually moves your crosshair when you test it.

## If the one-command setup fails

Most likely cause: your VM isn't managed by `virsh`/libvirt (a hand-rolled QEMU command
line, a different hypervisor, etc.) — the script can't edit a config that doesn't exist in
that form. Add this block manually to your VM's QEMU command line instead:

```
-chardev socket,id=inputqmp,path=/tmp/bc-input-qmp.sock,server=on,wait=off
-mon chardev=inputqmp,mode=control
```

If you *are* on libvirt and it still fails, open an editor on your domain
(`sudo virsh edit <YourVMName>`), confirm the root `<domain>` tag includes
`xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'`, and add this block right before
the closing `</domain>` tag:

```xml
<qemu:commandline>
  <qemu:arg value='-chardev'/>
  <qemu:arg value='socket,id=inputqmp,path=/tmp/bc-input-qmp.sock,server=on,wait=off'/>
  <qemu:arg value='-mon'/>
  <qemu:arg value='chardev=inputqmp,mode=control'/>
</qemu:commandline>
```

Then fully shut down and restart the VM (not a reboot from inside it — stop it from the
host, then start it again).
