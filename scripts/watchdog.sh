#!/bin/bash
# Watchdog para auto-recovery de WAN/LTE
set -e

ETH=eth0
LTE=usb0

ok_ping() { ping -c 1 -W 1 "$1" >/dev/null 2>&1; }
iface_ping() { ping -I "$1" -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; }

while true; do
  # Si hay internet por eth0, todo OK
  if iface_ping "$ETH"; then
    sleep 10
    continue
  fi

  # Si hay internet por usb0, OK (ethernet caído)
  if iface_ping "$LTE"; then
    sleep 10
    continue
  fi

  # Nada tiene internet: intenta recuperar LTE primero
  echo "$(date): No internet detected, trying to recover LTE..." | logger -t watchdog
  dhclient -r "$LTE" >/dev/null 2>&1 || true
  sleep 2
  dhclient "$LTE" >/dev/null 2>&1 || true

  # Re-test
  sleep 3
  if iface_ping "$LTE"; then
    echo "$(date): LTE recovered" | logger -t watchdog
    sleep 10
    continue
  fi

  # Último recurso: reiniciar modem (AT+CFUN=1,1)
  echo "$(date): DHCP failed, resetting modem..." | logger -t watchdog
  # Encuentra puerto AT y manda comando
  for p in /dev/ttyUSB*; do
    [ -c "$p" ] || continue
    echo -e "AT\r" > "$p" 2>/dev/null || true
    sleep 1
    echo -e "AT+CFUN=1,1\r" > "$p" 2>/dev/null || true
    break
  done

  echo "$(date): Modem reset sent, waiting 30s..." | logger -t watchdog
  sleep 30
done
