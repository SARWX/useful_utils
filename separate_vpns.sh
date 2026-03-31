#!/bin/bash

VPN0_IFACE="vpn0"   # интерфейс корпоративного VPN
LAN_IFACE="enxf4a80d50b40d" # интерфейс выхода в локальную сеть
AWG_IFACE="awg" # интерфейс иностранного VPN

VPN0_TABLE=100
AWG_TABLE=200

VPN0_SUBNETS="10.190.0.0/16 10.177.0.0/16 10.198.0.0/16"

echo "=== Настройка policy routing ==="

# Таблицы
grep -q "^$VPN0_TABLE vpn0" /etc/iproute2/rt_tables || echo "$VPN0_TABLE vpn0" | sudo tee -a /etc/iproute2/rt_tables
grep -q "^$AWG_TABLE awg" /etc/iproute2/rt_tables || echo "$AWG_TABLE awg" | sudo tee -a /etc/iproute2/rt_tables

# IP
VPN0_IP=$(ip -4 addr show $VPN0_IFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
LAN_IP=$(ip -4 addr show $LAN_IFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
AWG_IP=$(ip -4 addr show $AWG_IFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

echo "✓ VPN0 IP: $VPN0_IP"
echo "✓ LAN  IP: $LAN_IP"
echo "✓ AWG  IP: $AWG_IP"

# Очистка
for subnet in $VPN0_SUBNETS; do
    sudo ip rule del to $subnet table $VPN0_TABLE 2>/dev/null
done

sudo ip rule del table $AWG_TABLE 2>/dev/null

sudo ip route flush table $VPN0_TABLE 2>/dev/null
sudo ip route flush table $AWG_TABLE 2>/dev/null

for subnet in $VPN0_SUBNETS; do
    sudo ip route add table $VPN0_TABLE $subnet \
        nexthop dev $VPN0_IFACE weight 2 \
        nexthop dev $LAN_IFACE weight 1

    echo "✓ $subnet -> vpn0 (primary), $LAN_IFACE (secondary)"
done

# AWG default
sudo ip route add table $AWG_TABLE default dev $AWG_IFACE
echo "✓ default -> $AWG_IFACE"

# Rules
for subnet in $VPN0_SUBNETS; do
    sudo ip rule add to $subnet table $VPN0_TABLE priority 1000
done

sudo ip rule add to 0.0.0.0/0 table $AWG_TABLE priority 2000

# Проверка
echo -e "\n=== Таблица VPN0 ==="
ip route show table $VPN0_TABLE

echo -e "\n=== Таблица AWG ==="
ip route show table $AWG_TABLE

echo -e "\n=== Проверка ==="
ip route get 10.190.0.1 | head -1
ip route get 8.8.8.8 | head -1

echo -e "\n✓ Готово"
