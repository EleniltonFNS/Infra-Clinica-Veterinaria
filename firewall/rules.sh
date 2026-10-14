#!/bin/sh

# O script deve parar se um comando falhar ou se uma variável não estiver definida.
set -eu

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

# Regras adicionadas ao final da chain
iptables -A INPUT -i lo -j ACCEPT # Permite que os pacotes que chegam pela interface de loopback (lo) e são destinados ao firewall sejam aceitos.
iptables -A OUTPUT -o lo -j ACCEPT # Permite que os pacotes gerados pelo firewall saiam pela interface de loopback (lo).

iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT # Permite que os pacotes que chegam ao firewall sejam aceitos se fizerem parte de uma conexão já estabelecida ou estiverem relacionados a uma conexão existente.
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT # Permite que os pacotes gerados pelo firewall sejam aceitos se fizerem parte de uma conexão já estabelecida ou estiverem relacionados a uma conexão existente.
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT # Permite que os pacotes que chegam à chain FORWARD sejam aceitos se fizerem parte de uma conexão já estabelecida ou estiverem relacionados a uma conexão existente.

iptables -A FORWARD -s "$LAN_SUBNET" -d "$DMZ_SUBNET" -p tcp --dport 80 -j ACCEPT # Permite que os pacotes encaminhados da rede LAN para a rede DMZ sejam aceitos quando utilizarem o protocolo TCP e tiverem como destino a porta 80.