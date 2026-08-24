# Demarrage

Tout est deja en place. Le dossier est pret a etre lance.

## En quatre commandes

```bash
chmod +x scripts/*.sh scripts/*.py
./scripts/init-projet.sh
./scripts/boucle.sh --simulation
./scripts/boucle.sh --une
```

La premiere ligne est indispensable : une archive ne conserve pas toujours le droit d execution.

`init-projet.sh` verifie les outils, initialise git, cree le depot GitHub et protege la branche principale. Il te demande le nom du depot.

`--simulation` montre ce qui serait fait sans rien modifier. `--une` traite une seule fonctionnalite, pour que tu voies le resultat avant de lacher la boucle sur les 67.

Ensuite, la boucle complete :

```bash
./scripts/boucle.sh
```

## A faire avant, une seule fois

**Renommer le projet.** Le nom de code est `Yum`. Reprendre le nom ou l identite visuelle d une application existante est le seul vrai risque juridique de ce projet.

```bash
grep -rl "Yum" . --exclude-dir=.git | xargs sed -i '' 's/Yum/TonNom/g'
grep -rl "yum" . --exclude-dir=.git | xargs sed -i '' 's/yum/tonnom/g'
```

**Installer les outils manquants.**

```bash
brew install gh jq coreutils swiftlint swiftformat
npm install -g @anthropic-ai/claude-code
gh auth login
```

Sans `coreutils`, une phase bloquee tourne sans limite de temps.

## Le design

`DESIGN-SPEC.md` n est pas encore la. C est normal, il vient de Claude Design.

Tu peux lancer la boucle sans lui : elle saute les fonctionnalites d interface et traite les vingt et quelques autres, le socle, la base de donnees, le tri naturel, la lecture d archives, la chaine d images, les sources reseau.

Quand Claude Design te rend le fichier, pose le a la racine et relance la meme commande. Les fonctionnalites sautees redeviennent realisables.

Pour produire ce fichier, donne a Claude Design `docs/CAHIER-DES-CHARGES-DESIGN.md` et le dossier `wireframes/`.

## Ce que contient le dossier

| Dossier | Role |
|---|---|
| `scripts/` | la boucle et ses outils, `boucle.sh` est l orchestrateur |
| `loop/` | le backlog des 67 fonctionnalites et les gabarits de prompt |
| `.claude/` | les cinq competences, le sous agent de revue, les permissions et les hooks |
| `docs/` | les deux cahiers des charges |
| `wireframes/` | neuf maquettes filaires annotees |
| `.github/` | integration continue et publication du DMG |

`GUIDE-UTILISATION.md` explique le fonctionnement en detail. `CLAUDE.md` est lu par Claude Code a chaque session.

## Deux fichiers absents volontairement

`scripts/generer-jeu-de-test.sh` sera cree par la fonctionnalite F065. La chaine d integration continue le saute proprement en attendant.

`Ressources/fond-dmg.png` est l image de fond de la fenetre du DMG. Purement cosmetique, a demander a Claude Design.

## Le seul conseil qui compte

Lance `--une` en premier et lis vraiment ce que ca produit. Dix minutes de verification maintenant valent mieux qu une nuit de travail a refaire.
