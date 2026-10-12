# Firewall Linux com Netfilter e iptables — Clínica Veterinária Pata Amiga

## 1. Apresentação do Projeto

O **Firewall Linux — Clínica Veterinária Pata Amiga** é um projeto acadêmico desenvolvido para a disciplina de Segurança da Informação do curso de Bacharelado em Sistemas de Informação do Instituto Federal Goiano — Campus Ceres.

O projeto propõe a construção de uma infraestrutura de rede segmentada, utilizando Docker e Docker Compose, com um firewall Linux responsável por controlar o tráfego entre diferentes redes e serviços.

O cenário utilizado é uma clínica veterinária fictícia chamada Pata Amiga, que precisa disponibilizar seus sistemas aos usuários autorizados sem permitir acessos indevidos a informações restritas.

### Objetivos do projeto

- Implementar um ambiente de rede segmentado utilizando redes Docker isoladas.
- Configurar um container Linux para atuar como gateway e firewall.
- Utilizar Netfilter e iptables para estabelecer regras de filtragem de pacotes.
- Aplicar uma política de bloqueio por padrão, liberando explicitamente apenas os acessos necessários.
- Validar a configuração por meio de testes de conectividade permitida e bloqueada.

## 2. Definição do Cenário e Problema de Segurança

A clínica veterinária utiliza três serviços principais:

- **Portal de agendamento:** permite que os tutores consultem e solicitem agendamentos.
- **Prontuário eletrônico:** armazena informações clínicas dos animais e precisa ser acessível somente aos profissionais autorizados.
- **Banco de dados:** armazena informações utilizadas pelos sistemas e não deve ser acessado diretamente pelos usuários.

O cenário considera dois perfis de acesso:

**Tutor do animal:** acessa a rede externa e precisa utilizar o portal de agendamento, sem acesso direto ao prontuário eletrônico ou ao banco de dados.

**Médico-veterinário:** utiliza a rede interna da clínica e precisa acessar o portal e o prontuário eletrônico, sem acesso direto ao banco de dados.

### Problema identificado

Sem segmentação e regras de filtragem adequadas, um usuário pode tentar alcançar serviços que não fazem parte de suas permissões. A solução proposta é interpor um firewall entre as redes, controlar o encaminhamento de pacotes e permitir somente as comunicações previstas na política de segurança.

## 3. Arquitetura de Rede Proposta

O ambiente será simulado com containers Docker conectados a redes distintas, definidas no Docker Compose.

| Componente | Finalidade |
|---|---|
| Rede externa | Representar o acesso dos tutores ao portal. |
| Rede LAN | Representar a rede interna utilizada pelos médicos-veterinários. |
| Container Firewall | Encaminhar e filtrar o tráfego entre as redes, utilizando iptables. |
| Rede DMZ | Isolar os serviços disponibilizados pela clínica. |
| Portal de agendamento | Disponibilizar o serviço web nas portas TCP 80 e 443, conforme a configuração implementada. |
| Prontuário eletrônico | Disponibilizar o serviço restrito aos profissionais autorizados, previsto na porta TCP 8443. |
| Banco de dados | Manter os dados dos sistemas, previsto na porta TCP 5432, sem acesso direto pelos usuários. |

O container de firewall deverá possuir a capacidade administrativa `NET_ADMIN` e o encaminhamento IPv4 habilitado por meio de `net.ipv4.ip_forward=1`.

A segmentação deverá impedir que os usuários contornem as regras do firewall por meio de acessos diretos indevidos entre as redes.

*Nota: esta seção descreve a arquitetura planejada. A configuração efetiva será documentada e validada durante a implementação.*

## 4. Política de Segurança e Regras de Acesso

A política adotada será **bloquear por padrão e permitir explicitamente o necessário**, utilizando o alvo `DROP` como política padrão das cadeias de filtragem pertinentes.

A matriz abaixo representa os acessos planejados para o ambiente:

| Origem | Destino | Porta/Protocolo | Ação prevista | Justificativa |
|---|---|---|---|---|
| Rede externa | Portal na DMZ | TCP 80/443 | ACCEPT | Permitir o acesso dos tutores ao portal. |
| Rede externa | Prontuário na DMZ | TCP 8443 | DROP | Impedir o acesso dos tutores às informações clínicas. |
| Rede externa | Banco de dados na DMZ | TCP 5432 | DROP | Impedir o acesso direto ao banco de dados. |
| LAN | Portal na DMZ | TCP 80/443 | ACCEPT | Permitir o acesso dos profissionais ao portal. |
| LAN | Prontuário na DMZ | TCP 8443 | ACCEPT | Permitir o acesso dos profissionais ao prontuário. |
| LAN | Banco de dados na DMZ | TCP 5432 | DROP | Impedir o acesso direto ao banco de dados. |

As regras definitivas deverão considerar o caminho dos pacotes, as interfaces envolvidas e o rastreamento de conexões quando aplicável.

A matriz apresenta os resultados esperados. A documentação final deverá refletir as regras realmente implementadas e os resultados observados nos testes.

## 5. Tecnologias e Ferramentas Utilizadas

- **Docker:** execução dos serviços em containers isolados.
- **Docker Compose:** definição dos containers, das redes e de suas configurações.
- **Linux:** sistema utilizado no container de firewall.
- **Netfilter:** infraestrutura de filtragem de pacotes do kernel Linux.
- **iptables:** ferramenta utilizada para configurar as regras de filtragem.
- **Visual Studio Code:** edição e organização dos arquivos do projeto.
- **Git e GitHub Desktop:** controle de versão e registro da evolução do desenvolvimento.
- **GitHub:** armazenamento remoto do código e da documentação.

## 6. Execução do Ambiente

O ambiente deverá ser iniciado a partir do arquivo `docker-compose.yml`, que definirá os containers e as redes necessárias.

Após a implementação e a validação da configuração, o procedimento de inicialização previsto será:

```bash
docker compose up -d
```

Para conferir os containers em execução:

```bash
docker compose ps
```

Para consultar os registros de execução dos serviços:

```bash
docker compose logs
```

Para encerrar o ambiente:

```bash
docker compose down
```

**Importante:** estes comandos representam o procedimento de execução previsto. Eles somente poderão ser utilizados com sucesso depois que os arquivos de configuração necessários tiverem sido criados. As instruções definitivas serão atualizadas após os testes do ambiente.

## 7. Metodologia de Testes e Validação

A validação deverá demonstrar tanto os acessos autorizados quanto os bloqueios definidos na política de segurança.

### Testes positivos

- Verificar se o tutor consegue acessar o portal de agendamento.
- Verificar se o médico-veterinário consegue acessar o portal.
- Verificar se o médico-veterinário consegue acessar o prontuário eletrônico.

### Testes negativos

- Verificar se o tutor não consegue acessar o prontuário eletrônico.
- Verificar se os usuários não conseguem acessar diretamente o banco de dados.
- Verificar se a segmentação impede caminhos de acesso que contornem as regras do firewall.

Os resultados, os comandos utilizados, as evidências e eventuais ajustes serão documentados após a execução dos testes.

## 8. Estrutura do Repositório

A estrutura definitiva será apresentada conforme os arquivos forem criados e organizados durante o desenvolvimento.

O repositório deverá conter, no mínimo, o arquivo de configuração do Docker Compose, os arquivos necessários à configuração automática do firewall e a documentação do projeto.

## 9. Situação do Desenvolvimento

**Status atual:** fase inicial de estruturação do projeto.

As configurações de rede, as regras do firewall, os procedimentos de execução e os resultados dos testes serão documentados conforme sua implementação e validação.

Este repositório será atualizado com commits organizados, registrando a evolução do trabalho.

## 10. Contexto Acadêmico

**Instituição:** Instituto Federal Goiano — Campus Ceres  
**Curso:** Bacharelado em Sistemas de Informação  
**Disciplina:** Segurança da Informação  
**Docente:** Prof. Roitier Campos Gonçalves  
**Tema:** Firewall Linux, arquitetura Netfilter e iptables

Projeto acadêmico individual.