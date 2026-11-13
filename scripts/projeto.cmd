@echo off
setlocal
rem CMD evita mudar a politica Restricted de scripts PowerShell do hospedeiro.
pushd "%~dp0.." || exit /b 1
set "VAGRANT_VAGRANTFILE=Vagrantfile"
set "VAGRANT_DOTFILE_PATH=%CD%\.vagrant"
set "CHECKPOINT_DISABLE=1"
set "ASA_PROJ1_EXECUTION_APPROVED="
set "ASA_PROJ1_DHCP_CHANGE_APPROVED="
set "ASA_PROJ1_CLIENT_BOOTSTRAP_READY="
if "%~1"=="validate" goto validate
if "%~1"=="status" goto status
if "%~1"=="ssh-config" goto sshconfig
if "%~1"=="check-arq" goto checkarq
if "%~1"=="up-arq" goto uparq
if "%~1"=="up-db" goto db
if "%~1"=="up-app" goto app
if "%~1"=="up-cli" goto cli
echo Uso: scripts\projeto.cmd validate ^| status ^| ssh-config ^| check-arq
echo Apos aprovacao especifica: scripts\projeto.cmd up-arq --aprovar-vm --aprovar-dhcp
set "result=2"
goto finish
:validate
vagrant validate
goto capture
:status
vagrant status
goto capture
:sshconfig
vagrant ssh-config arq
goto capture
:checkarq
vagrant ssh arq -c "hostname -f; ip -4 address; ip -4 route; lsblk -b -o NAME,SIZE,TYPE,MOUNTPOINTS; python3 --version"
goto capture
:uparq
if not "%~2"=="--aprovar-vm" goto denied
if not "%~3"=="--aprovar-dhcp" goto denied
if not "%~4"=="" goto denied
rem Flags operacionais nao substituem a aprovacao humana da Etapa 4.4-B.
set "ASA_PROJ1_EXECUTION_APPROVED=1"
set "ASA_PROJ1_DHCP_CHANGE_APPROVED=1"
vagrant up arq --provider=virtualbox --no-provision
goto capture
:denied
echo Operacao bloqueada: faltam confirmacoes explicitas de VM e DHCP.
set "result=2"
goto finish
:db
set "client=db"
goto client
:app
set "client=app"
goto client
:cli
set "client=cli"
:client
if not "%~2"=="--aprovar-vm" goto denied
if not "%~3"=="--aprovar-dhcp" goto denied
set "ASA_PROJ1_EXECUTION_APPROVED=1"
set "ASA_PROJ1_DHCP_CHANGE_APPROVED=1"
set "ASA_PROJ1_CLIENT_BOOTSTRAP_READY=1"
vagrant up %client% --provider=virtualbox
goto capture
:capture
set "result=%errorlevel%"
:finish
popd
exit /b %result%
