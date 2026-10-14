# Imagem base para os contêineres de clientes (médico e tutor).
FROM alpine:3.22

# Instala as ferramentas necessárias para os testes de conectividade e segurança:
# curl (requisições HTTP/HTTPS), nmap (varredura de portas), iproute2 (tabela de rotas) e iputils (ping).
RUN apk add --no-cache curl nmap iproute2 iputils

# Mantém o contêiner em execução aguardando comandos
CMD ["tail", "-f", "/dev/null"]
