#!/bin/bash
# Definir opções para tratamento de erros
set -e
set -o pipefail

scriptDir=../..
resourceDir=../../lua_builder/src/resource

# Função para copiar arquivos de um diretório para outro
copy_files() {
    local source_dir="$1"
    local dest_dir="$2"
    mkdir -p "$dest_dir"
    cp -r "$source_dir"/* "$dest_dir"
}

# Criar diretório de recursos, se ainda não existir
mkdir -p "$resourceDir"
# Copiar fxmanifest.lua
cp "$scriptDir/fxmanifest.lua" "$resourceDir"

ignored_directories="lua_builder"

# Ler o arquivo de lista de diretórios ignorados diretamente do diretório $scriptDir
if [ -f "$scriptDir/ignored_directories.txt" ]; then
    while IFS= read -r dir; do
        # Adicionar diretório à lista de ignorados
        ignored_directories+=("$dir")
        echo "$dir"
    done < "$scriptDir/ignored_directories.txt"
fi

# Iterar sobre os diretórios em $scriptDir
for dir in "$scriptDir"/*/; do
    if [ -d "$dir" ]; then
        # Obtém o nome do diretório (última parte do caminho)
        dirname=$(basename "$dir")

        # Verifica se o diretório deve ser ignorado
        if [[ " ${ignored_directories[*]} " == *" $dirname "* ]]; then
            echo "ignorando $dirname"
            continue  # Pula a iteração se o diretório deve ser ignorado
        fi

        # Verifica se o diretório não está vazio
        if ls "$dir"/* >/dev/null 2>&1; then
            # Copia os arquivos do diretório para $resourceDir
            copy_files "$dir" "$resourceDir/$dirname"
        fi
    fi
done