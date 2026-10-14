#!/bin/sh

# O script deve parar se um comando falhar ou se uma variável não estiver definida.
set -eu

# Identifica o IP do gateway do firewall correspondente ao perfil do cliente
if [ "${PERFIL:-}" = "medico" ]; then
    GATEWAY_IP="$FIREWALL_LAN_IP"
elif [ "${PERFIL:-}" = "tutor" ]; then
    GATEWAY_IP="$FIREWALL_EXTERNAL_IP"
else
    GATEWAY_IP="${FIREWALL_LAN_IP:-10.77.1.254}"
fi

# Substitui a rota padrão para que todo tráfego externo à rede local passe pelo firewall
ip route replace default via "$GATEWAY_IP"
echo "[${PERFIL:-cliente}] Gateway padrão configurado para o firewall: $GATEWAY_IP"

# Permite execução de comandos passados via argumento ou mantém o contêiner ativo
if [ "$#" -gt 0 ]; then
    exec "$@"
fi

exec tail -f /dev/null
