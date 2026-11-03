@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

if not defined DOCKER_REPO_URL set "DOCKER_REPO_URL=https://github.com/TC-FIAP-SOAT-MECANICA/docker.git"
if not defined MS_MECANICA_REPO_URL set "MS_MECANICA_REPO_URL=https://github.com/TC-FIAP-SOAT-MECANICA/ms-mecanica.git"
if not defined DIRETORIO set "DIRETORIO=oficina-mecanica"
if not defined TIMEOUT_SEGUNDOS set "TIMEOUT_SEGUNDOS=300"
set "BRANCH=main"
set "SERVICO_API=ms-mecanica"
rem Mesmo nome do campo image do ms-mecanica no docker-compose.yml
set "IMAGEM_API=oficina-mecanica/ms-mecanica:latest"

rem Aberto pelo Explorer (duplo clique) a janela fecha ao terminar: nesse caso pausa antes de sair.
set "DUPLO_CLIQUE=0"
set "LINHA_CMD=%cmdcmdline:"=%"
if "%LINHA_CMD:~-1%"==" " set "DUPLO_CLIQUE=1"

:ler_opcoes
if "%~1"=="" goto opcoes_lidas
if /i "%~1"=="-h" goto ajuda
if /i "%~1"=="/?" goto ajuda
if /i "%~1"=="-d" (
    if "%~2"=="" (
        call :uso
        exit /b 1
    )
    set "DIRETORIO=%~2"
    shift
    shift
    goto ler_opcoes
)
call :uso
exit /b 1

:ajuda
call :uso
exit /b 0

:opcoes_lidas
call :info "Verificando pré-requisitos"
where git >nul 2>&1 || (set "MSG=git não encontrado. Instale em https://git-scm.com/downloads" & goto erro)
where docker >nul 2>&1 || (set "MSG=docker não encontrado. Instale o Docker Desktop: https://www.docker.com/products/docker-desktop" & goto erro)
set "COMPOSE="
docker compose version >nul 2>&1 && set "COMPOSE=docker compose"
if not defined COMPOSE (
    where docker-compose >nul 2>&1 && set "COMPOSE=docker-compose"
)
if not defined COMPOSE (set "MSG=Docker Compose não encontrado. Atualize o Docker Desktop ou instale o plugin compose." & goto erro)
docker info >nul 2>&1 || (set "MSG=o Docker não está rodando. Abra o Docker Desktop e execute o script de novo." & goto erro)
echo git, docker e %COMPOSE% disponíveis

set "PASTA_SCRIPT=%~dp0"
set "PASTA_SCRIPT=%PASTA_SCRIPT:~0,-1%"
set "USAR_CLONE_ATUAL=0"
if exist "%PASTA_SCRIPT%\docker-compose.yml" if exist "%PASTA_SCRIPT%\.git" set "USAR_CLONE_ATUAL=1"
if "%USAR_CLONE_ATUAL%"=="1" (
    call :info "Usando o repositório docker em %PASTA_SCRIPT%"
    cd /d "%PASTA_SCRIPT%"
) else (
    call :info "Baixando o repositório docker"
    set "MSG=falha ao baixar o repositório docker (%DOCKER_REPO_URL%)."
    call :clonar_ou_atualizar "%DOCKER_REPO_URL%" "%BRANCH%" "%DIRETORIO%" || goto erro
    cd /d "%DIRETORIO%" || (set "MSG=não foi possível entrar em %DIRETORIO%." & goto erro)
)

if not exist .env if exist .env.example (
    copy /y .env.example .env >nul
    echo Criado .env a partir do .env.example
)
set "API_PORT="
set "POSTGRES_PORT="
if exist .env (
    for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /c:"API_PORT=" .env`) do set "API_PORT=%%b"
    for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /c:"POSTGRES_PORT=" .env`) do set "POSTGRES_PORT=%%b"
)
if not defined API_PORT set "API_PORT=8080"
if not defined POSTGRES_PORT set "POSTGRES_PORT=5436"

call :info "Baixando o ms-mecanica"
if not exist services mkdir services
set "MSG=falha ao baixar o ms-mecanica (%MS_MECANICA_REPO_URL%)."
call :clonar_ou_atualizar "%MS_MECANICA_REPO_URL%" "%BRANCH%" "services\ms-mecanica" || goto erro

call :info "Verificando se a imagem %IMAGEM_API% já existe"
docker image inspect %IMAGEM_API% >nul 2>&1
if errorlevel 1 (
    echo Nenhuma imagem anterior encontrada
) else (
    echo Imagem encontrada: removendo o container da API e a imagem antiga
    %COMPOSE% rm -s -f %SERVICO_API% || (set "MSG=falha ao remover o container da API." & goto erro)
    docker image rm %IMAGEM_API% || (set "MSG=falha ao remover a imagem %IMAGEM_API%. Algum container fora deste projeto pode estar usando a imagem: veja com docker ps -a --filter ancestor=%IMAGEM_API%" & goto erro)
)

call :info "Compilando e subindo os containers (a primeira vez leva alguns minutos)"
%COMPOSE% up -d --build --remove-orphans || (set "MSG=falha ao subir os containers. Veja a saída acima." & goto erro)

call :info "Aguardando a API ficar saudável (até %TIMEOUT_SEGUNDOS%s)"
set "API_ID="
for /f "usebackq delims=" %%i in (`%COMPOSE% ps -q %SERVICO_API%`) do set "API_ID=%%i"
if not defined API_ID (set "MSG=container da API não foi criado. Veja: %COMPOSE% logs %SERVICO_API%" & goto erro)
set /a DECORRIDO=0

:aguardar_api
set "ESTADO="
for /f "usebackq delims=" %%s in (`docker inspect -f "{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}" %API_ID%`) do set "ESTADO=%%s"
if "%ESTADO%"=="healthy" goto api_pronta
if "%ESTADO%"=="unhealthy" goto api_falhou
if "%ESTADO%"=="exited" goto api_falhou
if "%ESTADO%"=="dead" goto api_falhou
if %DECORRIDO% geq %TIMEOUT_SEGUNDOS% (set "MSG=a API não ficou saudável em %TIMEOUT_SEGUNDOS%s (estado: %ESTADO%). Veja: %COMPOSE% logs %SERVICO_API%" & goto erro)
<nul set /p "=."
rem ping no lugar de timeout: timeout falha quando a entrada padrão está redirecionada
ping -n 6 127.0.0.1 >nul
set /a DECORRIDO+=5
goto aguardar_api

:api_falhou
set "MSG=a API ficou '%ESTADO%'. Veja o log com: %COMPOSE% logs %SERVICO_API%"
goto erro

:api_pronta
echo  pronto
echo.
%COMPOSE% ps

echo.
echo Tudo no ar! (ms-mecanica na branch %BRANCH%)
echo.
echo   API         http://localhost:%API_PORT%/api/v1
echo               login: POST /auth/login com o ADMIN do .env (padrão admin@oficina.com / admin12345)
echo   Contrato    http://localhost:%API_PORT%/api/v1/oficina-mecanica-contract.yaml
echo   Métricas    http://localhost:%API_PORT%/api/v1/actuator/prometheus
echo   PostgreSQL  localhost:%POSTGRES_PORT% (usuário e senha do .env, padrão oficina / oficina)
echo.
echo Collection do Postman: %CD%\services\ms-mecanica\postman\oficina-mecanica.postman_collection.json
echo.
echo Comandos úteis (dentro de %CD%):
call :comando "%COMPOSE% logs -f %SERVICO_API%" "log da API"
call :comando "setup.bat" "atualiza o código e reconstrói"
call :comando "%COMPOSE% down" "para tudo (mantém os dados)"
call :comando "%COMPOSE% down -v" "para tudo e apaga os dados"
call :pausar
exit /b 0

rem ---------------------------------------------------------------------------

:uso
echo Uso: setup.bat [-d diretorio]
echo.
echo Baixa a branch main do repositório docker e do ms-mecanica e sobe tudo no Docker (API e PostgreSQL).
echo Rodado de dentro de um clone do repositório docker, usa esse clone.
echo.
echo   -d diretorio  Pasta onde o repositório docker é clonado (padrão: %DIRETORIO%)
echo   -h            Mostra esta ajuda
echo.
echo Também aceita as variáveis DOCKER_REPO_URL, MS_MECANICA_REPO_URL, DIRETORIO e TIMEOUT_SEGUNDOS.
exit /b 0

:info
echo.
echo ==^> %~1
exit /b 0

:erro
echo.
>&2 echo ERRO: %MSG%
call :pausar
exit /b 1

:pausar
if "%DUPLO_CLIQUE%"=="1" (
    echo.
    pause
)
exit /b 0

:comando
set "COLUNA=%~1                                    "
echo   %COLUNA:~0,36% %~2
exit /b 0

:clonar_ou_atualizar
set "C_URL=%~1"
set "C_BRANCH=%~2"
set "C_DESTINO=%~3"
if exist "%C_DESTINO%\.git" (
    echo Atualizando %C_DESTINO% ^(branch %C_BRANCH%^)
    git -C "%C_DESTINO%" config core.longpaths true || exit /b 1
    git -C "%C_DESTINO%" fetch origin "%C_BRANCH%" || exit /b 1
    git -C "%C_DESTINO%" checkout "%C_BRANCH%" || exit /b 1
    git -C "%C_DESTINO%" pull --ff-only origin "%C_BRANCH%" || exit /b 1
    exit /b 0
)
if exist "%C_DESTINO%" (
    set "MSG=%C_DESTINO% já existe e não é um repositório git."
    exit /b 1
)
echo Clonando %C_URL% (branch %C_BRANCH%) em %C_DESTINO%
git clone -c core.longpaths=true --branch "%C_BRANCH%" "%C_URL%" "%C_DESTINO%" || exit /b 1
exit /b 0
