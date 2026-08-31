# Jeu de test de la section 12

Le corpus qui sert a mesurer les sept budgets de performance : 5000 series,
200000 chapitres, et deux chapitres poses en CBZ avec de vraies pages.

## Ce que le depot suit

| Fichier | Role |
|---|---|
| `manifeste.json` | les nombres et la graine du corpus, source de verite |
| `genere/` | le corpus materialise, ignore par git |

Le corpus n est pas suivi en binaire. La base pese une quarantaine de mega
octets, elle changerait a chaque regeneration, et elle se reconstruit a
l identique depuis la graine du manifeste. Ce que le depot suit est donc la
definition du corpus, pas sa materialisation.

Ce choix ne tient que si le generateur est reellement deterministe. Trois tests
de `Packages/Performance/Tests` s en assurent, sur un corpus reduit qui emprunte
le meme chemin de code : la repartition tombe au chapitre pres, deux generations
depuis la meme graine rendent le meme corpus, et deux ecritures du meme chapitre
rendent le meme fichier octet pour octet.

## Le materialiser

```bash
./scripts/generer-jeu-de-test.sh
```

Les nombres viennent du manifeste et de nulle part ailleurs. Aucun argument de
ligne de commande ne les remplace, sans quoi le corpus finirait genere a mille
series sur une machine pressee et les budgets seraient mesures sur autre chose
que ce que le cahier demande.

## Mesurer les budgets

```bash
./scripts/budgets-performance.sh
```

Le script genere le corpus s il manque, puis mesure les sept budgets, chacun
dans son propre processus. Il sort en erreur des qu un seul budget deborde, et
c est ce que l integration continue execute.
