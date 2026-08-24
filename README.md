# Yum Rufus

Lecteur de manga, manhwa et manhua pour macOS, iPadOS et iOS.
L application n heberge aucun contenu, elle lit ce que vous possedez deja.

Le detail fonctionnel et technique vit dans `docs/CAHIER-DES-CHARGES-DEV.md`,
les conventions de travail dans `CLAUDE.md`.

## Apres un clone, une fois

```bash
bash scripts/installer-hooks-git.sh   # hooks git versionnes
bash scripts/proteger-main.sh         # protection de main cote GitHub
```

Le premier pose le bit d execution sur `githooks/` et branche `core.hooksPath`
dessus. Sans lui, git ignore silencieusement les hooks, la regle de redaction
n est alors appliquee qu au moment des verifications.

Le second demande `gh` authentifie et un acces reseau. Il refuse la suppression
de `main` et la reecriture de son historique, mais laisse le push direct, dont
la boucle de developpement depend puisque le projet n utilise pas de pull
request.

## Organisation

```
Packages/    couche metier, un dossier par module, manifeste unique a la racine
App/Yum/     cible multiplateforme, vues et navigation
docs/        cahiers des charges
loop/        etat de la boucle de developpement
scripts/     boucle, verifications, empaquetage
githooks/    hooks git versionnes
```

## Travailler sur le projet

```bash
./scripts/boucle-statut.sh       ou en est le projet
./scripts/boucle.sh --une        une fonctionnalite
./scripts/verifications.sh       les neuf controles bloquants
swift build --package-path Packages
swift test --package-path Packages
```
