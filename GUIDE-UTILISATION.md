# Guide d utilisation de la boucle

Une seule commande construit le projet du dossier vide jusqu au DMG publie sur GitHub.

```bash
./scripts/boucle.sh
```

Elle prend la prochaine fonctionnalite, ouvre une branche, lance Claude Code dessus, verifie le resultat, commite, pousse, fusionne, puis passe a la suivante. Elle recommence 67 fois, puis publie.

---

## Sommaire

1. [Comment elle fonctionne](#1-comment-elle-fonctionne)
2. [Installation](#2-installation)
3. [Lancer la boucle](#3-lancer-la-boucle)
4. [Les options](#4-les-options)
5. [Les reglages](#5-les-reglages)
6. [Les garde fous](#6-les-garde-fous)
7. [Suivre et reprendre](#7-suivre-et-reprendre)
8. [Quand ca coince](#8-quand-ca-coince)
9. [Les competences](#9-les-competences)
10. [Modifier le backlog](#10-modifier-le-backlog)
11. [Publier une version](#11-publier-une-version)
12. [Reference des fichiers](#12-reference-des-fichiers)

---

## 1. Comment elle fonctionne

### Le principe

**Claude Code implemente, mais c est `verifications.sh` qui decide.**

C est le point le plus important de toute l architecture. Un agent qui evalue son propre travail finit toujours par se declarer satisfait. La boucle ne lui fait donc pas confiance : elle relance elle meme les neuf controles, et c est leur code de sortie qui tranche. Le verdict ecrit par le modele sert a expliquer, jamais a decider.

### Le cycle

```
   selectionner la prochaine fonctionnalite realisable
        |
        v
   ouvrir la branche  feat/F0XX-slug
        |
        v
   +--> claude -p  ... phase d implementation
   |    |
   |    v
   |  verifications.sh   <-- la boucle decide ici
   |    |
   |    +-- echec --> claude -p --resume  ... phase de reparation
   |    |             (jusqu a MAX_TENTATIVES)
   |    v
   |  succes
   |    |
   |    v
   |  commit, push, pull request, integration continue, fusion
   |    |
   +----+ fonctionnalite suivante
        |
        v
   backlog vide --> DMG signe --> etiquette --> release GitHub
```

### Deux phases par fonctionnalite

La phase d implementation part d une session neuve. Si les verifications echouent, la phase de reparation **reprend la meme session** avec `--resume`, et recoit en entree la sortie exacte de `verifications.sh`. Le contexte est preserve, le modele sait ce qu il a deja essaye.

### Ce que la boucle appelle

Elle lance Claude Code en mode non interactif :

```bash
claude -p --output-format stream-json --verbose \
  --permission-mode acceptEdits --max-turns 40
```

Le prompt arrive par l entree standard. Le flux `stream-json` sert a deux choses : l affichage en direct de ce que fait l agent, et l extraction du cout et de l identifiant de session sur l evenement final.

La boucle n utilise **pas** `--bare`. C est deliberé : elle a besoin que `CLAUDE.md`, les cinq competences, les hooks et le sous agent de revue soient charges. C est toute l infrastructure qui rend le resultat previsible.

---

## 2. Installation

### Prerequis

| Outil | Installation | Role |
|---|---|---|
| Xcode 16 | App Store | compilation |
| Claude Code | `npm install -g @anthropic-ai/claude-code` | l agent |
| GitHub CLI | `brew install gh` | pull requests et releases |
| jq | `brew install jq` | lecture du backlog |
| python3 | fourni avec macOS | assemblage des prompts |
| coreutils | `brew install coreutils` | `gtimeout`, borne les phases |
| SwiftLint | `brew install swiftlint` | controle 3 |
| SwiftFormat | `brew install swiftformat` | controle 3 |

Sans coreutils, la boucle tourne quand meme mais une phase bloquee peut durer indefiniment. Installe le.

### Mise en place

```bash
mkdir -p docs
cp CAHIER-DES-CHARGES-DEV.md docs/
cp CAHIER-DES-CHARGES-DESIGN.md docs/
cp -r wireframes .

chmod +x scripts/*.sh
./scripts/init-projet.sh
gh auth login
```

### Renommer le projet

Le nom de code est `Yum`. Remplace le avant de lancer :

```bash
grep -rl "Yum" . --exclude-dir=.git | xargs sed -i '' 's/Yum/TonNom/g'
grep -rl "yum" . --exclude-dir=.git | xargs sed -i '' 's/yum/tonnom/g'
```

---

## 3. Lancer la boucle

### Sans le design, tout de suite

Tu peux demarrer avant que `DESIGN-SPEC.md` existe. La boucle **saute** les fonctionnalites d interface au lieu de s arreter dessus, et traite tout ce qui n en depend pas : le socle, la base de donnees, le tri naturel, la lecture d archives, la chaine d images, les formats etendus, les sources reseau. Cela represente une vingtaine de fonctionnalites.

```bash
./scripts/boucle.sh
```

Quand le design arrive, pose `DESIGN-SPEC.md` a la racine et relance la meme commande. Les fonctionnalites sautees redeviennent realisables.

### Un essai a blanc d abord

```bash
./scripts/boucle.sh --simulation
```

Montre quelle fonctionnalite serait prise et quelle commande serait lancee, sans rien modifier.

### Une seule fonctionnalite, pour voir

```bash
./scripts/boucle.sh --une
```

Recommande pour le premier lancement. Regarde le resultat, puis lance la boucle complete.

---

## 4. Les options

```bash
./scripts/boucle.sh                        du debut a la fin, publication comprise
./scripts/boucle.sh --une                  une fonctionnalite puis sortie
./scripts/boucle.sh --jusqu-a F030         s arrete apres F030
./scripts/boucle.sh --etape 5              ne traite que l etape 5
./scripts/boucle.sh --simulation           montre sans agir
./scripts/boucle.sh --sans-publication     ne publie pas a la fin
./scripts/boucle.sh --reprendre F041       remet une fonctionnalite bloquee a faire
```

---

## 5. Les reglages

Par variables d environnement.

| Variable | Defaut | Effet |
|---|---|---|
| `MAX_TENTATIVES` | 3 | essais par fonctionnalite avant blocage |
| `MAX_ECHECS_CONSECUTIFS` | 3 | disjoncteur global |
| `BUDGET_USD` | 150 | plafond de depense cumulee |
| `DELAI_PAR_PHASE` | 3600 | secondes par appel a Claude Code |
| `MAX_TOURS` | 40 | tours agentiques par appel |
| `MODELE` | vide | `sonnet` ou `opus` |
| `PERMISSIONS` | `acceptEdits` | ou `dontAsk`, ou `bypassPermissions` |
| `SANS_COULEUR` | 0 | mettre a 1 pour un journal propre |

Exemple pour une nuit surveillee :

```bash
BUDGET_USD=80 MAX_TENTATIVES=2 DELAI_PAR_PHASE=1800 \
  ./scripts/boucle.sh --jusqu-a F026 2>&1 | tee nuit.log
```

Sur `PERMISSIONS` : `acceptEdits` laisse Claude ecrire des fichiers et lance les commandes deja autorisees dans `.claude/settings.json`, qui couvre git, gh, swift, xcodebuild et les scripts de la boucle. C est le bon reglage. `bypassPermissions` desactive tout controle : ne l utilise que dans un conteneur jetable.

---

## 6. Les garde fous

Sept mecanismes empechent la boucle de partir en vrille. Chacun a ete teste.

| Garde fou | Declenchement | Effet |
|---|---|---|
| **Verification independante** | apres chaque phase | seul `verifications.sh` decide, jamais le modele |
| **Tentatives bornees** | `MAX_TENTATIVES` epuise | fonctionnalite marquee bloquee, on passe a la suivante |
| **Detection d absence de progres** | deux tentatives sans le moindre changement | arret immediat, evite de tourner a vide |
| **Blocage declare** | le modele ecrit `statut: bloque` | on ne s acharne pas, on note le besoin exprime |
| **Disjoncteur** | `MAX_ECHECS_CONSECUTIFS` d affilee | arret complet, quelque chose de systemique ne va pas |
| **Plafond de depense** | cumul superieur a `BUDGET_USD` | arret immediat |
| **Delai par phase** | `DELAI_PAR_PHASE` depasse | la phase est tuee, tentative suivante |

Trois protections viennent en plus, heritees de l infrastructure :

- Le hook `hook-tiret-cadratin.sh` renvoie le message a Claude Code des qu il ecrit un tiret cadratin.
- Le hook `hook-protege-main.sh` refuse tout commit direct sur `main`.
- L integration continue rejoue les verifications avant la fusion.

### Ce qui a ete verifie

Les chemins suivants ont ete executes sur un banc d essai avec des doublures de `claude`, `gh` et `verifications.sh` :

- parcours nominal sur plusieurs fonctionnalites enchainees
- echec de verification suivi d une reparation reussie a la deuxieme puis a la troisieme tentative
- epuisement des tentatives, blocage, passage a la fonctionnalite suivante
- disjoncteur apres trois echecs consecutifs
- blocage declare par le modele
- deux tentatives sans aucune progression
- depassement du plafond de depense
- absence de `DESIGN-SPEC.md`, les fonctionnalites d interface sautees et les autres traitees

---

## 7. Suivre et reprendre

### Pendant

La boucle affiche en direct le texte de l agent et chaque outil qu il appelle. Tout est aussi ecrit dans `loop/journal/boucle-DATE.log`, et le flux brut de chaque phase dans `loop/journal/flux-*.jsonl`.

```bash
./scripts/boucle-statut.sh              depuis un autre terminal
tail -f loop/journal/boucle-*.log
```

### Interrompre

`Ctrl+C` arrete apres la phase en cours. L etat vit dans `loop/backlog.json`, qui est versionne. Rien ne se perd.

### Reprendre

```bash
./scripts/boucle.sh
```

Une fonctionnalite restee en cours d une session precedente est automatiquement remise a faire.

---

## 8. Quand ca coince

### Le disjoncteur s est declenche

Trois echecs de suite signalent un probleme systemique, pas trois fonctionnalites difficiles. Regarde les trois raisons dans le rapport final. Les causes habituelles : Xcode mal configure, `DESIGN-SPEC.md` incomplet, dependance manquante, integration continue cassee.

### Une fonctionnalite reste bloquee

```bash
./scripts/boucle-statut.sh --detail
```

Traite la a la main dans une session interactive, avec du contexte supplementaire :

```bash
claude
> Reprends F041. Elle est bloquee, voici pourquoi : ...
```

Puis remets la dans le circuit :

```bash
./scripts/boucle.sh --reprendre F041
```

### La boucle tourne mais rien n avance

Le garde fou d absence de progres s en charge apres deux tentatives. Si ce n est pas le cas, regarde `loop/journal/flux-*.jsonl` pour voir ce que l agent a reellement fait.

### La depense grimpe vite

Baisse `MAX_TOURS`, et utilise `MODELE=sonnet` pour les etapes mecaniques. Garde le modele par defaut pour les etapes 6 et 9, qui sont les plus difficiles.

---

## 9. Les competences

Cinq competences dans `.claude/skills/`. Claude Code les charge selon le contexte, et la fiche de mission indique lesquelles pour chaque fonctionnalite.

| Competence | Contenu |
|---|---|
| `boucle-projet` | le cycle, les regles non negociables, la gestion du blocage |
| `design-systeme` | la these du produit, les jetons, les trois etats par ecran, l accessibilite |
| `developpement-swift` | frontieres entre paquets, concurrence, memoire, les sept erreurs qui tuent le projet |
| `tests-qualite` | ce qui doit etre couvert, les budgets, ce qui est interdit pour faire passer les controles |
| `release-dmg` | l ordre des dix operations de signature, le diagnostic Gatekeeper |

Un sous agent `revue-avant-fusion` relit un diff en contexte isole et rend un verdict tranche. La boucle ne l invoque pas d elle meme : demande le explicitement sur une fonctionnalite sensible.

---

## 10. Modifier le backlog

`loop/backlog.json` est fait pour etre edite.

```json
{
  "id": "F068",
  "slug": "lecture-partagee",
  "etape": 11,
  "titre": "Lecture partagee entre deux appareils",
  "description": "Synchroniser la page affichee sur le reseau local.",
  "skills": ["developpement-swift", "tests-qualite"],
  "criteres": [
    "La page se synchronise en moins de 200 ms sur le reseau local",
    "La deconnexion d un appareil n interrompt pas l autre"
  ],
  "depend_de": ["F058"],
  "statut": "a_faire"
}
```

- L identifiant est unique, le `slug` sert au nom de branche.
- `depend_de` conditionne la selection : une dependance non terminee fait sauter la fonctionnalite.
- Chaque critere doit etre verifiable. `l interface est agreable` ne sert a rien.
- Pas de tiret cadratin, l integration continue le detecte.

---

## 11. Publier une version

La boucle publie toute seule quand le backlog est vide **et** qu aucune fonctionnalite n est bloquee. Sinon elle s arrete et te le dit.

### Preparation, une seule fois

```bash
xcrun notarytool store-credentials "yum-notarisation" \
  --apple-id "adresse@exemple.fr" \
  --team-id "TEAMID" \
  --password "mot-de-passe-application"
```

### Secrets GitHub

| Secret | Contenu |
|---|---|
| `CERTIFICAT_P12_BASE64` | `base64 -i certificat.p12` |
| `MOT_DE_PASSE_P12` | mot de passe du fichier p12 |
| `MOT_DE_PASSE_TROUSSEAU` | une chaine aleatoire |
| `IDENTIFIANT_APPLE` | adresse du compte developpeur |
| `EQUIPE_APPLE` | identifiant d equipe |
| `MOT_DE_PASSE_APPLICATION` | mot de passe pour application |
| `IDENTITE_SIGNATURE` | `Developer ID Application: Nom (TEAMID)` |

### A la main si besoin

```bash
./scripts/build-dmg.sh
git tag -a v1.0.0 -m "Version 1.0.0"
git push origin v1.0.0
```

La release est creee **en brouillon**. Avant de la rendre publique : telecharger le DMG depuis la page de la release, le tester sur une machine qui n a jamais vu le projet, verifier la somme SHA 256, relire les notes de version.

---

## 12. Reference des fichiers

```
CLAUDE.md                          contexte permanent, lu a chaque session
GUIDE-UTILISATION.md               ce fichier
DESIGN-SPEC.md                     produit par Claude Design

docs/                              les deux cahiers des charges
wireframes/                        neuf maquettes filaires annotees

loop/
  backlog.json                     67 fonctionnalites, source de verite
  etat-boucle.json                 depense cumulee, hors suivi git
  verdict.json                     verdict de la phase en cours, hors suivi git
  prompts/implementer.md           gabarit de la phase d implementation
  prompts/reparer.md               gabarit de la phase de reparation
  journal/                         journaux et flux bruts

scripts/
  boucle.sh                        L ORCHESTRATEUR
  lib-boucle.sh                    fonctions partagees
  construire-prompt.py             assemblage des prompts
  init-projet.sh                   installation, une seule fois
  boucle-demarrer.sh               ouvre une fonctionnalite
  boucle-terminer.sh               ferme une fonctionnalite
  boucle-statut.sh                 avancement et pilotage
  verifications.sh                 les neuf controles bloquants
  build-dmg.sh                     signature, notarisation, DMG
  hook-tiret-cadratin.sh           garde fou d ecriture
  hook-protege-main.sh             garde fou de branche

.claude/
  settings.json                    permissions et hooks
  skills/                          les cinq competences
  agents/revue-avant-fusion.md     relecteur en contexte isole

.github/workflows/
  ci.yml                           verifications sur chaque pull request
  release.yml                      DMG et release sur etiquette de version
```

---

## Trois choses a savoir

**Lance `--une` en premier.** Regarde ce que produit une iteration complete avant de lacher la boucle sur 67 fonctionnalites. Dix minutes de verification maintenant valent mieux qu une nuit de travail a refaire.

**F009 est le vrai test du produit.** Si a la fin de cette fonctionnalite lire un tome local n est pas agreable, les 58 suivantes ne sauveront rien. Les criteres peuvent etre coches et le resultat mediocre : c est le seul moment ou ton jugement compte plus que celui de la boucle.

**Le backlog est une hypothese.** Il est deduit du cahier des charges, lui meme deduit de captures d ecran incompletes. Tu decouvriras que des fonctionnalites manquent et que certaines sont mal decoupees. Modifie le fichier, c est fait pour.
