#!/bin/sh
# Script de configuração simples do Git para toda a equipe do Morph.
# Cada programador roda apenas 1 vez:
#   sh scripts/setup-git.sh

set -e

echo "🔧 Configurando repositório Morph..."

# 1. Ativa as travas de segurança (hooks) do repositório
git config --local core.hooksPath .githooks

# 2. Usa merge padrão no git pull (mais simples e seguro que rebase para iniciantes)
git config --local pull.rebase false

# 3. O Git memoriza conflitos já resolvidos para não perguntar de novo
git config --local rerere.enabled true

# 4. Limpa referências de branches antigas que já foram apagadas no GitHub
git config --local fetch.prune true

# 5. 'git push' envia direto para a branch atual, sem precisar digitar o nome dela
git config --local push.default current
git config --local push.autoSetupRemote true

echo "✅ Tudo pronto! Configuração aplicada com sucesso."
