#!/bin/sh
# Script opcional para juntar sua branch atual na 'develop' de forma simples e segura.
# Uso: estando na sua branch (ex: func/tela-tv), rode:
#   sh scripts/enviar-develop.sh

set -e

branch_atual=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

if [ -z "$branch_atual" ] || [ "$branch_atual" = "main" ] || [ "$branch_atual" = "develop" ]; then
  echo "❌ Você precisa estar em uma branch de trabalho (func/..., correcao/... ou ajuste/...)."
  echo "   Branch atual: '$branch_atual'"
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "❌ Você tem alterações ainda não commitadas."
  echo "👉 Antes de rodar este script, salve seu trabalho com:"
  echo "   git add . && git commit -m \"sua mensagem\""
  exit 1
fi

echo "1️⃣  Enviando sua branch '$branch_atual' para o GitHub..."
git push

echo "2️⃣  Atualizando a branch 'develop'..."
git checkout develop
git pull origin develop

echo "3️⃣  Juntando '$branch_atual' dentro da 'develop'..."
if ! git merge --no-ff "$branch_atual" -m "Merge: $branch_atual -> develop"; then
  echo ""
  echo "⚠️  Deu um conflito ao juntar '$branch_atual' na 'develop'."
  echo "👉 Abra os arquivos marcados no Xcode, escolha o código certo, depois rode:"
  echo "   git add . && git commit && git push origin develop"
  echo "   (Ou peça ajuda ao líder da equipe / cancele com: git merge --abort)"
  exit 1
fi

echo "4️⃣  Subindo a 'develop' atualizada para o GitHub..."
git push origin develop

echo "✅ Pronto! Suas alterações de '$branch_atual' já estão na 'develop'."
echo "👉 Voltando para a sua branch '$branch_atual'..."
git checkout "$branch_atual"
