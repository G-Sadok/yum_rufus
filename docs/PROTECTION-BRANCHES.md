# Protection des branches

Le depot a deux branches longues.

| Branche | Role |
|---|---|
| `main` | ce qui est publie, recoit le code par pull request uniquement |
| `dev` | integration, cible des pull requests de fonctionnalite |

Chaque fonctionnalite vit sur `feat/<ID>-<slug>` et rejoint `dev` par une pull
request. La boucle ne fusionne qu apres le passage des controles distants.

## Appliquer la protection

La protection de branche est une configuration de GitHub, pas un fichier du
depot. Elle se pose avec un jeton qui porte le droit d administration :

```bash
bash scripts/proteger-branches.sh
```

Le script est idempotent. Il lit le depot courant avec `gh repo view`, ou prend
`proprietaire/depot` en premier argument.

## Ce que le script pose

Sur `main` :

- passage par une pull request obligatoire, zero relecteur exige
- historique lineaire
- aucune poussee forcee, aucune suppression de branche
- conversations resolues avant fusion
- aucun controle distant exige, l integration continue tourne sur `dev` et le
  code arrive sur `main` deja verifie

Sur `dev` :

- le job `Verifications` de `.github/workflows/ci.yml` doit passer
- `strict` reste a `false`, sinon la boucle attendrait une remise a niveau
  manuelle avant chaque fusion
- aucune relecture exigee, la boucle fusionne elle meme
- aucune poussee forcee, aucune suppression de branche

## Pourquoi `enforce_admins` reste a `false`

Le depot n a qu un mainteneur. Mettre `enforce_admins` a `true` rendrait toute
reparation d urgence impossible, y compris la reparation de la protection elle
meme. La regle "jamais de commit direct sur `main`" est deja tenue localement
par `scripts/hook-protege-main.sh`, qui refuse tout `git commit` et tout
`git push` lance depuis `main`, `master` ou `dev` en dehors des scripts de la
boucle.

Le jour ou une deuxieme personne rejoint le projet, passe `enforce_admins` a
`true` et `required_approving_review_count` a `1` dans
`scripts/proteger-branches.sh`, puis relance le script.

## Verifier l etat pose

```bash
gh api repos/<proprietaire>/<depot>/branches/main/protection
gh api repos/<proprietaire>/<depot>/branches/dev/protection
```
