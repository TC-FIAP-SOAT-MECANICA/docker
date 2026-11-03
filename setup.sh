#!/usr/bin/env bash
set -euo pipefail

DOCKER_REPO_URL="${DOCKER_REPO_URL:-https://github.com/TC-FIAP-SOAT-MECANICA/docker.git}"
DOCKER_BRANCH="${DOCKER_BRANCH:-main}"
MS_MECANICA_REPO_URL="${MS_MECANICA_REPO_URL:-https://github.com/TC-FIAP-SOAT-MECANICA/ms-mecanica.git}"
DIRETORIO="${DIRETORIO:-oficina-mecanica}"
TIMEOUT_SEGUNDOS="${TIMEOUT_SEGUNDOS:-300}"
SERVICO_API="ms-mecanica"

uso() {
    cat <<EOF
Uso: ./setup.sh [-m branch] [-d diretorio]

Baixa o repositório docker e o ms-mecanica e sobe tudo no Docker (API e PostgreSQL).
Rodado de dentro de um clone do repositório docker, usa esse clone.

  -m branch     Branch do ms-mecanica (padrão: MS_MECANICA_BRANCH do .env ou main)
  -d diretorio  Pasta onde o repositório docker é clonado (padrão: ${DIRETORIO})
  -h            Mostra esta ajuda

Também aceita as variáveis DOCKER_REPO_URL, DOCKER_BRANCH, MS_MECANICA_REPO_URL, DIRETORIO e TIMEOUT_SEGUNDOS.
EOF
}

info() { printf '\n==> %s\n' "$1"; }
erro() { printf '\nERRO: %s\n' "$1" >&2; exit 1; }

clonar_ou_atualizar() {
    local url="$1" branch="$2" destino="$3"
    if [ -d "$destino/.git" ]; then
        echo "Atualizando $destino (branch $branch)"
        git -C "$destino" config core.longpaths true
        git -C "$destino" fetch origin "$branch"
        git -C "$destino" checkout "$branch"
        git -C "$destino" pull --ff-only origin "$branch"
    elif [ -e "$destino" ]; then
        erro "$destino já existe e não é um repositório git."
    else
        echo "Clonando $url (branch $branch) em $destino"
        git clone -c core.longpaths=true --branch "$branch" "$url" "$destino"
    fi
}

BRANCH_ARGUMENTO=""
while getopts "m:d:h" opcao; do
    case "$opcao" in
        m) BRANCH_ARGUMENTO="$OPTARG" ;;
        d) DIRETORIO="$OPTARG" ;;
        h) uso; exit 0 ;;
        *) uso; exit 1 ;;
    esac
done

info "Verificando pré-requisitos"
command -v git >/dev/null 2>&1 || erro "git não encontrado. Instale em https://git-scm.com/downloads"
command -v docker >/dev/null 2>&1 || erro "docker não encontrado. Instale o Docker Desktop: https://www.docker.com/products/docker-desktop"
if docker compose version >/dev/null 2>&1; then
    COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE=(docker-compose)
else
    erro "Docker Compose não encontrado. Atualize o Docker Desktop ou instale o plugin compose."
fi
docker info >/dev/null 2>&1 || erro "o Docker não está rodando. Abra o Docker Desktop e execute o script de novo."
echo "git, docker e ${COMPOSE[*]} disponíveis"

PASTA_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$PASTA_SCRIPT/docker-compose.yml" ] && [ -d "$PASTA_SCRIPT/.git" ]; then
    info "Usando o repositório docker em $PASTA_SCRIPT"
    cd "$PASTA_SCRIPT"
else
    info "Baixando o repositório docker"
    clonar_ou_atualizar "$DOCKER_REPO_URL" "$DOCKER_BRANCH" "$DIRETORIO"
    cd "$DIRETORIO"
fi

if [ ! -f .env ] && [ -f .env.example ]; then
    cp .env.example .env
    echo "Criado .env a partir do .env.example"
fi
BRANCH_ENV="$(grep -E '^MS_MECANICA_BRANCH=' .env 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '\r' || true)"
MS_MECANICA_BRANCH="${BRANCH_ARGUMENTO:-${MS_MECANICA_BRANCH:-${BRANCH_ENV:-main}}}"
API_PORT="$(grep -E '^API_PORT=' .env 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '\r' || true)"
API_PORT="${API_PORT:-8080}"
POSTGRES_PORT="$(grep -E '^POSTGRES_PORT=' .env 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '\r' || true)"
POSTGRES_PORT="${POSTGRES_PORT:-5436}"

info "Baixando o ms-mecanica"
mkdir -p services
clonar_ou_atualizar "$MS_MECANICA_REPO_URL" "$MS_MECANICA_BRANCH" services/ms-mecanica

info "Compilando e subindo os containers (a primeira vez leva alguns minutos)"
"${COMPOSE[@]}" up -d --build --remove-orphans

info "Aguardando a API ficar saudável (até ${TIMEOUT_SEGUNDOS}s)"
API_ID="$("${COMPOSE[@]}" ps -q "$SERVICO_API")"
[ -n "$API_ID" ] || erro "container da API não foi criado. Veja: ${COMPOSE[*]} logs $SERVICO_API"
inicio=$SECONDS
while true; do
    estado="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$API_ID")"
    case "$estado" in
        healthy) break ;;
        unhealthy|exited|dead) erro "a API ficou '$estado'. Veja o log com: ${COMPOSE[*]} logs $SERVICO_API" ;;
    esac
    if [ $((SECONDS - inicio)) -ge "$TIMEOUT_SEGUNDOS" ]; then
        erro "a API não ficou saudável em ${TIMEOUT_SEGUNDOS}s (estado: $estado). Veja: ${COMPOSE[*]} logs $SERVICO_API"
    fi
    printf '.'
    sleep 5
done
echo " pronto"

"${COMPOSE[@]}" ps

cat <<EOF

Tudo no ar! (ms-mecanica na branch $MS_MECANICA_BRANCH)

  API         http://localhost:${API_PORT}/api/v1
              login: POST /auth/login com o ADMIN do .env (padrão admin@oficina.com / admin12345)
  Contrato    http://localhost:${API_PORT}/api/v1/oficina-mecanica-contract.yaml
  Métricas    http://localhost:${API_PORT}/api/v1/actuator/prometheus
  PostgreSQL  localhost:${POSTGRES_PORT} (usuário e senha do .env, padrão oficina / oficina)

Collection do Postman: $(pwd)/services/ms-mecanica/postman/oficina-mecanica.postman_collection.json

Comandos úteis (dentro de $(pwd)):
EOF
printf '  %-36s %s\n' \
    "${COMPOSE[*]} logs -f $SERVICO_API" "log da API" \
    "./setup.sh" "atualiza o código e reconstrói" \
    "${COMPOSE[*]} down" "para tudo (mantém os dados)" \
    "${COMPOSE[*]} down -v" "para tudo e apaga os dados"
