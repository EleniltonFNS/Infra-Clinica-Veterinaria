#!/bin/sh

# Script para demonstrar a varredura de portas na DMZ a partir da estação cliente
echo "================================================================="
echo "  VARREDURA DE PORTAS NMAP - PERFIL: ${PERFIL:-cliente}"
echo "================================================================="
echo

echo "1. Varredura no Servidor Web ($WEB_IP):"
nmap -Pn -n -T4 --max-retries 1 -p 80,443,8080,22 "$WEB_IP"

echo
echo "2. Varredura no Prontuario Eletronico ($PRONTUARIO_IP):"
nmap -Pn -n -T4 --max-retries 1 -p 80,443,8443,22 "$PRONTUARIO_IP"

echo
echo "3. Varredura no Banco de Dados ($DB_IP):"
nmap -Pn -n -T4 --max-retries 1 -p 5432,22,80 "$DB_IP"
