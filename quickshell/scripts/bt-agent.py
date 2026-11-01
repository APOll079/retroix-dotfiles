#!/usr/bin/env python3
"""Bluetooth pairing agent for popups/BluetoothMenu.qml (PIN, passkey, number comparison).

Usage: bt-agent.py          (Quickshell runs it only while the Bluetooth menu is open)
Registers org.bluez.Agent1 at /qs/agent with BlueZ's AgentManager1 as capability KeyboardDisplay
and makes it the default agent (RequestDefaultAgent), so pairings started from our own menu reach
it. While it runs it takes the requests another agent (blueman) would get. It unregisters on every
normal exit (stdin closed, SIGTERM / SIGINT, error); BlueZ also drops the default agent by itself
when the process dies (kill -9), so the previous behaviour comes back either way.
QS_BT_BUS = a D-Bus address to use instead of the system bus (tests use a private bus).

Every BlueZ call becomes one JSON line on stdout:
  {"id": n, "method": M, "device": <object path>, "name": <device alias>, ...}
    M = "pin"            type the PIN the device shows (answer value: string)
        "passkey"        type the 6 digit passkey the device shows (answer value: number or digits)
        "displayPin"     "code": type this PIN on the device (no answer needed)
        "displayPasskey" "code": type these 6 digits on the device (no answer needed)
        "confirm"        "code": do the 6 digits match? (answer ok true = Pair, false = Cancel)
        "authorize"      allow this device to pair (answer ok)
        "service"        "uuid": allow this device to use a service (answer ok)
  {"method": "cancel"}   BlueZ dropped the request: remove the prompt
  {"method": "release"}  BlueZ dropped the agent
The answer is one JSON line on stdin: {"id": n, "ok": true, "value": "1234"} or {"id": n, "ok": false}.
No answer within TIMEOUT seconds, ok false, Cancel, or stdin closing all reject the request
(org.bluez.Error.Rejected). Ends when stdin closes or on SIGTERM; unregisters first.
Standard library + python-dbus + gi.repository.GLib only.
"""
import json
import os
import signal
import sys

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

try:                                    # newer PyGObject moved the Unix signal helper
    from gi.repository import GLibUnix
    signal_add = GLibUnix.signal_add
except ImportError:
    signal_add = GLib.unix_signal_add

AGENT_PATH = "/qs/agent"
AGENT_IFACE = "org.bluez.Agent1"
CAPABILITY = "KeyboardDisplay"
TIMEOUT = int(os.environ.get("QS_BT_TIMEOUT", "60"))   # seconds QML gets to answer

loop = None
bus = None
pending = {}        # id -> (reply, error, timer source id)
next_id = 0
inbuf = b""


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Canceled(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Canceled"


def device_name(path):
    """The device's Alias, or "" when BlueZ can't say (QML falls back to the address)."""
    try:
        obj = bus.get_object("org.bluez", path, introspect=False)
        return str(obj.Get("org.bluez.Device1", "Alias", dbus_interface="org.freedesktop.DBus.Properties", timeout=2))
    except Exception:
        return ""


def finish(req_id, ok, value=None):
    entry = pending.pop(req_id, None)
    if entry is None:
        return
    reply, error, timer, kind = entry
    GLib.source_remove(timer)
    if not ok:
        error(Rejected("Rejected"))
    elif kind == "pin":
        reply(str(value))
    elif kind == "passkey":
        try:
            reply(dbus.UInt32(int(str(value).strip())))
        except ValueError:
            error(Rejected("Rejected"))
    else:
        reply()


def timed_out(req_id):
    finish(req_id, False)
    return False


def ask(method, kind, device, reply, error, **extra):
    """Send one request line; the D-Bus reply waits for the answer line."""
    global next_id
    next_id += 1
    req_id = next_id
    timer = GLib.timeout_add_seconds(TIMEOUT, timed_out, req_id)
    pending[req_id] = (reply, error, timer, kind)
    msg = {"id": req_id, "method": method, "device": str(device), "name": device_name(device)}
    msg.update(extra)
    emit(msg)


def reject_all():
    for req_id in list(pending):
        finish(req_id, False)


class Agent(dbus.service.Object):
    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self):
        reject_all()
        emit({"method": "release"})

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="", async_callbacks=("reply", "error"))
    def AuthorizeService(self, device, uuid, reply, error):
        ask("service", "ok", device, reply, error, uuid=str(uuid))

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="s", async_callbacks=("reply", "error"))
    def RequestPinCode(self, device, reply, error):
        ask("pin", "pin", device, reply, error)

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        emit({"id": 0, "method": "displayPin", "device": str(device), "name": device_name(device), "code": str(pincode)})

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="u", async_callbacks=("reply", "error"))
    def RequestPasskey(self, device, reply, error):
        ask("passkey", "passkey", device, reply, error)

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        emit({"id": 0, "method": "displayPasskey", "device": str(device), "name": device_name(device),
              "code": "%06d" % int(passkey), "entered": int(entered)})

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="", async_callbacks=("reply", "error"))
    def RequestConfirmation(self, device, passkey, reply, error):
        ask("confirm", "ok", device, reply, error, code="%06d" % int(passkey))

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="", async_callbacks=("reply", "error"))
    def RequestAuthorization(self, device, reply, error):
        ask("authorize", "ok", device, reply, error)

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self):
        reject_all()
        emit({"method": "cancel"})


def on_stdin(fd, cond):
    """Read answer lines; end when stdin closes."""
    global inbuf
    if cond & GLib.IO_IN:
        data = os.read(fd, 4096)
        if not data:
            loop.quit()
            return False
        inbuf += data
        while b"\n" in inbuf:
            line, inbuf = inbuf.split(b"\n", 1)
            try:
                ans = json.loads(line)
                finish(ans["id"], bool(ans.get("ok")), ans.get("value"))
            except (ValueError, KeyError, TypeError):
                pass
        return True
    loop.quit()
    return False


def main():
    global loop, bus
    DBusGMainLoop(set_as_default=True)
    addr = os.environ.get("QS_BT_BUS")
    bus = dbus.bus.BusConnection(addr) if addr else dbus.SystemBus()
    loop = GLib.MainLoop()
    agent = Agent(bus, AGENT_PATH)
    manager = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
    try:
        manager.RegisterAgent(AGENT_PATH, CAPABILITY)
        manager.RequestDefaultAgent(AGENT_PATH)
    except dbus.DBusException as e:
        sys.stderr.write("bt-agent: RegisterAgent / RequestDefaultAgent failed: %s\n" % e)
        try:
            manager.UnregisterAgent(AGENT_PATH)
        except dbus.DBusException:
            pass
        return 1
    GLib.io_add_watch(sys.stdin.fileno(), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal_add(GLib.PRIORITY_DEFAULT, sig, lambda: loop.quit() or False)
    emit({"method": "ready"})
    try:
        loop.run()
    finally:
        reject_all()
        try:
            manager.UnregisterAgent(AGENT_PATH)
        except dbus.DBusException:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
