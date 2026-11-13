#!/bin/sh
set -eu
mac="$1"
fqdn="$2"
iface=''
for nic in /sys/class/net/*; do
  [ "$(cat "$nic/address")" = "$mac" ] && iface="${nic##*/}"
done
[ -n "$iface" ] && [ "$iface" != eth0 ]
hostname "$fqdn"
cat > /etc/dhcp/dhclient-enter-hooks.d/asa-private-route <<EOF
# Preservar o default NAT mesmo anunciando gateway privado conforme enunciado.
if [ "\$interface" = "$iface" ]; then
  unset new_routers
fi
EOF
cat > /etc/network/interfaces.d/asa-private <<EOF
auto $iface
iface $iface inet dhcp
EOF
if ! ip -4 address show dev "$iface" | grep -q 'inet '; then
  ifup "$iface"
fi
ip -4 address show dev "$iface"
ip -4 route
