# docker

Ambiente Docker da Oficina Mecânica: sobe o [ms-mecanica](https://github.com/TC-FIAP-SOAT-MECANICA/ms-mecanica)
(API) e o PostgreSQL com um comando.

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
2. clona este repositório em `oficina-mecanica/` (ou usa o clone atual, se rodado de dentro dele);
3. cria o `.env` a partir do `.env.example`, se ainda não existir;
4. clona ou atualiza o ms-mecanica em `services/ms-mecanica`;
5. compila a API e sobe os containers;
6. espera a API ficar saudável e mostra os endereços.

| Opção | Para quê |
|---|---|
| `-m <branch>` | Branch do ms-mecanica (padrão `MS_MECANICA_BRANCH` do `.env`, ou `main`), ex.: `bash setup.sh -m feat/nova-estrutura` |
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

A collection do Postman fica em `services/ms-mecanica/postman/oficina-mecanica.postman_collection.json`.

## Configuração

Tudo é opcional: sem `.env`, valem os padrões. Copie [.env.example](.env.example) para `.env` para mudar:

| Variável | Padrão | Para quê |
|---|---|---|
| `MS_MECANICA_BRANCH` | `main` | Branch do ms-mecanica baixada pelo `setup.sh` |
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
