#!/bin/zsh
# Publica JenBar en GitHub: crea el repo (si no existe), sube el código y la release con el DMG.
# Requiere `gh` con la sesión iniciada (gh auth login). Uso: ./publicar.sh
set -e
cd "$(dirname "$0")"
VERSION=$(grep '^VERSION=' build.sh | cut -d= -f2)
REPO=$(grep '^let repoGitHub' Sources/App.swift | cut -d'"' -f2)
./build.sh
gh repo view "$REPO" >/dev/null 2>&1 || gh repo create "$REPO" --public \
  --description "Cuánto te queda en Claude y ChatGPT, en tu barra de menú de macOS." --source . --remote origin
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$REPO.git"
git push -u origin HEAD:main
NOTAS=$(awk "/^## $VERSION/{f=1;next}/^## /{f=0}f" CHANGELOG.md)
gh release create "v$VERSION" "build/JenBar-$VERSION.dmg" --title "JenBar $VERSION" --notes "$NOTAS"
echo "Publicado: https://github.com/$REPO/releases/tag/v$VERSION"
