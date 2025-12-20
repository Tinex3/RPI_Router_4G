#!/bin/bash
echo "ECM init"
dhclient usb0 || true
