#!/usr/bin/env python3
"""Ajoute les chaines de la fiche de serie au catalogue de l application.

Le catalogue est un JSON trie par cle, ecrit par Xcode. Le script conserve
cette forme pour que le prochain enregistrement dans Xcode ne produise aucun
diff parasite.
"""

import json
import pathlib

CATALOGUE = pathlib.Path("App/Yum/Ressources/Localizable.xcstrings")

NOUVELLES = {
    "chapitre.etiquetteDeTelechargement": (
        "DESIGN-SPEC.md, section 4.5 et section 7, etiquette de l icone de telechargement",
        "Telecharge",
    ),
    "chapitre.lu": ("DESIGN-SPEC.md, tableau 4.5, sous ligne d un chapitre lu", "Lu"),
    "chapitre.nombreDePages": (
        "DESIGN-SPEC.md, tableau 4.5, sous ligne d un chapitre non lu",
        "%lld pages",
    ),
    "chapitre.numerote": ("DESIGN-SPEC.md, tableau 4.5, titre de la ligne", "Chapitre %@"),
    "chapitre.pageSurTotal": (
        "DESIGN-SPEC.md, tableau 4.5, sous ligne d un chapitre en cours",
        "page %1$lld sur %2$lld",
    ),
    "chapitre.telecharge": (
        "DESIGN-SPEC.md, tableau 4.5, suffixe d un chapitre telecharge",
        "telecharge",
    ),
    "erreur.ficheDeSerie.phrase": (
        "DESIGN-SPEC.md, tableau 6.4. Le nom et le nombre sont les valeurs reelles",
        "%1$@ a repondu, puis a coupe la connexion. "
        "Les %2$lld chapitres telecharges restent lisibles.",
    ),
    "erreur.ficheDeSerie.titre": ("DESIGN-SPEC.md, tableau 6.4", "La liste des chapitres n a pas pu etre lue"),
    "erreur.reessayer": ("DESIGN-SPEC.md, tableau 6.5, bouton secondaire de tout etat d erreur", "Reessayer"),
    "etatVide.ficheDeSerie.action": ("DESIGN-SPEC.md, tableau 6.3", "Suivre la serie"),
    "etatVide.ficheDeSerie.phrase": (
        "DESIGN-SPEC.md, tableau 6.3",
        "La source connait cette serie mais n expose encore aucun chapitre. "
        "Suivez la serie pour etre prevenu.",
    ),
    "etatVide.ficheDeSerie.titre": ("DESIGN-SPEC.md, tableau 6.3", "Aucun chapitre dans cette serie"),
    "fiche.afficherMoins": (
        "Repli du resume. Libelle absent de la section 6, ecrit selon ses regles",
        "Afficher moins",
    ),
    "fiche.afficherPlus": ("DESIGN-SPEC.md, tableau 6.5", "Afficher plus"),
    "fiche.aucunChapitre": ("DESIGN-SPEC.md, section 5.6, bouton principal desactive", "Aucun chapitre"),
    "fiche.commencerLaLecture": ("DESIGN-SPEC.md, tableau 6.5, aucun chapitre lu", "Commencer la lecture"),
    "fiche.dansMaListe": ("DESIGN-SPEC.md, tableau 6.5, action secondaire", "Dans ma liste"),
    "fiche.options": (
        "Etiquette d accessibilite du bouton d options du wireframe 04",
        "Options de la serie",
    ),
    "fiche.reprendreChapitre": ("DESIGN-SPEC.md, tableau 6.5, lecture en cours", "Reprendre ch. %@"),
    "fiche.retour": ("DESIGN-SPEC.md, tableau 6.1, retour depuis la fiche", "Bibliotheque"),
    "fiche.suivre": ("DESIGN-SPEC.md, tableau 6.5, action secondaire", "Suivre"),
    "fiche.toutEstLu": ("DESIGN-SPEC.md, tableau 6.5, tous les chapitres lus", "Tout est lu"),
    "liste.compteurDeChapitres": ("DESIGN-SPEC.md, section 5.6, en tete de la liste", "%lld chapitres"),
    "liste.filtrer": ("DESIGN-SPEC.md, tableau 6.5, liste de chapitres", "Filtrer"),
    "liste.toutMarquerLu": ("DESIGN-SPEC.md, tableau 6.5, liste de chapitres", "Tout marquer lu"),
    "liste.trier": ("DESIGN-SPEC.md, tableau 6.5, liste de chapitres", "Trier"),
    "selection.compteur": ("DESIGN-SPEC.md, section 4.5, compteur de la barre", "%lld selectionnes"),
    "selection.etendreLaSelection": (
        "Equivalent atteignable du Maj clic de la section 4.5, libelle ecrit selon la section 6",
        "Etendre la selection",
    ),
    "selection.fermer": (
        "Fermeture de la barre de selection, libelle ecrit selon la section 6",
        "Tout deselectionner",
    ),
    "selection.marquerLu": ("DESIGN-SPEC.md, tableau 6.5, selection multiple", "Marquer lu"),
    "selection.selectionner": (
        "Equivalent atteignable du clic maintenu de la section 4.5, libelle ecrit selon la section 6",
        "Selectionner",
    ),
    "selection.supprimer": ("DESIGN-SPEC.md, tableau 6.5, selection multiple, action destructive", "Supprimer"),
    "selection.telecharger": ("DESIGN-SPEC.md, tableau 6.5, selection multiple", "Telecharger"),
}


def main() -> None:
    catalogue = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    langue = catalogue["sourceLanguage"]

    for cle, (commentaire, valeur) in NOUVELLES.items():
        catalogue["strings"][cle] = {
            "comment": commentaire,
            "extractionState": "manual",
            "localizations": {
                langue: {"stringUnit": {"state": "translated", "value": valeur}}
            },
        }

    catalogue["strings"] = dict(sorted(catalogue["strings"].items()))

    texte = json.dumps(catalogue, ensure_ascii=False, indent=2, separators=(",", " : "))
    CATALOGUE.write_text(texte + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
