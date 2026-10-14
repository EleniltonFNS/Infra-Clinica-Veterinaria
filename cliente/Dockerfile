# Imagem base para os contêineres de clientes (médico e tutor).
FROM alpine:3.22

# Instala as ferramentas necessárias para os testes de conectividade e segurança:
# curl (requisições HTTP/HTTPS), nmap (varredura de portas), iproute2 (tabela de rotas) e iputils (ping).
RUN apk add --no-cache curl nmap iproute2 iputils

# Copia e configura o script de inicialização para definir a rota default apontando para o firewall
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Define o entrypoint responsável por ajustar o gateway na subida do contêiner
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
