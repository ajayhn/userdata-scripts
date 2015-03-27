#!/bin/bash

FB_FLAG=/var/log/contrail/firstboot.log
PHYS_INTF=$(grep "^physical_interface=" /etc/contrail/contrail-vrouter-agent.conf | cut -d'=' -f 2)
if [ -f ${FB_FLAG} ]; then
    exit 0
fi

dhclient -v ${PHYS_INTF}
export DHCP_ADDR=$(ifconfig ${PHYS_INTF} | grep "inet addr" | awk '{ print $2 }' | cut -d ':' -f 2)
sed -i 's/    address.*/    address '${DHCP_ADDR}'/' /etc/network/interfaces
sed -i -r -e 's/control_network_ip=.*/control_network_ip='${DHCP_ADDR}'/' -e 's/^ip=.*\/(.*)/ip='${DHCP_ADDR}'\/\1/' /etc/contrail/contrail-vrouter-agent.conf
touch ${FB_FLAG}
reboot
