# Imagem base do Nginx no Alpine para os servidores da DMZ.
FROM nginx:alpine

# Instala curl (testes), iproute2 (gerenciamento de rotas) e openssl (geração de certificado autoassinado).
RUN apk add --no-cache curl iproute2 openssl \
    && mkdir -p /etc/nginx/certs \
    && openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
       -keyout /etc/nginx/certs/lab.key -out /etc/nginx/certs/lab.crt \
       -subj "/CN=dmz-web/O=Clinica Veterinaria Pata Amiga (laboratorio)"

# Copia o script de gateway para ser executado automaticamente na inicialização do contêiner Nginx
COPY 40-gateway.sh /docker-entrypoint.d/40-gateway.sh
RUN chmod +x /docker-entrypoint.d/40-gateway.sh

# Copia a configuração do Nginx e a página do portal para a imagem.
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY html/ /usr/share/nginx/html/
