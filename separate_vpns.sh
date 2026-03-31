#!/bin/bash

# Конфигурация
VPN0_IFACE="vpn0"
AWG_IFACE="awg"
VPN0_TABLE=100
AWG_TABLE=200

# Подсети, которые идут через vpn0
VPN0_SUBNETS="10.190.0.0/16 10.177.0.0/16 10.198.0.0/16"

# 1. Добавляем таблицы в систему (если их нет)
grep -q "^$VPN0_TABLE vpn0" /etc/iproute2/rt_tables || echo "$VPN0_TABLE vpn0" | sudo tee -a /etc/iproute2/rt_tables
grep -q "^$AWG_TABLE awg" /etc/iproute2/rt_tables || echo "$AWG_TABLE awg" | sudo tee -a /etc/iproute2/rt_tables

# 2. Получаем IP адреса интерфейсов
VPN0_IP=$(ip addr show $VPN0_IFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
AWG_IP=$(ip addr show $AWG_IFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

echo "✓ VPN0 IP: $VPN0_IP"
echo "✓ AWG IP: $AWG_IP"

# 3. Очищаем старые правила (если были)
sudo ip rule del table $VPN0_TABLE 2>/dev/null
sudo ip rule del table $AWG_TABLE 2>/dev/null

# 4. Очищаем старые маршруты в таблицах
sudo ip route flush table $VPN0_TABLE 2>/dev/null
sudo ip route flush table $AWG_TABLE 2>/dev/null

# 5. Добавляем маршруты по умолчанию для каждой таблицы
sudo ip route add default dev $VPN0_IFACE table $VPN0_TABLE
sudo ip route add default dev $AWG_IFACE table $AWG_TABLE

# 6. Копируем локальные маршруты (чтобы не сломать localhost)
sudo ip route show table local | while read route; do
    sudo ip route add $route table $VPN0_TABLE 2>/dev/null
    sudo ip route add $route table $AWG_TABLE 2>/dev/null
done

# 7. Добавляем правила: подсети 10.190, 10.120, 10.130 через vpn0
for subnet in $VPN0_SUBNETS; do
    sudo ip rule add to $subnet table $VPN0_TABLE priority 1000
    echo "✓ $subnet -> $VPN0_IFACE"
done

# 8. Всё остальное через awg
sudo ip rule add to 0.0.0.0/0 table $AWG_TABLE priority 2000
echo "✓ default -> $AWG_IFACE"

# 9. Проверка
echo -e "\n=== Правила маршрутизации ==="
ip rule show | grep -E "table ($VPN0_TABLE|$AWG_TABLE)"

echo -e "\n=== Проверка маршрутов ==="
echo "До 10.190.0.1:"
ip route get 10.190.0.1 2>/dev/null | head -1

echo -e "\nДо 8.8.8.8:"
ip route get 8.8.8.8 2>/dev/null | head -1
