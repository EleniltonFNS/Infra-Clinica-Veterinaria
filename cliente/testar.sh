#!/bin/sh

# O script deve parar se um comando falhar ou se uma variável não estiver definida.
set -eu

PERFIL="${PERFIL:?Variavel PERFIL nao definida}"
PASS=0
FAIL=0

ok() {
    PASS=$((PASS + 1))
    printf '[PASSOU] %-55s %s\n' "$1" "$2"
}

bad() {
    FAIL=$((FAIL + 1))
    printf '[FALHOU] %-55s %s\n' "$1" "$2"
    if [ -n "${3:-}" ]; then
        printf '  -> Detalhe: %s\n' "$3"
    fi
}

# Testa se uma conexão TCP tem resposta (aberta) ou é descartada pelo firewall (filtrada/timeout)
testar_tcp() {
    # -m 3 define timeout de 3 segundos; se retornar 28 significa timeout (DROP do firewall)
    curl -ksS -m 3 -o /dev/null "http://$1:$2/" 2>/dev/null
    case $? in
        7) echo "recusada" ;;
        28) echo "filtrada" ;;
        *) echo "aberta" ;;
    esac
}

echo "================================================================="
echo "  BATERIA DE TESTES DE SEGURANÇA - PERFIL: $PERFIL"
echo "================================================================="
echo

echo "--- 1. Testes Positivos (Conexões Autorizadas)"

# Teste P1: Acesso HTTP ao portal web (porta 80)
if curl -fsS -m 5 -o /dev/null "http://$WEB_IP/"; then
    ok "P1: Acesso HTTP ao portal web (dmz-web:80)" "[ACCEPT]"
else
    bad "P1: Acesso HTTP ao portal web (dmz-web:80)" "[FALHA]" "Falha ao conectar no portal web"
fi

# Teste P2: Acesso HTTPS ao portal web (porta 443)
if curl -fsSk -m 5 -o /dev/null "https://$WEB_IP/"; then
    ok "P2: Acesso HTTPS ao portal web (dmz-web:443)" "[ACCEPT]"
else
    bad "P2: Acesso HTTPS ao portal web (dmz-web:443)" "[FALHA]" "Falha ao conectar no portal HTTPS"
fi

# Teste P3: Acesso ao Prontuário Clínico (Depende do Perfil)
if [ "$PERFIL" = "medico" ]; then
    if curl -fsSk -m 5 "https://$PRONTUARIO_IP:8443/api/prontuarios/1" 2>/dev/null | grep -q '"sistema":"prontuario"'; then
        ok "P3: Medico acessa prontuario clinico (:8443)" "[ACCEPT]"
    else
        bad "P3: Medico acessa prontuario clinico (:8443)" "[FALHA]" "Medico deveria conseguir acessar"
    fi
else
    estado=$(testar_tcp "$PRONTUARIO_IP" 8443)
    if [ "$estado" = "filtrada" ]; then
        ok "P3: Tutor BLOQUEADO no prontuario (:8443)" "[DROP]"
    else
        bad "P3: Tutor BLOQUEADO no prontuario (:8443)" "[FALHA]" "Tutor nao deveria acessar o prontuario (estado: $estado)"
    fi
fi

echo
echo "--- 2. Testes Negativos (Bloqueios de Segurança Obrigatórios)"

# Teste N1: Bloqueio de acesso direto ao banco de dados PostgreSQL (porta 5432)
estado_db=$(testar_tcp "$DB_IP" 5432)
if [ "$estado_db" = "filtrada" ]; then
    ok "N1: Bloqueio de acesso direto ao banco de dados (:5432)" "[DROP]"
else
    bad "N1: Bloqueio de acesso direto ao banco de dados (:5432)" "[FALHA]" "Banco nao deve ser acessivel diretamente (estado: $estado_db)"
fi

# Teste N2: Bloqueio de ping ICMP para o banco de dados
if ping -c 1 -W 2 "$DB_IP" >/dev/null 2>&1; then
    bad "N2: Bloqueio de ping para o banco de dados" "[FALHA]" "Banco respondeu ao ping, deveria estar bloqueado"
else
    ok "N2: Bloqueio de ping para o banco de dados" "[DROP]"
fi

# Teste N3: Bloqueio de ping direto para a estacao da outra zona
if [ "$PERFIL" = "medico" ]; then
    ALVO_OUTRO="$TUTOR_IP"
else
    ALVO_OUTRO="$MEDICO_IP"
fi

if ping -c 1 -W 2 "$ALVO_OUTRO" >/dev/null 2>&1; then
    bad "N3: Bloqueio de comunicacao direta entre estacoes" "[FALHA]" "Estacao respondeu ao ping"
else
    ok "N3: Bloqueio de comunicacao direta entre estacoes" "[DROP]"
fi

# Teste N4: Varredura de portas com nmap no banco de dados
varredura_db=$(nmap -Pn -n -T4 --max-retries 1 --host-timeout 30s -p 5432 "$DB_IP" 2>/dev/null || true)
if echo "$varredura_db" | grep -q '5432/tcp filtered'; then
    ok "N4: Varredura nmap confirma banco como filtered" "[DROP]"
else
    bad "N4: Varredura nmap confirma banco como filtered" "[FALHA]" "Porta 5432 nao apareceu como filtered"
fi

echo
echo "================================================================="
echo "  RESUMO DOS TESTES ($PERFIL): $PASS passaram, $FAIL falharam"
echo "================================================================="

[ "$FAIL" -eq 0 ]
