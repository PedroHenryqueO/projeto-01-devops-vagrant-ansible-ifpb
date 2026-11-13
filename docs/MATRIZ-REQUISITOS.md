# Matriz de requisitos — validação final

Atualizada em 12/11/2026. Fonte: enunciado e verificador originais do professor, preservados localmente. Resultados reais do ambiente atual; reprodução integral em clone limpo ainda não executada.

Esta matriz resume os resultados comprovados no ambiente original. A documentação de execução e a síntese das validações estão no README.md; registros operacionais e evidências brutas permanecem locais, fora do versionamento.

| ID | Requisito | Componente | Resultado comprovado | Estado | Pendência |
|---|---|---|---|---|---|
| V01 | Quatro VMs arq, db, app, cli | Vagrant | Quatro VMs reais; configuração principal consolidada; redes e recursos preservados após reboot | Testado | — |
| V02 | Provider VirtualBox | Todas | Quatro VMs reais; configuração principal consolidada; redes e recursos preservados após reboot | Testado | — |
| V03 | Box debian/bookworm64 | Todas | Quatro VMs reais; configuração principal consolidada; redes e recursos preservados após reboot | Testado | — |
| V04 | Não substituir chave da box | SSH Vagrant | Quatro VMs reais; configuração principal consolidada; redes e recursos preservados após reboot | Testado | — |
| V05 | Gatilho desabilita DHCP VirtualBox | Host-only | DHCP VirtualBox permanece desabilitado; gatilho validado por execução e simulação | Testado | — |
| V06 | Linked clones | Todas | Quatro VMs reais; configuração principal consolidada; redes e recursos preservados após reboot | Testado | — |
| V07 | Não verificar Guest Additions | Todas | Quatro VMs reais; configuração principal consolidada; redes e recursos preservados após reboot | Testado | — |
| V08 | RAM 512/512/512/1024 MB | Todas | Quatro VMs reais; configuração principal consolidada; redes e recursos preservados após reboot | Testado | — |
| V09 | Três discos adicionais de 10 GB | arq | Três discos adicionais de 10 GiB vinculados a arq; atualmente PVs do VG dados | Testado | — |
| V10 | arq estático 192.168.56.120 | arq | Quatro VMs reais; configuração principal consolidada; redes e recursos preservados após reboot | Testado | — |
| V11 | db por reserva MAC | db | Quatro VMs reais; configuração principal consolidada; redes e recursos preservados após reboot | Testado | — |
| V12 | app por reserva MAC | app | Quatro VMs reais; configuração principal consolidada; redes e recursos preservados após reboot | Testado | — |
| V13 | cli por DHCP dinâmico | cli | Quatro VMs reais; configuração principal consolidada; redes e recursos preservados após reboot | Testado | — |
| V14 | Hostnames personalizados | Todas | Quatro VMs reais; configuração principal consolidada; redes e recursos preservados após reboot | Testado | — |
| G01 | Atualizar update e upgrade | Todas | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G02 | Chrony com pool.ntp.br | Todas | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G03 | Timezone America/Recife | Todas | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G04 | Grupo ifpb | Todas | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G05 | Usuários pedro e henryque | Todas | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G06 | Inclusão dos usuários no ifpb | Todas | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G07 | Sudo ao grupo ifpb | Todas | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G08 | SSH exclusivamente por chave | Todas | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G09 | Bloquear root via SSH | Todas | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G10 | AllowGroups vagrant ifpb | Todas | SSH negado para intruso com chave válida nas quatro VMs; conta removida ao final | Testado | — |
| G11 | Gerar/configurar chaves dos dois usuários | Todas/controlador | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G12 | Mensagem SSH exigida | Todas | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G13 | Cliente NFS | Todas | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G14 | Playbooks organizados/documentados | Ansible | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| G15 | Execução automatizada sem erros | Todas | Configuração aplicada nas quatro VMs; SSH/sudo/Chrony e persistência aprovados | Testado | — |
| H01 | DHCP autoritativo | arq | Concessões reais .121/.122/.50; DHCP autoritativo restrito a eth1; NAT preservado | Testado | — |
| H02 | Domínio pedro.henryque.devops | DHCP | Concessões reais .121/.122/.50; DHCP autoritativo restrito a eth1; NAT preservado | Testado | — |
| H03 | DNS 192.168.56.120 | DHCP | Concessões reais .121/.122/.50; DHCP autoritativo restrito a eth1; NAT preservado | Testado | — |
| H04 | Lease padrão 180 e máximo 3600 s | DHCP | dhcpd -t aprovado; configuração 180/3600 s; concessões reais obtidas | Testado | — |
| H05 | Rede /24 e pool .50–.100 | DHCP | Concessões reais .121/.122/.50; DHCP autoritativo restrito a eth1; NAT preservado | Testado | — |
| H06 | Anunciar gateway .1 | DHCP/rotas | Opção routers .1 configurada; hook privado preserva default NAT 10.0.2.2 | Testado | — |
| H07 | Reservas para db e app por MAC | DHCP | Concessões reais .121/.122/.50; DHCP autoritativo restrito a eth1; NAT preservado | Testado | — |
| H08 | DHCP só na interface privada | DHCP | Concessões reais .121/.122/.50; DHCP autoritativo restrito a eth1; NAT preservado | Testado | — |
| D01 | DNS autoritativo | arq | DNS direto/reverso e resolução externa funcionais nos convidados após reboot | Testado | — |
| D02 | Consultas aceitas da rede interna | DNS | DNS direto/reverso e resolução externa funcionais nos convidados após reboot | Testado | — |
| D03 | Forwarders 1.1.1.1 e 8.8.8.8 | DNS | DNS direto/reverso e resolução externa funcionais nos convidados após reboot | Testado | — |
| D04 | Zona direta para arq/db/app | DNS | DNS direto/reverso e resolução externa funcionais nos convidados após reboot | Testado | — |
| D05 | Zona reversa da rede | DNS | DNS direto/reverso e resolução externa funcionais nos convidados após reboot | Testado | — |
| D06 | Resolução do cli dinâmico | DHCP/DNS | Concessão dinâmica real de cli .50 com A/PTR por DDNS TSIG; persistente após reboot | Testado | — |
| D07 | Nomes entre VMs e hospedeiro | DNS/sistemas | NRPT restrita ao domínio criada com autorização; quatro nomes normais resolvidos Windows/WSL; HTTPS externo 200; DNS gerais preservados | Testado | — |
| L01 | PVs nos três discos adicionais | arq/LVM | Três PVs de 10 GiB, VG dados, LV ifpb 15 GiB ext4; /dados persistente após reboot | Testado | — |
| L02 | VG dados | arq/LVM | Três PVs de 10 GiB, VG dados, LV ifpb 15 GiB ext4; /dados persistente após reboot | Testado | — |
| L03 | LV ifpb de 15 GB | arq/LVM | Três PVs de 10 GiB, VG dados, LV ifpb 15 GiB ext4; /dados persistente após reboot | Testado | — |
| L04 | Sistema de arquivos ext4 | arq/LVM | Três PVs de 10 GiB, VG dados, LV ifpb 15 GiB ext4; /dados persistente após reboot | Testado | — |
| L05 | Montagem persistente em /dados | arq/LVM | Três PVs de 10 GiB, VG dados, LV ifpb 15 GiB ext4; /dados persistente após reboot | Testado | — |
| F01 | Exportar /dados/nfs à rede /24 | arq/NFS | NFS ativo após reboot; export sync/all_squash; escrita e leitura reais; UID/GID 2048 | Testado | — |
| F02 | Usuário nfs-ifpb sem shell | arq/NFS | NFS ativo após reboot; export sync/all_squash; escrita e leitura reais; UID/GID 2048 | Testado | — |
| F03 | Escrita local só por nfs-ifpb | arq/NFS | NFS ativo após reboot; export sync/all_squash; escrita e leitura reais; UID/GID 2048 | Testado | — |
| F04 | Mapear usuários remotos para nfs-ifpb | arq/NFS | NFS ativo após reboot; export sync/all_squash; escrita e leitura reais; UID/GID 2048 | Testado | — |
| F05 | Gravações síncronas | arq/NFS | NFS ativo após reboot; export sync/all_squash; escrita e leitura reais; UID/GID 2048 | Testado | — |
| F06 | NFS depende de /dados | arq/systemd | NFS ativo após reboot; export sync/all_squash; escrita e leitura reais; UID/GID 2048 | Testado | — |
| B01 | MariaDB instalado/funcionando | db | MariaDB SELECT 1 e autofs NFS aprovados após reboot | Testado | — |
| B02 | autofs NFS em /var/nfs | db | MariaDB SELECT 1 e autofs NFS aprovados após reboot | Testado | — |
| A01 | Apache2 funcional | app | Apache HTTP 200, identidade acadêmica e autofs aprovados após reboot | Testado | — |
| A02 | Página com descrição/nome/matrícula | app | Apache HTTP 200, identidade acadêmica e autofs aprovados após reboot | Testado | — |
| A03 | autofs NFS em /var/nfs | app | Apache HTTP 200, identidade acadêmica e autofs aprovados após reboot | Testado | — |
| C01 | firefox-esr e xauth | cli | Firefox ESR/xauth instalados; autofs funcional após reboot | Testado | — |
| C02 | Encaminhamento X11 SSH | cli/controlador | SSH -X e xdpyinfo aprovados; aluno confirmou visualmente a página no Firefox em 12/11/2026 | Testado | — |
| C03 | autofs NFS em /var/nfs | cli | Firefox ESR/xauth instalados; autofs funcional após reboot | Testado | — |
| O01 | README com identificação e execução | Repositório | README completo com identificação, implantação, operação, testes e limitações | Implementado | Reprodução integral em ambiente novo não executada |
| O02 | Inventário/configuração Ansible | Controlador | Inventário e ansible.cfg usados com sucesso nas quatro VMs | Testado | — |
| O03 | Playbooks e arquivos de configuração | Repositório | Roles, templates, scripts e dependências organizados; execução real sem falhas | Testado | — |
| O04 | Publicação GitHub | Repositório | Destino aprovado: [PedroHenryqueO/projeto-01-devops-vagrant-ansible-ifpb](https://github.com/PedroHenryqueO/projeto-01-devops-vagrant-ansible-ifpb), público, branch main | Entrega | Conferir publicação, arquivos e histórico no destino indicado |
| T01 | Validação sintática da proposta | Vagrant | Sintaxe do Vagrantfile principal aprovada | Testado | — |
| T02 | Conectividade Ansible WSL→VMs | Controlador/convidados | Conexões Ansible/SSH aprovadas nas quatro VMs; comandos no README | Testado | — |
| T03 | Idempotência | Ansible | arq ok=60; db ok=25; app ok=26; cli ok=24; todos changed=0, failed=0, unreachable=0 | Testado | — |
| T04 | Persistência após reboot | Todas | Reinícios normais individuais arq/db/app/cli; serviços e kernel 6.1.0-54-amd64 confirmados | Testado | — |
| T05 | Verificador original preservado | Testes | Reexecutado em 12/11/2026 com DNS normal e cli 2 CPUs/1024 MB; hash original preservado, código 0 e STDERR vazio; NFS restaurado por hash/metadados, intruso/home/chave ausentes nas quatro VMs | Testado | Código 0 não é nota; quoting/erros ocultos e Firefox assíncrono limitam o verificador; testes independentes anteriores preservados |
| T06 | Proteger chaves e estado local | Repositório/controlador | Privadas/TSIG fora do Git; estado, discos, logs e originais sem licença excluídos | Implementado | Inspeção de 50 arquivos sem artefatos proibidos; reexaminar alterações futuras |
| T07 | Validar configuração da proposta | Vagrant | Vagrant validate com metadados vazios e simulação de gatilhos; não cria VMs | Testado | Não equivale a reprodução integral limpa |
