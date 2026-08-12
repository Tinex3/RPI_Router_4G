from __future__ import annotations

import logging
import re
import subprocess
import time

logger = logging.getLogger(__name__)


def run_command(cmd: list[str], timeout: int = 10) -> tuple[int, str, str]:
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"
    except FileNotFoundError:
        return -1, "", f"Command not found: {cmd[0]}"


def apply_iptables_rules(ap_network: str = "192.168.50.0/24") -> list[str]:
    results: list[str] = []
    rules = [
        ["iptables", "-t", "nat", "-C", "POSTROUTING", "-o", "eth0", "-j", "MASQUERADE"],
        ["iptables", "-t", "nat", "-A", "POSTROUTING", "-o", "eth0", "-j", "MASQUERADE"],
        ["iptables", "-t", "nat", "-C", "POSTROUTING", "-o", "usb0", "-j", "MASQUERADE"],
        ["iptables", "-t", "nat", "-A", "POSTROUTING", "-o", "usb0", "-j", "MASQUERADE"],
        ["iptables", "-t", "nat", "-C", "POSTROUTING", "-o", "wwan0", "-j", "MASQUERADE"],
        ["iptables", "-t", "nat", "-A", "POSTROUTING", "-o", "wwan0", "-j", "MASQUERADE"],
        ["iptables", "-C", "FORWARD", "-i", "wlan0", "-j", "ACCEPT"],
        ["iptables", "-A", "FORWARD", "-i", "wlan0", "-j", "ACCEPT"],
        ["iptables", "-C", "FORWARD", "-o", "wlan0", "-j", "ACCEPT"],
        ["iptables", "-A", "FORWARD", "-o", "wlan0", "-j", "ACCEPT"],
    ]

    if ap_network != "0.0.0.0/0":
        rules.extend([
            ["iptables", "-C", "FORWARD", "-s", ap_network, "-d", ap_network, "-j", "DROP"],
            ["iptables", "-A", "FORWARD", "-s", ap_network, "-d", ap_network, "-j", "DROP"],
        ])
    else:
        rules.extend([
            ["iptables", "-D", "FORWARD", "-s", "192.168.50.0/24", "-d", "192.168.50.0/24", "-j", "DROP"],
        ])

    for rule in rules:
        rc, out, err = run_command(rule)
        action = " ".join(rule[0:2])
        if rc == 0 or (rule[1] == "-C" and rc != 0 and rule[0] == "iptables"):
            pass
        elif rule[1] == "-D":
            results.append(f"Removed: {action}")
        else:
            results.append(f"Applied: {action}")

    return results


def get_active_wan() -> dict[str, str | bool]:
    info: dict[str, str | bool] = {
        "active_interface": None,
        "internet": False,
        "ethernet_wan": False,
        "lte_connected": False,
    }

    try:
        result = subprocess.run(
            ["ip", "route", "show", "default"],
            capture_output=True, text=True, timeout=5,
        )
        if result.stdout:
            for line in result.stdout.strip().split("\n"):
                match = re.search(r"dev\s+(\S+)", line)
                if match:
                    info["active_interface"] = match.group(1)
                    break
    except Exception:
        pass

    rc, _, _ = run_command(["ping", "-c", "1", "-W", "2", "8.8.8.8"])
    info["internet"] = rc == 0

    rc, _, _ = run_command(["ping", "-c", "1", "-W", "1", "-I", "eth0", "8.8.8.8"])
    info["ethernet_wan"] = rc == 0

    for iface in ["usb0", "wwan0"]:
        rc, out, _ = run_command(["ip", "addr", "show", iface])
        if rc == 0 and "inet " in out:
            info["lte_connected"] = True
            break

    return info


def check_connectivity(host: str = "8.8.8.8", timeout: int = 2) -> bool:
    rc, _, _ = run_command(["ping", "-c", "1", "-W", str(timeout), host])
    return rc == 0


def get_ip_address(interface: str | None = None) -> str | None:
    cmd = ["ip", "-4", "addr", "show"]
    if interface:
        cmd.append(interface)

    rc, out, _ = run_command(cmd)
    if rc == 0 and out:
        match = re.search(r"inet\s+(\d+\.\d+\.\d+\.\d+)", out)
        if match:
            return match.group(1)
    return None
