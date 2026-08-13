# rer-dsp-core

> Este repositório é um dos módulos do **DSP (Data Sharing Platform)**, parte do ecossistema RER.
> A documentação completa do projeto está em **[rer-dsp-docs](https://github.com/Rural-Environmental-Registry/rer-dsp-docs)**.
> As informações abaixo tratam apenas deste módulo, não do projeto DSP como um todo.

## Qual parte do DSP este módulo é

```mermaid
flowchart LR
    Backend[rer-dsp-backend]
    Frontend[rer-dsp-frontend]
    Job[rer-dsp-job-data-migration]
    Docs[(rer-dsp-docs)]
    Core((rer-dsp-core))

    Core --> Backend
    Core --> Frontend
    Core --> Job
    Core -.doc.-> Docs
```

## Objetivo

Orquestra, via Docker Compose, os bancos de dados (PostgreSQL/PostGIS), o GeoServer e a
configuração do adotante para toda a stack DSP.

## Responsabilidades

- Subir e configurar os bancos de dados (`dsp-db`, `dsp-job-migration-db`)
- Subir o GeoServer de exibição (WMS)
- Guiar a configuração do adotante (hierarquia, telas, KPIs, camadas do mapa)
- Orquestrar os demais módulos via Docker Compose

## Tecnologias

Docker Compose, PostgreSQL/PostGIS, GeoServer, Bash, Python.

## Pré-requisitos

| Ferramenta | Versão | Uso |
|------------|--------|-----|
| Git | 2.x+ | Clonar repositórios irmãos (automático ou manual), se ainda não existirem |
| Docker | 24+ com Compose v2 | Subir bancos, GeoServer e módulos |
| Python | 3 | Wizard `./config.sh` |

## Como executar

Clone apenas o core e siga os scripts. Os demais repositórios podem ser clonados
automaticamente quando ausentes (`./config.sh`, `./setup.sh` e `./start.sh` exibem
a estrutura de pastas antes de confirmar o clone). O `.env` é criado automaticamente
a partir de `.env.example` na primeira execução.

```bash
git clone https://github.com/Rural-Environmental-Registry/rer-dsp-core.git
cd rer-dsp-core
./config.sh
./setup.sh
./start.sh
```

Estrutura esperada após o setup (layout padrão):

```text
DSP/
├── rer-dsp-core/
├── rer-dsp-backend/
├── rer-dsp-frontend/
└── rer-dsp-job-data-migration/
```

## Licença

[GNU General Public License v3.0](LICENSE)
