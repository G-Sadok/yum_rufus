---
name: release-dmg
description: "Empaquete l application en DMG et publie une version sur GitHub. A utiliser quand il faut signer, notariser, construire un DMG, creer une etiquette de version, rediger des notes de version, ou publier une release. A utiliser aussi pour diagnostiquer un probleme de signature, de notarisation ou de Gatekeeper."
---

# Empaquetage et publication

## Ordre des operations

L ordre compte. Une erreur d ordre produit un DMG qui semble correct et qui declenche Gatekeeper chez l utilisateur.

```
1. archiver
2. exporter avec le profil developer-id
3. verifier la signature de l application
4. notariser l application
5. agrafer l application
6. construire le DMG
7. signer le DMG
8. notariser le DMG
9. agrafer le DMG
10. verifier avec spctl
```

L application se notarise **avant** d entrer dans le DMG, et le DMG se notarise ensuite a son tour. Les deux, pas l un ou l autre.

Tout est deja dans `./scripts/build-dmg.sh`. Ne reecris pas la chaine a la main.

## Preparation du poste

Une seule fois, pour creer le profil de notarisation dans le trousseau :

```bash
xcrun notarytool store-credentials "yum-notarisation" \
  --apple-id "adresse@exemple.fr" \
  --team-id "TEAMID" \
  --password "mot-de-passe-application"
```

Le mot de passe est un mot de passe pour application, genere sur appleid.apple.com. Ce n est pas le mot de passe du compte Apple.

Variables attendues par le script :

```bash
export IDENTITE_SIGNATURE="Developer ID Application: Nom (TEAMID)"
export EQUIPE_APPLE="TEAMID"
export PROFIL_NOTARISATION="yum-notarisation"
```

## Construction locale

```bash
./scripts/build-dmg.sh                      version deduite du projet
./scripts/build-dmg.sh 1.2.0                version imposee
SANS_NOTARISATION=1 ./scripts/build-dmg.sh  iteration rapide
```

Fais toujours au moins une construction locale complete, notarisation comprise, avant de pousser une etiquette. La chaine distante coute du temps et la notarisation Apple peut prendre plusieurs minutes.

## Publication

```bash
git tag -a v1.0.0 -m "Version 1.0.0"
git push origin v1.0.0
```

L etiquette declenche `.github/workflows/release.yml`, qui construit, signe, notarise, empaquette, calcule la somme SHA 256, redige les notes de version et cree une release **en brouillon**.

La release reste en brouillon jusqu a validation manuelle. C est voulu : tu relis les notes et tu testes le DMG telecharge sur une machine tierce avant de publier.

## Versionnage

Versionnage semantique. `MARKETING_VERSION` dans le projet doit correspondre exactement a l etiquette, sans le `v`.

- Correctif : `1.0.1`
- Fonctionnalite : `1.1.0`
- Rupture ou refonte majeure : `2.0.0`

Les notes de version se generent depuis les messages de commit. C est pour cela que le format `feat(F0XX): titre` compte.

## Diagnostic

**Gatekeeper refuse le DMG.**

```bash
spctl --assess --type open --context context:primary-signature -vvv chemin.dmg
codesign --verify --deep --strict --verbose=4 chemin.app
xcrun stapler validate chemin.dmg
```

Cause la plus frequente : le ticket de notarisation n a pas ete agrafe, ou l application a ete modifiee apres signature.

**La notarisation echoue.**

```bash
xcrun notarytool log IDENTIFIANT --keychain-profile "yum-notarisation"
```

Causes frequentes : horodatage manquant, `hardened runtime` non active, binaire imbrique non signe, droit d acces reclame sans justification.

**Le DMG s ouvre mais l application refuse de demarrer.**

Verifie que le lien vers `/Applications` existe dans le DMG. Une application lancee depuis le volume monte se comporte parfois differemment.

## Avant de publier, la liste

- [ ] Le DMG a ete telecharge depuis la release et teste sur une machine qui n a jamais vu le projet
- [ ] `spctl` accepte le DMG
- [ ] La somme SHA 256 publiee correspond au fichier telecharge
- [ ] Les notes de version sont lisibles par un humain, pas une liste brute de commits
- [ ] Le numero de version dans l application correspond a l etiquette
- [ ] Aucun tiret cadratin dans les notes de version
