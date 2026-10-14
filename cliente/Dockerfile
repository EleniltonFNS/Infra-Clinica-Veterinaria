# Imagem base para os contêineres de clientes (médico e tutor).
FROM alpine:3.22

# Instala as ferramentas necessárias para os testes de conectividade e segurança:
# curl (requisições HTTP/HTTPS), nmap (varredura de portas), iproute2 (tabela de rotas) e iputils (ping).
RUN apk add --no-cache curl nmap iproute2 iputils

# Copia os scripts de inicialização, teste e varredura
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY testar.sh /usr/local/bin/testar
COPY varredura.sh /usr/local/bin/varredura

# Define permissão de execução para todos os scripts utilitários
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/testar /usr/local/bin/varredura

# Define o entrypoint responsável por ajustar o gateway na subida do contêiner
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
