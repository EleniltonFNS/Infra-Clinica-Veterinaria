#!/bin/sh

# O script deve parar se um comando falhar ou se uma variável não estiver definida.
set -eu

# Manda para executar o arquivo rules.sh, que contém as regras do firewall.
/usr/local/sbin/rules.sh

# Executa o comando passado como argumento para o entrypoint
exec "$@"
