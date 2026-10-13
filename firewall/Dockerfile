# Imagem base para o firewall.
FROM alpine:3.22

# Instala o iptables(regras de filtragem, controle de acesso) e o iproute2(manejo de rotas, configuração de interface de rede).
RUN apk add --no-cache iptables iproute2

# Copia os scripts de regras e de entrada para o diretório /usr/local/sbin/ da imagem.
COPY rules.sh /usr/local/sbin/rules.sh
COPY entrypoint.sh /usr/local/sbin/entrypoint.sh

# Define permissões de execução para os scripts copiados.
RUN chmod +x /usr/local/sbin/rules.sh /usr/local/sbin/entrypoint.sh

# Define o script que será executado quando o contêiner for iniciado.
ENTRYPOINT [ "/usr/local/sbin/entrypoint.sh" ]