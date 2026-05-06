# Lua Builder

Ferramenta de build para recursos FiveM que consolida múltiplos diretórios (client, server, shared, files) em um único recurso empacotado e gera um arquivo ZIP pronto para release.

---

## Sumário

- [Visão Geral](#visão-geral)
- [Como Funciona](#como-funciona)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Uso](#uso)
- [Manifest Suportado](#manifest-suportado)

---

## Visão Geral

O **Lua Builder** automatiza o processo de build de recursos FiveM escritos em múltiplos arquivos Lua distribuídos em diretórios `client/`, `server/` e `shared/`. A partir de um `fxmanifest.lua`, ele descobre os arquivos declarados, os copia para um diretório `dist/` organizado e compacta tudo em um `.zip` para distribuição.

É usado como dependência pelo template **[builder](../builder)** via GitHub Actions para gerar releases automáticos.

---

## Como Funciona

1. Lê o `fxmanifest.lua` do recurso-alvo
2. Extrai todas as declarações de scripts (`server_scripts`, `client_scripts`, `shared_scripts`, `files`)
3. Resolve os caminhos dos arquivos declarados recursivamente
4. Copia os arquivos para `dist/`, organizando em `server/`, `client/`, `shared/` e `files/`
5. Compacta o conteúdo de `dist/` em um arquivo `.zip`
6. Remove arquivos temporários

---

## Estrutura do Projeto

```
lua_builder/
└── src/
    ├── builder.lua         # Motor principal de build (parse do manifest + cópia de arquivos)
    ├── build.sh            # Executor: roda builder.lua e compacta o resultado em ZIP
    └── pre-build.sh        # Pré-build: prepara o diretório de staging (src/resource/)
```

---

## Uso

### Standalone (via Bash)

```bash
# Na raiz do recurso que deseja buildar
bash /caminho/para/lua_builder/src/pre-build.sh
bash /caminho/para/lua_builder/src/build.sh
```

### Via GitHub Actions (modo recomendado)

O lua_builder é automaticamente clonado e executado pelo workflow do template **[builder](../builder)**. Veja a documentação do template para configurar builds automáticos no seu repositório.

---

## Manifest Suportado

O builder reconhece as seguintes chaves do `fxmanifest.lua`:

| Chave manifest | Diretório destino |
|---|---|
| `server_scripts` / `server_script` | `dist/server/` |
| `client_scripts` / `client_script` | `dist/client/` |
| `shared_scripts` / `shared_script` | `dist/shared/` |
| `files` | `dist/files/` |

Padrões glob e múltiplos arquivos são suportados. Arquivos e diretórios ignorados são configurados via `ignored_directories.txt` no repositório que usa o builder.
