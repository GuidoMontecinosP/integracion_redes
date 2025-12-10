#!/bin/bash
###############################################################################
# FIREWALL EMPRESARIAL - Configuración iptables
# Cumple: SSH limitado, HTTP/HTTPS completo, phpMyAdmin externo
###############################################################################

echo "==> Respaldando configuración actual..."
BACKUP_FILE="/root/firewall-backup-$(date +%Y%m%d-%H%M%S).txt"
iptables-save > "$BACKUP_FILE"
echo "✓ Respaldo guardado en: $BACKUP_FILE"

# Limpiar reglas existentes
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Políticas por defecto: bloquear todo
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# 1. Tráfico loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# 2. Conexiones establecidas y relacionadas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# 3. SSH solo desde redes autorizadas
for NET in 192.168.23.0/24 200.27.0.0/24 146.83.1.0/24; do
    iptables -A INPUT -p tcp --dport 22 -s $NET -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 22 -d $NET -j ACCEPT
    iptables -A FORWARD -p tcp --dport 22 -s $NET -j ACCEPT
done

# 4. HTTP/HTTPS servidores web (hosting 192.168.23.10 y corporativo)
WEBS=("192.168.23.10")  # Agregar IP web corporativa si aplica

for WEB in "${WEBS[@]}"; do
    iptables -A INPUT -p tcp -d $WEB --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp -d $WEB --dport 443 -j ACCEPT
    iptables -A FORWARD -p tcp -d $WEB --dport 80 -j ACCEPT
    iptables -A FORWARD -p tcp -d $WEB --dport 443 -j ACCEPT
    iptables -A OUTPUT -p tcp -s $WEB --sport 80 -j ACCEPT
    iptables -A OUTPUT -p tcp -s $WEB --sport 443 -j ACCEPT
done

# 5. phpMyAdmin (192.168.23.11) accesible solo desde fuera de la red interna
iptables -A INPUT -p tcp -d 192.168.23.11 --dport 80 ! -s 192.168.23.0/24 -j ACCEPT
iptables -A INPUT -p tcp -d 192.168.23.11 --dport 443 ! -s 192.168.23.0/24 -j ACCEPT
iptables -A FORWARD -p tcp -d 192.168.23.11 --dport 80 ! -s 192.168.23.0/24 -j ACCEPT
iptables -A FORWARD -p tcp -d 192.168.23.11 --dport 443 ! -s 192.168.23.0/24 -j ACCEPT
iptables -A OUTPUT -p tcp -s 192.168.23.11 --sport 80 -j ACCEPT
iptables -A OUTPUT -p tcp -s 192.168.23.11 --sport 443 -j ACCEPT

# 6. DNS para resolución de nombres
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A INPUT -p tcp --sport 53 -j ACCEPT

# Mostrar reglas
echo "==> Reglas configuradas:"
iptables -L INPUT -n -v --line-numbers
iptables -L OUTPUT -n -v --line-numbers
iptables -L FORWARD -n -v --line-numbers

# Guardar reglas permanentemente (Debian/Ubuntu)
echo "==> Guardando reglas permanentemente..."
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4
echo "✓ Reglas guardadas en /etc/iptables/rules.v4"
echo "✓ Script completado"
