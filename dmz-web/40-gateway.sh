#!/bin/sh

# O script deve parar se um comando falhar ou se uma variável não estiver definida.
set -eu

# Aponta a rota default dos servidores da DMZ para o IP do firewall na DMZ.
# Sem essa rota, os pacotes de resposta para o médico ou tutor não retornariam pelo firewall.
if [ -n "${FIREWALL_DMZ_IP:-}" ]; then
    ip route replace default via "$FIREWALL_DMZ_IP"
    echo "[dmz-web] Gateway padrão configurado para o firewall: $FIREWALL_DMZ_IP"
fi
