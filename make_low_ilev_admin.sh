#!/bin/bash

USERNAME="low_ilev"
PASSWORD="password123"

useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
usermod -aG sudo "$USERNAME"

echo "$USERNAME ALL=(ALL:ALL) ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME
pdpl-user -i 0 "$USERNAME"

echo "Низкоцелостный администратор $USERNAME создан"

