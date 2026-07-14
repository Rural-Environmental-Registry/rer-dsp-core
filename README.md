# RER DSP — Core

**Projeto**: Rural Environmental Registry — Data Sharing Platform  
**Componente**: Core (Lógica de Domínio)  
**Tipo**: Digital Public Good (DPG)  
**Licença**: GPL-3.0

---

## 📋 Visão Geral

Biblioteca core da plataforma DSP do RER. Contém a lógica de domínio, modelos de dados, regras de negócio e utilitários compartilhados entre os demais componentes.

## 🏗️ Arquitetura

Este componente faz parte do ecossistema RER DSP:

```
rer-dsp-frontend (UI)
    ↓
rer-dsp-backend (API REST)
    ↓
rer-dsp-core  ← ESTE REPO
    ↓
rer-dsp-job-data-migration (ETL)
rer-dsp-job-geo-file-generation (geoespacial)
```

## 🚀 Setup

```bash
# Clonar
git clone https://github.com/Rural-Environmental-Registry/rer-dsp-core.git
cd rer-dsp-core

# Instruções de build serão adicionadas conforme desenvolvimento
```

## 📖 Documentação

- [RER — Visão Geral](https://github.com/Rural-Environmental-Registry)
- [SDD (System Design Document)](https://github.com/Rural-Environmental-Registry/core)

## 📜 Licença

Este projeto é licenciado sob a [GNU General Public License v3.0](LICENSE).
