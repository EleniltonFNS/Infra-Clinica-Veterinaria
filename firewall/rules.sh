#!/bin/sh

# O script deve parar se um comando falhar ou se uma variável não estiver definida.
set -eu

# Identifica dinamicamente o nome da interface de rede correspondente a cada IP do firewall
obter_interface() {
    ip -o -4 addr show | awk -v ip="$1" '$4 ~ ("^" ip "/") { print $2; exit }'
}

LAN_IF=$(obter_interface "$FIREWALL_LAN_IP")
DMZ_IF=$(obter_interface "$FIREWALL_DMZ_IP")
EXTERNAL_IF=$(obter_interface "$FIREWALL_EXTERNAL_IP")

# Flush
iptables -F # Limpa todas as regras antigas das chains da tabela padrão (filter)
iptables -t nat -F # Limpa todas as regras antigas da tabela NAT
iptables -t mangle -F # Limpa todas as regras antigas da tabela MANGLE

iptables -X # remove - Remove todas as chains definidas pelo usuário, que não estejam sendo usadas

iptables -Z # zero - Zera os contadores de pacotes e bytes de todas as regras

# Políticas Padrão
iptables -P INPUT DROP # Descarta todos os pacotes destinados à chain INPUT (chain de entrada) que não forem aceitos por nenhuma regra anterior.
iptables -P FORWARD DROP # Descarta todos os pacotes encaminhados pela chain FORWARD (chain de encaminhamento) que não forem aceitos por nenhuma regra anterior.
iptables -P OUTPUT ACCEPT # Aceita todos os pacotes gerados pelo próprio firewall na chain OUTPUT (chain de saída) que não forem bloqueados por uma regra anterior.

# Regras da chain INPUT (proteção do próprio contêiner firewall)
iptables -A INPUT -i lo -j ACCEPT # Permite que os pacotes que chegam pela interface de loopback (lo) e são destinados ao firewall sejam aceitos.
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP # Descarta pacotes inválidos direcionados ao próprio firewall.
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT # Permite que os pacotes que chegam ao firewall sejam aceitos se fizerem parte de uma conexão já estabelecida ou relacionada.

# Regras da chain OUTPUT
iptables -A OUTPUT -o lo -j ACCEPT # Permite que os pacotes gerados pelo firewall saiam pela interface de loopback (lo).
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT # Permite que os pacotes gerados pelo firewall sejam aceitos se fizerem parte de uma conexão já estabelecida ou relacionada.

# Regras da chain FORWARD (roteamento e filtragem entre zonas)
# 1. Higiene de conexões e proteção anti-spoofing
iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP # Descarta pacotes que não pertençam a fluxos válidos (proteção contra varreduras anômalas).
iptables -A FORWARD -i "$EXTERNAL_IF" ! -s "$EXTERNAL_SUBNET" -m comment --comment "Anti-spoofing rede externa" -j DROP # Descarta pacotes que cheguem na interface externa com IP forjado de outra zona.
iptables -A FORWARD -i "$LAN_IF" ! -s "$LAN_SUBNET" -m comment --comment "Anti-spoofing LAN" -j DROP # Descarta pacotes que cheguem na interface da LAN com IP forjado de outra zona.

# 2. Retorno de conexões estabelecidas (Firewall Stateful)
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT # Permite que os servidores da DMZ respondam às requisições legítimas feitas pelos clientes.

# 3. Liberações explícitas de serviços autorizados
iptables -A FORWARD -i "$EXTERNAL_IF" -o "$DMZ_IF" -s "$TUTOR_IP" -d "$WEB_IP" -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -j ACCEPT # Permite que os pacotes encaminhados do IP do tutor para o IP do webserver sejam aceitos nas portas 80 ou 443 em nova conexão.
iptables -A FORWARD -i "$LAN_IF" -o "$DMZ_IF" -s "$MEDICO_IP" -d "$WEB_IP" -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -j ACCEPT # Permite que os pacotes encaminhados do IP do médico para o IP do webserver sejam aceitos nas portas 80 ou 443 em nova conexão.
iptables -A FORWARD -i "$LAN_IF" -o "$DMZ_IF" -s "$MEDICO_IP" -d "$PRONTUARIO_IP" -p tcp --dport 8443 -m conntrack --ctstate NEW -j ACCEPT # Permite que os pacotes encaminhados do IP do médico para o IP do prontuário sejam aceitos na porta 8443 em nova conexão.

# 4. Bloqueios explícitos para auditoria e matriz de segurança
iptables -A FORWARD -i "$EXTERNAL_IF" -o "$DMZ_IF" -d "$PRONTUARIO_IP" -m comment --comment "Tutor bloqueado no prontuario" -j DROP # Bloqueia tentativa de acesso do tutor ao prontuário médico.
iptables -A FORWARD -o "$DMZ_IF" -d "$DB_IP" -m comment --comment "Clientes bloqueados no banco" -j DROP # Bloqueia tentativa de acesso direto ao banco de dados por qualquer cliente.
iptables -A FORWARD -i "$EXTERNAL_IF" -o "$LAN_IF" -m comment --comment "Trafego externo para LAN bloqueado" -j DROP # Impede comunicação direta entre a rede externa e a rede interna LAN.
iptables -A FORWARD -i "$LAN_IF" -o "$EXTERNAL_IF" -m comment --comment "Trafego LAN para externa bloqueado" -j DROP # Impede comunicação direta entre a rede LAN e a rede externa.

# 5. Regra de Ouro da DMZ
iptables -A FORWARD -i "$DMZ_IF" -m conntrack --ctstate NEW -m comment --comment "DMZ nao inicia conexao para dentro" -j DROP # Impede que servidores comprometidos na DMZ iniciem conexões contra a rede interna.
