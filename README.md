# hilink-pin
Script for OpenWRT to perform an automatic SIM unlock of Huawei Hilink E3372.

The script should be installed at: /etc/hotplug.d/iface/99-hilink-pin.sh

To set password and pin use:
```
uci set network.wan.pincode=1234
uci set network.wan.password=PASSWORD
uci commit
```

## Requirements
Requires full curl package.

## Compatibility
Tested with:
- lede-17.01.4
- E3372
  - Firmware: 22.315.01.01.264
  - UI: 17.100.14.00.264
