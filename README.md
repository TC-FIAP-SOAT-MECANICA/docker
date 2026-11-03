# docker

Ambiente Docker da Oficina Mecânica: sobe o [ms-mecanica](https://github.com/TC-FIAP-SOAT-MECANICA/ms-mecanica)
(API) e o PostgreSQL com um comando, sempre a partir da branch `main`.

Este repositório só orquestra: o código e o `Dockerfile` de cada serviço ficam no repositório dele. Para rodar só a
API a partir do próprio código, veja o README do
[ms-mecanica](https://github.com/TC-FIAP-SOAT-MECANICA/ms-mecanica#como-executar).

| Serviço | Repositório | Branch |
|---|---|---|
| `ms-mecanica` | [TC-FIAP-SOAT-MECANICA/ms-mecanica](https://github.com/TC-FIAP-SOAT-MECANICA/ms-mecanica) | `main` |
| `postgres` | imagem `postgres:16-alpine` | — |

## Instalação automática

[**⬇ Baixar setup.sh**](https://raw.githubusercontent.com/TC-FIAP-SOAT-MECANICA/docker/main/setup.sh)
([ver o arquivo](setup.sh))

Pré-requisitos: `git` e Docker Desktop em execução. No Windows, rode pelo Git Bash ou WSL.

```bash
curl -fsSL https://raw.githubusercontent.com/TC-FIAP-SOAT-MECANICA/docker/main/setup.sh -o setup.sh
bash setup.sh
```

O script:

1. verifica `git`, Docker e Docker Compose;
2. clona a `main` deste repositório em `oficina-mecanica/` (ou usa o clone atual, se rodado de dentro dele);
3. cria o `.env` a partir do `.env.example`, se ainda não existir;
4. clona ou atualiza a `main` do ms-mecanica em `services/ms-mecanica`;
5. compila a API e sobe os containers;
6. espera a API ficar saudável e mostra os endereços.

| Opção | Para quê |
|---|---|
| `-d <pasta>` | Pasta do clone deste repositório (padrão `oficina-mecanica`) |

Rodar o script de novo atualiza os dois repositórios (`git pull`) e reconstrói a API.

## Já clonou este repositório?

```bash
./setup.sh
```

Ou, com o ms-mecanica já em `services/ms-mecanica` (ou em outra pasta, via `MS_MECANICA_PATH` no `.env`):

```bash
docker compose up -d --build
```

## Endereços

| Serviço | Endereço | Acesso |
|---|---|---|
| API | http://localhost:8080/api/v1 | `POST /auth/login` com `admin@oficina.com` / `admin12345` |
| Contrato OpenAPI | http://localhost:8080/api/v1/oficina-mecanica-contract.yaml | público |
| Saúde | http://localhost:8080/api/v1/actuator/health | público |
| PostgreSQL | `localhost:5436`, banco `oficina` | `oficina` / `oficina` |

As portas são as mesmas do `docker compose` do ms-mecanica: se ele estiver rodando, pare-o antes (ou mude
`API_PORT` e `POSTGRES_PORT` no `.env`).

A collection do Postman fica em `services/ms-mecanica/postman/oficina-mecanica.postman_collection.json`.

## Configuração

Tudo é opcional: sem `.env`, valem os padrões. Copie [.env.example](.env.example) para `.env` para mudar:

| Variável | Padrão | Para quê |
|---|---|---|
| `MS_MECANICA_PATH` | `./services/ms-mecanica` | Pasta com o código do ms-mecanica usada no build |
| `API_PORT` | `8080` | Porta da API na máquina |
| `POSTGRES_PORT` | `5436` | Porta do PostgreSQL na máquina |
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | `oficina` | Banco de dados |
| `ADMIN_EMAIL` / `ADMIN_SENHA` | `admin@oficina.com` / `admin12345` | ADMIN criado na primeira subida |
| `JWT_SECRET`, `CRYPTO_KEY`, `CRYPTO_INDEX_KEY` | chaves de desenvolvimento | Segredos da API. **Defina fora do ambiente local** |

## Comandos úteis

| Quero... | Comando |
|---|---|
| Ver o log da API | `docker compose logs -f ms-mecanica` |
| Atualizar o código e reconstruir | `./setup.sh` |
| Parar (mantém os dados) | `docker compose down` |
| Parar e apagar os dados | `docker compose down -v` |
