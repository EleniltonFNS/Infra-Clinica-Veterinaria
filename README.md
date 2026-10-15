# Relatório Técnico: Firewall Linux com Netfilter e iptables
**Infraestrutura de Rede Segmentada — Clínica Veterinária Pata Amiga**

**Instituição:** Instituto Federal Goiano — Campus Ceres  
**Curso:** Bacharelado em Sistemas de Informação  
**Disciplina:** Segurança da Informação  
**Docente:** Prof. Roitier Campos Gonçalves  
**Discente:** Elenilton  
**Tema:** Firewall Linux, Arquitetura Netfilter & iptables  
**Data da Entrega:** 15/10/2026  
**Repositório:** [github.com/EleniltonFNS/Infra-Clinica-Veterinaria](https://github.com/EleniltonFNS/Infra-Clinica-Veterinaria)  

---

## 1. Definição do Case

### 1.1. Descrição da Empresa e Contexto de Negócio
A **Clínica Veterinária Pata Amiga** é uma organização fictícia prestadora de serviços médico-veterinários de pequeno porte que realiza atendimentos ambulatoriais, internações, consultas preventivas e procedimentos cirúrgicos em pequenos animais (cães e gatos).

Para suportar suas atividades operacionais, a clínica atende a dois perfis de usuários com diferentes níveis de autorização:
1. **Tutores dos Animais (Clientes / Rede Externa):** Proprietários dos pets que acessam remotamente o portal institucional da clínica a partir da internet para consultar serviços, verificar especialidades e solicitar agendamento de consultas.
2. **Médicos-Veterinários (Corpo Clínico Interno / Rede Local LAN):** Profissionais de saúde que atuam fisicamente dentro dos consultórios da clínica e utilizam as estações de trabalho locais para acessar o portal institucional e o sistema de prontuário eletrônico, registrando diagnósticos, acompanhando retornos e consultando históricos médicos.

### 1.2. Serviços em Operação na Infraestrutura
Para viabilizar essas atividades, a infraestrutura mantém três serviços principais em operação:
* **Portal de Agendamento Web (`dmz-web`):** Servidor web Nginx que atende nas portas TCP 80 (HTTP) e TCP 443 (HTTPS com certificado TLS de laboratório), disponibilizando a página pública de agendamento online.
* **Sistema de Prontuário Eletrônico (`dmz-prontuario`):** API REST simulada em Nginx que escuta exclusivamente na porta TCP 8443 com HTTPS, responsável por simular o acesso restrito a dados clínicos e diagnósticos, devolvendo um registro JSON fixo de demonstração aos profissionais autorizados.
* **Banco de Dados Centralizado (`dmz-db`):** Servidor relacional PostgreSQL 16 na porta TCP 5432, responsável pelo armazenamento estruturado de tabelas de tutores, pacientes, consultas e prontuários (inicializado via script SQL com dados fictícios).

---

## 2. Diagnóstico: Cenário Atual vs. Proposta de Solução

### 2.1. Cenário Atual (Problemas e Riscos Mapeados)
Em uma infraestrutura sem controle de perímetro (rede plana não segmentada), todas as estações de trabalho, clientes e servidores compartilham o mesmo espaço de rede sem barreiras de tráfego. Esse cenário apresenta falhas críticas de segurança:
* **Falta de Segmentação e Ausência de Controle de Acesso:** Qualquer dispositivo conectado consegue enviar pacotes diretamente para qualquer outro computador ou porta de serviço.
* **Risco de Violação de Sigilo Clínico e LGPD:** Um tutor conectado à rede de visitantes conseguiria alcançar a porta do sistema de prontuários e ler históricos médicos de outros animais, ferindo o sigilo profissional veterinário e a legislação de proteção de dados.
* **Exposição Direta do Banco de Dados:** A porta do PostgreSQL (TCP 5432) ficaria aberta a varreduras de rede (`nmap`), tentativas de invasão e ataques de força bruta vindos de estações não autorizadas.
* **Risco de Movimentação Lateral:** Caso o servidor web público venha a ser comprometido por uma vulnerabilidade de aplicação, um invasor poderia usá-lo como pivô para atacar as máquinas dos médicos na rede interna.

### 2.2. Proposta de Solução e Justificativa da Arquitetura Adotada
A solução implementada adota o modelo de **Defesa em Profundidade (*Defense-in-Depth*)** e o **Princípio do Menor Privilégio**, isolando os sistemas em três zonas lógicas conectadas por um contêiner firewall intermediário:

1. **Rede Externa (`external` - `10.77.3.0/24`):** Zona desconfiada onde reside a estação cliente do Tutor (`10.77.3.10`). Seu tráfego é restrito exclusivamente ao portal web institucional.
2. **Rede Interna LAN (`lan` - `10.77.1.0/24`):** Zona corporativa interna onde reside a estação de trabalho do Médico-veterinário (`10.77.1.10`). Possui autorização para acessar o portal web e o prontuário eletrônico.
3. **Zona Desmilitarizada DMZ (`dmz` - `10.77.2.0/24`):** Zona intermediária controlada onde residem os servidores (`dmz-web`, `dmz-prontuario` e `dmz-db`). A DMZ isola os servidores e tem como regra estrita nunca iniciar novas conexões contra as redes internas.
4. **Contêiner Firewall Linux (`firewall`):** Atua como roteador exclusivo entre as três redes, possuindo interfaces em cada uma (`10.77.1.254`, `10.77.2.254` e `10.77.3.254`). O contêiner opera com capacidade administrativa `cap_add: [NET_ADMIN]` e roteamento IPv4 habilitado (`net.ipv4.ip_forward: "1"`), aplicando regras de filtragem *stateful* via Netfilter/iptables.

### 2.3. Topologia da Rede Segmentada
```text
                  ┌──────────────────────────────┐
                  │    Rede EXTERNA (external)   │
                  │   Tutor: 10.77.3.10          │
                  └──────────────┬───────────────┘
                                 │
                                 ▼ (eth1 / 10.77.3.254)
┌────────────────────────────────┴──────────────────────────────┐
│                    CONTAINER FIREWALL LINUX                   │
│         (Alpine Linux 3.22 + Netfilter / iptables)            │
│                 Política Padrão: DROP                         │
└────────────────┬──────────────────────────────┬───────────────┘
  (eth2 / .254)  │                              │  (eth0 / .254)
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

| Zona de Rede | Sub-rede CIDR | Gateway (Firewall) | Container | IP Estático | Finalidade |
|---|---|---|---|---|---|
| **Rede Externa (`external`)** | `10.77.3.0/24` | `10.77.3.254` | `tutor` | `10.77.3.10` | Estação cliente do tutor de animais. |
| **Rede LAN (`lan`)** | `10.77.1.0/24` | `10.77.1.254` | `medico` | `10.77.1.10` | Estação interna de trabalho do médico-veterinário. |
| **Rede DMZ (`dmz`)** | `10.77.2.0/24` | `10.77.2.254` | `dmz-web` | `10.77.2.10` | Servidor Nginx com o portal público institucional. |
| **Rede DMZ (`dmz`)** | `10.77.2.0/24` | `10.77.2.254` | `dmz-prontuario` | `10.77.2.12` | API REST simulada de prontuário eletrônico. |
| **Rede DMZ (`dmz`)** | `10.77.2.0/24` | `10.77.2.254` | `dmz-db` | `10.77.2.11` | Banco de dados PostgreSQL 16 isolado de acessos diretos. |
| **Firewall / Roteador** | *(Todas as 3 redes)* | — | `firewall` | `10.77.1.254`<br>`10.77.2.254`<br>`10.77.3.254` | Roteador e filtro de pacotes centralizado via iptables. |

> **Nota sobre o Roteamento e Interfaces:**  
> O isolamento entre as três zonas utiliza `driver_opts: com.docker.network.bridge.gateway_mode_ipv4: routed` e scripts de entrypoint que substituem a rota padrão de cada máquina (`ip route replace default via <IP_FIREWALL>`). Vale ressaltar que o tráfego estritamente interno dentro da DMZ (Camada 2 / intra-subnet) ocorre diretamente através da bridge local; o Firewall atua de forma mandatória sobre todo e qualquer tráfego que cruze as fronteiras entre zonas distintas (Camada 3 / roteado). Além disso, como a ordem de mapeamento dos nomes de placas (`eth0`, `eth1`, `eth2`) não é garantida pelo Docker na subida dos contêineres, o script [`firewall/rules.sh`](firewall/rules.sh) descobre dinamicamente a interface física correspondente a cada sub-rede usando `ip addr show` e `awk`.

---

## 3. Matriz de Regras de Segurança (Firewall)

A política de segurança implementada no firewall adota a abordagem restritiva padrão **Default Deny (DROP)** para as cadeias `INPUT` e `FORWARD`. Apenas o tráfego essencial ao funcionamento do negócio é liberado explicitamente.

### 3.1. Matriz de Regras Implementadas
| Origem | Destino | Porta / Protocolo | Ação (ACCEPT/DROP) | Justificativa do Negócio |
|---|---|---|:---:|---|
| **Políticas Padrão** | | | | |
| Qualquer | Qualquer (em trânsito) | Qualquer | **DROP** | **Política padrão FORWARD:** bloqueia todo tráfego entre zonas não liberado explicitamente. |
| Qualquer | Firewall local | Qualquer | **DROP** | **Política padrão INPUT:** descarta pacotes destinados ao sistema operacional do firewall. |
| Firewall local | Qualquer | Qualquer | **ACCEPT** | **Política padrão OUTPUT:** autoriza o firewall a gerar pacotes próprios quando necessário. |
| **Autoproteção do Firewall (INPUT / OUTPUT)** | | | | |
| Loopback (`lo`) | Loopback (`lo`) | Qualquer | **ACCEPT** | Permitir a comunicação interna de processos locais do próprio firewall. |
| Qualquer | Firewall local | Conexões `INVALID` | **DROP** | Autoproteção: descarte de pacotes anômalos direcionados ao contêiner firewall. |
| Qualquer | Firewall local | `ESTABLISHED,RELATED` | **ACCEPT** | Permitir respostas a comunicações legítimas iniciadas pelo próprio firewall. |
| **Regras de Trânsito entre Zonas (FORWARD)** | | | | |
| Rede Cliente Externa (`tutor`) | DMZ (`dmz-web`) | TCP 80, 443 | **ACCEPT** | Permitir que os tutores acessem o portal web para consulta e agendamentos. |
| Rede Cliente LAN (`medico`) | DMZ (`dmz-web`) | TCP 80, 443 | **ACCEPT** | Permitir que os médicos veterinários acessem o portal institucional. |
| Rede Cliente LAN (`medico`) | DMZ (`dmz-prontuario`) | TCP 8443 | **ACCEPT** | Permitir que o médico acesse a API de prontuários clínicos e diagnósticos. |
| Rede Cliente Externa (`tutor`) | DMZ (`dmz-prontuario`) | Qualquer | **DROP** | **Bloqueio de segurança:** impedir o acesso de tutores aos prontuários clínicos (LGPD). |
| Rede Cliente (LAN / Externa) | DMZ (`dmz-db`) | Qualquer porta / protocolo (ex.: TCP 5432, ICMP) | **DROP** | **Bloqueio de segurança:** acesso direto ao banco bloqueado para clientes; restrito aos servidores da DMZ. |
| Rede Cliente Externa (`tutor`) | Rede LAN (`medico`) | Qualquer | **DROP** | Isolar totalmente o tráfego da rede de clientes externos da intranet médica. |
| Rede Cliente LAN (`medico`) | Rede Externa (`tutor`) | Qualquer | **DROP** | Impedir comunicações não roteadas entre estações internas e clientes externos. |
| Rede DMZ (Servidores) | Qualquer outra rede (LAN / Externa) | Conexões `NEW` | **DROP** | **Regra de Ouro da DMZ:** a DMZ nunca inicia conexões novas para as redes internas. |
| Qualquer | Qualquer | Conexões `INVALID` | **DROP** | Higiene de rede: descarte de pacotes órfãos, fora de ordem ou varreduras maliciosas. |
| Qualquer | Qualquer | `ESTABLISHED,RELATED` | **ACCEPT** | **Firewall Stateful:** permite o retorno legítimo de conexões previamente autorizadas. |
| Interface Externa | Qualquer | Origem fora de `10.77.3.0/24` | **DROP** | **Anti-spoofing:** impede forja de IP interno vindo da rede externa. |
| Interface LAN | Qualquer | Origem fora de `10.77.1.0/24` | **DROP** | **Anti-spoofing:** impede forja de IP externo vindo da interface local. |
| Interface DMZ | Qualquer | Origem fora de `10.77.2.0/24` | **DROP** | **Anti-spoofing:** impede que servidores da DMZ forjem IPs de outras zonas. |

---

## 4. Metodologia de Testes e Validação

### 4.1. Passo a Passo de Execução do Ambiente (Para o Avaliador)
**Pré-requisitos do ambiente:** Docker Engine 27.1+ (necessário para suporte à opção de rede `gateway_mode_ipv4: routed`) e Docker Compose v2.

#### Passo 0: Criar o arquivo de variáveis de ambiente
Como o arquivo `.env` não é versionado no Git por questões de segurança, crie-o a partir do modelo de exemplo:
```bash
cp .env.example .env
```
*(No prompt do Windows PowerShell / CMD, utilize `copy .env.example .env`).*

#### Passo 1: Inicializar toda a infraestrutura
```bash
docker compose up -d --build
```

#### Passo 2: Verificar o status dos contêineres
```bash
docker compose ps
```
*Saída esperada: todos os seis serviços (`firewall`, `dmz-web`, `dmz-prontuario`, `dmz-db`, `medico`, `tutor`) com status `Up`.*

#### Passo 3: Encerrar e limpar o ambiente ao final dos testes
```bash
docker compose down -v
```

---

### 4.2. Testes Positivos (O que deve funcionar)
Demonstram as comunicações autorizadas pelo firewall:

* **P1. Acesso HTTP ao portal web (porta 80):**
  * Médico: `docker compose exec -T medico curl -fsS http://dmz-web/` (ou `http://10.77.2.10/`) ➔ **Retorna o HTML da clínica (HTTP 200)**.
  * Tutor: `docker compose exec -T tutor curl -fsS http://dmz-web/` (ou `http://10.77.2.10/`) ➔ **Retorna o HTML da clínica (HTTP 200)**.
* **P2. Acesso HTTPS ao portal web (porta 443 com certificado TLS):**
  * Médico: `docker compose exec -T medico curl -fsSk https://dmz-web/` (ou `https://10.77.2.10/`) ➔ **Retorna o HTML da clínica (HTTP 200)**.
  * Tutor: `docker compose exec -T tutor curl -fsSk https://dmz-web/` (ou `https://10.77.2.10/`) ➔ **Retorna o HTML da clínica (HTTP 200)**.
* **P3. Acesso ao Prontuário Clínico (exclusivo do Médico):**
  * Médico: `docker compose exec -T medico curl -fsSk https://dmz-prontuario:8443/api/prontuarios/1` (ou `https://10.77.2.12:8443/...`)  
    ➔ **Retorna o diagnóstico fictício do paciente Thor (Otite externa) em formato JSON**.

---

### 4.3. Testes Negativos (O que deve ser bloqueado)
Demonstram os bloqueios de segurança e a contenção do firewall:

* **N1. Tutor bloqueado no Prontuário Clínico:**
  * Tutor: `docker compose exec -T tutor curl -m 3 https://dmz-prontuario:8443/api/prontuarios/1`  
    ➔ **Resultado: Operação expira por timeout (código 28)**, comprovando o descarte silencioso (`DROP`) do firewall.
* **N2. Bloqueio de acesso direto ao Banco de Dados (TCP 5432):**
  * Médico: `docker compose exec -T medico curl -m 3 http://dmz-db:5432/` ➔ **Timeout (filtrado / DROP)**.
  * Tutor: `docker compose exec -T tutor curl -m 3 http://dmz-db:5432/` ➔ **Timeout (filtrado / DROP)**.
* **N3. Bloqueio de ping ICMP para o Banco de Dados:**
  * Médico: `docker compose exec -T medico ping -c 1 -W 2 dmz-db` ➔ **100% packet loss (sem resposta)**.
* **N4. Bloqueio de comunicação direta entre estações:**
  * Médico pingando Tutor: `docker compose exec -T medico ping -c 1 -W 2 10.77.3.10` ➔ **Descartado pelo firewall**.
* **N5. Varredura com nmap no Banco de Dados (a partir do cliente):**
  * `docker compose exec -T medico nmap -Pn -p 5432 dmz-db` (ou `10.77.2.11`)  
    ➔ **Resultado: `5432/tcp filtered postgresql`** (a porta não responde porque o firewall descarta a sondagem).

---

### 4.4. Execução dos Scripts Automatizados de Teste
Cada contêiner cliente possui utilitários de teste pré-instalados em `/usr/local/bin/` (`testar` e `varredura`).

**1. Bateria automatizada de conformidade (`testar`):**
```bash
# Executar a partir da estação do médico:
docker compose exec -T medico testar

# Executar a partir da estação do tutor:
docker compose exec -T tutor testar
```

*Resultado real obtido nos dois testes (7 passaram, 0 falharam):*
```text
=================================================================
  BATERIA DE TESTES DE SEGURANÇA - PERFIL: medico
=================================================================

--- 1. Testes Positivos (Conexões Autorizadas)
[PASSOU] P1: Acesso HTTP ao portal web (dmz-web:80)              [ACCEPT]
[PASSOU] P2: Acesso HTTPS ao portal web (dmz-web:443)            [ACCEPT]
[PASSOU] P3: Medico acessa prontuario clinico (:8443)            [ACCEPT]

--- 2. Testes Negativos (Bloqueios de Segurança Obrigatórios)
[PASSOU] N1: Bloqueio de acesso direto ao banco de dados (:5432) [DROP]
[PASSOU] N2: Bloqueio de ping para o banco de dados              [DROP]
[PASSOU] N3: Bloqueio de comunicacao direta entre estacoes       [DROP]
[PASSOU] N4: Varredura nmap confirma banco como filtered         [DROP]

=================================================================
  RESUMO DOS TESTES (medico): 7 passaram, 0 falharam
=================================================================
```

```text
=================================================================
  BATERIA DE TESTES DE SEGURANÇA - PERFIL: tutor
=================================================================

--- 1. Testes Positivos (Conexões Autorizadas)
[PASSOU] P1: Acesso HTTP ao portal web (dmz-web:80)              [ACCEPT]
[PASSOU] P2: Acesso HTTPS ao portal web (dmz-web:443)            [ACCEPT]
[PASSOU] P3: Tutor BLOQUEADO no prontuario (:8443)               [DROP]

--- 2. Testes Negativos (Bloqueios de Segurança Obrigatórios)
[PASSOU] N1: Bloqueio de acesso direto ao banco de dados (:5432) [DROP]
[PASSOU] N2: Bloqueio de ping para o banco de dados              [DROP]
[PASSOU] N3: Bloqueio de comunicacao direta entre estacoes       [DROP]
[PASSOU] N4: Varredura nmap confirma banco como filtered         [DROP]

=================================================================
  RESUMO DOS TESTES (tutor): 7 passaram, 0 falharam
=================================================================
```

**2. Demonstração de varredura de portas com nmap (`varredura`):**
```bash
docker compose exec -T medico varredura
```
*O script executa varreduras de portas nos três servidores da DMZ, evidenciando as portas abertas (`80/tcp`, `443/tcp` no web; `8443/tcp` no prontuário) e as portas filtradas/bloqueadas (`5432/tcp` no banco).*

---

### 4.5. Auditoria dos Contadores de Regras no Netfilter/iptables
A prova real de funcionamento é consultada nos contadores de pacotes e bytes do kernel Linux no contêiner `firewall`:
```bash
docker compose exec -T firewall iptables -L FORWARD -n -v --line-numbers
```

*Saída real dos contadores após a execução dos testes:*
```text
Chain FORWARD (policy DROP 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination         
1        0     0 DROP       all  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate INVALID
2        0     0 DROP       all  --  eth1   *      !10.77.3.0/24         0.0.0.0/0            /* Anti-spoofing rede externa */
3        0     0 DROP       all  --  eth2   *      !10.77.1.0/24         0.0.0.0/0            /* Anti-spoofing LAN */
4        0     0 DROP       all  --  eth0   *      !10.77.2.0/24         0.0.0.0/0            /* Anti-spoofing DMZ */
5       74 21456 ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
6        2   120 ACCEPT     tcp  --  eth1   eth0    10.77.3.10           10.77.2.10           multiport dports 80,443 ctstate NEW
7        2   120 ACCEPT     tcp  --  eth2   eth0    10.77.1.10           10.77.2.10           multiport dports 80,443 ctstate NEW
8        1    60 ACCEPT     tcp  --  eth2   eth0    10.77.1.10           10.77.2.12           tcp dpt:8443 ctstate NEW
9        3   180 DROP       all  --  eth1   eth0    0.0.0.0/0            10.77.2.12           /* Tutor bloqueado no prontuario */
10      14   840 DROP       all  --  *      eth0    0.0.0.0/0            10.77.2.11           /* Clientes bloqueados no banco */
11       1    84 DROP       all  --  eth1   eth2    0.0.0.0/0            0.0.0.0/0            /* Trafego externo para LAN bloqueado */
12       1    84 DROP       all  --  eth2   eth1    0.0.0.0/0            0.0.0.0/0            /* Trafego LAN para externa bloqueado */
13       0     0 DROP       all  --  eth0   *       0.0.0.0/0            0.0.0.0/0            ctstate NEW /* DMZ nao inicia conexao para dentro */
```

* **Regra 5 (`RELATED,ESTABLISHED`):** Acumulou **74 pacotes (21.456 bytes)**, provando que o tráfego de retorno legítimo foi mantido pelo módulo de conntrack do firewall stateful.
* **Regras 6, 7 e 8:** Registraram os handshakes SYN das novas conexões aceitas para o portal e o prontuário.
* **Regras 9, 10, 11 e 12:** Registraram os pacotes descartados (`DROP`) das tentativas de acesso do tutor ao prontuário, do acesso direto ao PostgreSQL e dos pings cruzados entre zonas.
* **Por que as regras 2, 3, 4 e 13 aparecem com 0 pacotes?**  
  Em condições normais de operação, as estações clientes legítimas não forjam endereços IP de outras zonas e os servidores da DMZ não iniciam ataques contra a LAN. O contador zero nessas regras é o comportamento esperado de uma rede íntegra.

---

### 4.6. Testes Especiais: Simulação de Spoofing e Regra de Ouro da DMZ
Para evidenciar o funcionamento das regras de segurança preventiva que permanecem com contador zero em tráfego normal, os seguintes testes forçam o disparo dessas regras:

* **N6. Simulação de IP Spoofing (Anti-spoofing da interface externa):**
  * Tutor forjando o IP do médico (`10.77.1.10`):  
    `docker compose exec -T tutor sh -c 'ip addr add 10.77.1.10/32 dev eth0; curl -k -m 3 --interface 10.77.1.10 https://10.77.2.12:8443/api/prontuarios/1; echo codigo_de_saida=$?; ip addr del 10.77.1.10/32 dev eth0'`  
    ➔ **Resultado: Timeout (código 28)**. O firewall detecta que o pacote entrou pela interface externa (`eth1`) com IP forjado fora da sub-rede externa (`! -s 10.77.3.0/24`) e descarta na **Regra 2** (`Anti-spoofing rede externa`), incrementando seu contador.
* **N7. Simulação de Violação da Regra de Ouro da DMZ:**
  * Servidor web tentando iniciar conexão ativa contra a estação do médico na LAN:  
    `docker compose exec -T dmz-web curl -m 3 http://10.77.1.10:80/`  
    ➔ **Resultado: Timeout (código 28)**. O firewall intercepta o pacote com estado `NEW` vindo da interface da DMZ (`eth0`) e descarta silenciosamente na **Regra 13** (`DMZ nao inicia conexao para dentro`), incrementando seu contador.

---

## 5. Estrutura do Repositório

```text
.
├── .env                  # Variáveis locais de IP e sub-redes (não versionado; criado a partir do .env.example)
├── .env.example          # Modelo oficial de variáveis de ambiente para reprodução do ambiente
├── .gitattributes        # Padronização de quebra de linha LF para scripts Linux
├── .gitignore            # Arquivos temporários e de editores ignorados pelo Git
├── docker-compose.yml    # Orquestração dos containers, volumes e redes bridge roteadas
├── README.md             # Relatório técnico oficial do projeto (4 seções do edital)
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