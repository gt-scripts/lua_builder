#!/bin/bash

# Definir opções para tratamento de erros
set -e
set -o pipefail

# Executa o script lua builder.lua
lua builder.lua

# Move o diretório "dist" para o destino especificado pelo primeiro argumento
mv dist "$1"

# Compacta o diretório especificado pelo primeiro argumento em um arquivo ZIP com o mesmo nome
zip -r "$1.zip" "$1"