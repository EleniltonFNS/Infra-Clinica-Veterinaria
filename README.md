# Firewall Linux com Netfilter e iptables — Clínica Veterinária Pata Amiga

## 1. Apresentação do Projeto

O **Firewall Linux — Clínica Veterinária Pata Amiga** é um projeto acadêmico desenvolvido para a disciplina de **Segurança da Informação** do curso de Bacharelado em Sistemas de Informação do **Instituto Federal Goiano — Campus Ceres**, sob orientação do Prof. Roitier Campos Gonçalves.

O projeto propõe a construção de uma infraestrutura de rede segmentada, utilizando Docker e Docker Compose, com um firewall Linux responsável por controlar e filtrar o tráfego entre diferentes redes e serviços por meio do Netfilter/iptables.

O cenário utilizado é uma clínica veterinária fictícia chamada **Pata Amiga**, que precisa disponibilizar seus sistemas aos usuários autorizados sem permitir acessos indevidos a informações restritas e prontuários médicos.

### Objetivos do projeto

- Implementar um ambiente de rede segmentado utilizando redes Docker isoladas (`lan`, `dmz`, `external`).
- Configurar um container Linux para atuar como gateway e roteador com permissões administrativas (`cap_add: [NET_ADMIN]`) e encaminhamento ativado (`net.ipv4.ip_forward: "1"`).
- Utilizar Netfilter e iptables para estabelecer regras de filtragem de pacotes stateful (com inspeção de estado).
- Aplicar uma política de bloqueio por padrão (**DROP**), liberando explicitamente apenas os acessos necessários para cada perfil.
- Implementar proteções de rede: regras de anti-spoofing por interface e a regra de ouro da DMZ (servidores expostos não iniciam conexões para a rede interna).
- Validar a configuração por meio de testes automatizados de conectividade permitida e bloqueada, além de auditoria dos contadores de regras no kernel.

---

## 2. Definição do Cenário e Problema de Segurança

A clínica veterinária utiliza três serviços principais:

- **Portal de agendamento (`dmz-web`):** permite que os tutores e médicos consultem e solicitem agendamentos (portas TCP 80 e 443).
- **Prontuário eletrônico (`dmz-prontuario`):** armazena informações clínicas e diagnósticos dos animais, devendo ser acessível exclusivamente aos profissionais autorizados (porta TCP 8443 com HTTPS).
- **Banco de dados (`dmz-db`):** servidor PostgreSQL (porta TCP 5432) que armazena os dados persistentes da clínica e não deve ser acessado diretamente pelos usuários.

O cenário considera dois perfis de acesso:

- **Tutor do animal (Perfil Externo):** acessa a rede externa (`external`) e precisa utilizar apenas o portal de agendamento, sem acesso direto ao prontuário eletrônico ou ao banco de dados.
- **Médico-veterinário (Perfil Interno):** utiliza a rede interna da clínica (`lan`) e precisa acessar o portal e o prontuário eletrônico, sem acesso direto à porta do banco de dados.

### Problema identificado

Sem segmentação e regras de filtragem adequadas (rede plana), qualquer usuário pode alcançar serviços que não fazem parte de suas permissões:
1. O tutor conseguiria ler prontuários de outros pacientes (violação grave de sigilo médico-veterinário e da LGPD).
2. O banco de dados ficaria exposto a varreduras de portas e acessos diretos indevidos.
3. Se um invasor comprometesse o servidor web da DMZ, poderia usá-lo para atacar estações internas na LAN.

A solução proposta intercala um contêiner firewall entre as redes isoladas, controlando o encaminhamento de pacotes e permitindo somente as comunicações autorizadas pela política de segurança.

---

## 3. Arquitetura de Rede Implementada

O ambiente é simulado com containers Docker conectados a três redes bridge distintas (`routed`), definidas no Docker Compose:

```text
                  ┌──────────────────────────────┐
                  │    Rede EXTERNA (external)   │
                  │   Tutor: 10.77.3.10          │
                  └──────────────┬───────────────┘
                                 │
                                 ▼ (eth2 / 10.77.3.254)
┌────────────────────────────────┴──────────────────────────────┐
│                    CONTAINER FIREWALL LINUX                   │
│         (Alpine Linux 3.22 + Netfilter / iptables)            │
│                 Política Padrão: DROP                         │
└────────────────┬──────────────────────────────┬───────────────┘
  (eth0 / .254)  │                              │  (eth1 / .254)
                 ▼                              ▼
┌──────────────────────────────┐  ┌─────────────────────────────┐
│       Rede LAN (lan)         │  │       Rede DMZ (dmz)        │
│   Médico: 10.77.1.10         │  │ • Web: 10.77.2.10 (80/443)  │
└──────────────────────────────┘  │ • Prontuário: 10.77.2.12    │
                                  │   (porta 8443)              │
                                  │ • Banco DB: 10.77.2.11      │
                                  │   (PostgreSQL porta 5432)   │
                                  └─────────────────────────────┘
```

| Zona de Rede | Sub-rede CIDR | Gateway (Firewall) | Componente / Container | IP Estático | Finalidade |
|---|---|---|---|---|---|
| **Rede Externa (`external`)** | `10.77.3.0/24` | `10.77.3.254` | `tutor` | `10.77.3.10` | Representar o acesso dos tutores ao portal. |
| **Rede LAN (`lan`)** | `10.77.1.0/24` | `10.77.1.254` | `medico` | `10.77.1.10` | Representar a rede interna utilizada pelos médicos-veterinários. |
| **Rede DMZ (`dmz`)** | `10.77.2.0/24` | `10.77.2.254` | `dmz-web` | `10.77.2.10` | Disponibilizar o serviço web nas portas TCP 80 e 443. |
| **Rede DMZ (`dmz`)** | `10.77.2.0/24` | `10.77.2.254` | `dmz-prontuario` | `10.77.2.12` | Disponibilizar o serviço restrito aos profissionais autorizados na porta TCP 8443. |
| **Rede DMZ (`dmz`)** | `10.77.2.0/24` | `10.77.2.254` | `dmz-db` | `10.77.2.11` | Manter os dados dos sistemas na porta TCP 5432, sem acesso direto pelos usuários. |
| **Firewall / Roteador** | *(Todas as 3 redes)* | — | `firewall` | `10.77.1.254`<br>`10.77.2.254`<br>`10.77.3.254` | Encaminhar e filtrar o tráfego entre as redes, utilizando iptables. |

O container de firewall possui a capacidade administrativa `NET_ADMIN` e o encaminhamento IPv4 habilitado por meio de `net.ipv4.ip_forward: "1"`. A segmentação impede que os usuários contornem as regras do firewall por meio de acessos diretos indevidos entre as redes.

---

## 4. Política de Segurança e Regras de Acesso

A política adotada é **bloquear por padrão e permitir explicitamente o necessário**, utilizando o alvo `DROP` como política padrão das cadeias de filtragem pertinentes (`INPUT` e `FORWARD`).

A matriz abaixo detalha cada regra implementada no firewall:

| Origem | Destino | Porta / Protocolo | Ação | Justificativa do Negócio |
|---|---|---|---|---|
| Rede externa (Tutor) | Portal na DMZ | TCP 80/443 | **ACCEPT** | Permitir o acesso dos tutores ao portal de agendamento. |
| LAN (Médico) | Portal na DMZ | TCP 80/443 | **ACCEPT** | Permitir o acesso dos profissionais ao portal institucional. |
| LAN (Médico) | Prontuário na DMZ | TCP 8443 | **ACCEPT** | Permitir o acesso dos profissionais ao prontuário eletrônico. |
| Rede externa (Tutor) | Prontuário na DMZ | Qualquer | **DROP** | **Bloqueio de segurança:** impedir o acesso dos tutores às informações clínicas (LGPD). |
| LAN / Rede externa | Banco de dados na DMZ | TCP 5432 | **DROP** | **Bloqueio de segurança:** clientes não devem acessar o banco direto; apenas a aplicação o acessa. |
| Rede externa (Tutor) | Rede LAN (Médico) | Qualquer | **DROP** | Isolar totalmente o tráfego da rede de clientes externos da intranet médica. |
| Rede LAN (Médico) | Rede externa (Tutor) | Qualquer | **DROP** | Impedir comunicações não roteadas entre estações internas e clientes externos. |
| Rede DMZ (Servidores) | LAN / Externa | Conexões `NEW` | **DROP** | **Regra de Ouro da DMZ:** a DMZ nunca inicia conexões novas para as redes internas. |
| Qualquer | Qualquer | Conexões `INVALID` | **DROP** | Higiene de rede: descarte de pacotes órfãos e varreduras anômalas (ex: varreduras NULL). |
| Qualquer | Qualquer | `ESTABLISHED,RELATED` | **ACCEPT** | **Firewall Stateful:** permite o retorno de conexões legítimas iniciadas por uma regra autorizada. |
| Interface Externa | Qualquer | Origem fora de `10.77.3.0/24` | **DROP** | **Anti-spoofing:** impede que um invasor na rede externa forje o endereço IP de um médico da LAN. |
| Interface LAN | Qualquer | Origem fora de `10.77.1.0/24` | **DROP** | **Anti-spoofing:** garante que apenas pacotes com IP legítimo da LAN trafeguem pela interface local. |

---

## 5. Tecnologias e Ferramentas Utilizadas

- **Docker:** execução dos serviços em containers isolados.
- **Docker Compose:** definição dos containers, das redes e de suas configurações.
- **Linux (Alpine 3.22):** sistema utilizado no container de firewall e nas estações clientes.
- **Netfilter:** infraestrutura de filtragem de pacotes do kernel Linux.
- **iptables:** ferramenta utilizada para configurar as regras de filtragem.
- **Nginx (Alpine):** servidor web e proxy reverso para o portal e a API de prontuário com SSL.
- **PostgreSQL 16 (Alpine):** banco de dados relacional com volume persistente e script SQL de carga.
- **Visual Studio Code:** edição e organização dos arquivos do projeto.
- **Git e GitHub:** controle de versão e registro da evolução do desenvolvimento com commits frequentes.

---

## 6. Execução do Ambiente

O ambiente é iniciado a partir do arquivo `docker-compose.yml`, que define os containers, as redes roteadas e os volumes persistentes.

### 1. Inicializar todos os serviços
```bash
docker compose up -d --build
```

### 2. Conferir os containers em execução
```bash
docker compose ps
```
*Todos os seis containers (`firewall`, `dmz-web`, `dmz-prontuario`, `dmz-db`, `medico`, `tutor`) devem constar com status `Up`.*

### 3. Executar os testes automatizados da estação do médico
```bash
docker compose exec -T medico testar
```

### 4. Executar os testes automatizados da estação do tutor
```bash
docker compose exec -T tutor testar
```

### 5. Consultar os registros de execução (logs)
```bash
docker compose logs firewall
```

### 6. Consultar os contadores de regras do firewall
```bash
docker compose exec -T firewall iptables -L FORWARD -n -v --line-numbers
```

### 7. Encerrar o ambiente
```bash
docker compose down -v
```

---

## 7. Metodologia de Testes e Validação

A validação demonstra tanto os acessos autorizados quanto os bloqueios definidos na política de segurança:

### Testes positivos (o que deve funcionar)
- **Acesso HTTP ao portal web (porta 80):** o médico e o tutor conseguem carregar a página inicial do portal de agendamento.
- **Acesso HTTPS ao portal web (porta 443):** ambos os perfis conseguem se conectar via TLS com o portal.
- **Acesso ao prontuário eletrônico (porta 8443):** o médico-veterinário consegue consultar a API de prontuários e recebe o diagnóstico do paciente.

### Testes negativos (o que deve ser bloqueado)
- **Tutor no prontuário eletrônico:** o tutor é bloqueado com descarte silencioso (`DROP`), gerando timeout e comprovando a retenção do sigilo clínico.
- **Acesso direto ao banco de dados:** nem o médico nem o tutor conseguem conectar diretamente na porta TCP 5432 do PostgreSQL.
- **Varredura com nmap:** varreduras de portas confirmam que portas restritas aparecem no estado `filtered` (pacote descartado pelo firewall).
- **Isolamento de redes:** ping e comunicações diretas entre a estação do médico e a do tutor são descartadas pelo firewall.
- **Proteção anti-spoofing:** se o tutor adicionar o IP do médico em sua interface e tentar acessar o prontuário, o firewall descarta o pacote por ter entrado na interface da rede externa.

---

## 8. Estrutura do Repositório

```text
.
├── .env                  # Variáveis de ambiente da infraestrutura e sub-redes
├── .env.example          # Modelo de variáveis de ambiente para reprodução do ambiente
├── .gitattributes        # Padronização de quebra de linha LF para scripts Linux
├── .gitignore            # Arquivos temporários e de editores ignorados pelo Git
├── docker-compose.yml    # Orquestração dos containers, volumes e redes bridge roteadas
├── README.md             # Apresentação do projeto e guia de uso da infraestrutura
├── cliente/              # Estações de trabalho (médico e tutor)
│   ├── Dockerfile        # Imagem Alpine com curl, nmap, iproute2 e iputils
│   ├── entrypoint.sh     # Script que define o gateway padrão apontando para o firewall
│   ├── testar.sh         # Script utilitário com bateria de testes automatizados
│   └── varredura.sh      # Script de varredura nmap para demonstração de portas
├── dmz-web/              # Servidor Web do Portal de Agendamento da DMZ
│   ├── Dockerfile        # Imagem Nginx Alpine com geração de certificado SSL
│   ├── nginx.conf        # Configuração das rotas HTTP (80) e HTTPS (443)
│   ├── 40-gateway.sh     # Script de inicialização da rota padrão para o firewall
│   └── html/index.html   # Página inicial institucional da clínica
├── dmz-prontuario/       # Serviço da API de Prontuário Eletrônico
│   └── nginx.conf        # Configuração da API HTTPS restrita na porta 8443
├── dmz-db/               # Banco de dados relacional PostgreSQL
│   └── init.sql          # Script SQL com schema das tabelas e carga inicial fictícia
└── firewall/             # Container Gateway e Filtro de Pacotes
    ├── Dockerfile        # Imagem Alpine com iptables e iproute2
    ├── entrypoint.sh     # Script de inicialização do container firewall
    └── rules.sh          # Script com regras completas de filtragem do Netfilter
```

---

## 9. Situação do Desenvolvimento

**Status atual:** Concluído e validado com sucesso.

As configurações de rede, as regras do firewall, os procedimentos de execução e os resultados dos testes foram implementados e validados no ambiente simulado. O laboratório atende integralmente a todas as exigências do Trabalho Parcial da disciplina.

---

## 10. Contexto Acadêmico

**Instituição:** Instituto Federal Goiano — Campus Ceres  
**Curso:** Bacharelado em Sistemas de Informação  
**Disciplina:** Segurança da Informação  
**Docente:** Prof. Roitier Campos Gonçalves  
**Tema:** Firewall Linux, arquitetura Netfilter e iptables  
**Discente:** Elenilton  

Projeto acadêmico individual.