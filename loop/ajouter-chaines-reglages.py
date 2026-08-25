#!/usr/bin/env python3
"""Ajoute les chaines de l ecran Reglages au catalogue de l application.

Les libelles viennent des sections 5.5, 6.4, 6.5, 6.7 et 6.8 de DESIGN-SPEC.md,
au caractere pres. Le catalogue est un JSON trie par cle, ecrit par Xcode. Le
script conserve cette forme pour que le prochain enregistrement dans Xcode ne
produise aucun diff parasite.
"""

import json
import pathlib

RACINE = pathlib.Path(__file__).resolve().parent.parent
CATALOGUE = RACINE / "App/Yum/Ressources/Localizable.xcstrings"

SECTION = "DESIGN-SPEC.md, section 5.5, en tete de section"
LIGNE = "DESIGN-SPEC.md, section 5.5, libelle de ligne"
VALEUR = "DESIGN-SPEC.md, tableau 6.7, valeur de reglage"
DESCRIPTION = "DESIGN-SPEC.md, tableau 6.8, description sous une carte"

SECTIONS = {
    "abonnement": "Abonnement",
    "confidentialite": "Confidentialite",
    "general": "General",
    "bibliothequeTri": "Bibliotheque",
    "traduction": "Traduction",
    "lecteur": "Lecteur",
    "prereglagesDeLecture": "Prereglages de lecture",
    "comportementDuLecteur": "Comportement du lecteur",
    "bibliothequeComportement": "Bibliotheque",
    "pontNavigateur": "Pont navigateur",
    "suivis": "Suivis",
    "telechargements": "Telechargements",
    "sauvegardeEtRestauration": "Sauvegarde et restauration",
    "iCloud": "iCloud",
    "stockage": "Stockage",
    "assistance": "Assistance",
    "aPropos": "A propos",
}

LIGNES = {
    "abonnement.passerAPremium": "Passer a Premium",
    "abonnement.restaurerLesAchats": "Restaurer les achats",
    "confidentialite.incognito": "Incognito",
    "confidentialite.verrouillageDeLApp": "Verrouillage de l app",
    "general.langue": "Langue",
    "general.apparence": "Apparence",
    "general.theme": "Theme",
    "general.notificationsDeNouveauxChapitres": "Notifications de nouveaux chapitres",
    "bibliothequeTri.trierPar": "Trier par",
    "bibliothequeTri.ordre": "Ordre",
    "bibliothequeTri.grouperParCategorie": "Grouper par categorie",
    "traduction.traduireLesBulles": "Traduire les bulles",
    "traduction.langueCible": "Langue cible",
    "traduction.policeDeRemplacement": "Police de remplacement",
    "lecteur.sensDeLecture": "Sens de lecture",
    "lecteur.miseEnPage": "Mise en page",
    "lecteur.fondDuLecteur": "Fond du lecteur",
    "lecteur.rognerLesBords": "Rogner les bords",
    "prereglagesDeLecture.prereglages": "Prereglages",
    "prereglagesDeLecture.appliquerAuChapitreSuivant": "Appliquer au chapitre suivant",
    "comportementDuLecteur.tourneDePageAnimee": "Tourne de page animee",
    "comportementDuLecteur.garderLEcranAllume": "Garder l ecran allume",
    "comportementDuLecteur.tournerAvecLesTouchesDeVolume": "Tourner avec les touches de volume",
    "comportementDuLecteur.pagesGardeesEnMemoire": "Pages gardees en memoire",
    "comportementDuLecteur.luminositeDuLecteur": "Luminosite du lecteur",
    "bibliothequeComportement.marquerLuALaDernierePage": "Marquer lu a la derniere page",
    "bibliothequeComportement.supprimerApresLecture": "Supprimer apres lecture",
    "bibliothequeComportement.mettreAJourAuLancement": "Mettre a jour au lancement",
    "pontNavigateur.extensionSafari": "Extension Safari",
    "pontNavigateur.ouvrirLesLiensDansLApplication": "Ouvrir les liens dans Yum",
    "suivis.services": "Services de suivi",
    "suivis.envoyerLaProgression": "Envoyer la progression",
    "suivis.confirmerAvantDEnvoyer": "Confirmer avant d envoyer",
    "telechargements.qualite": "Qualite",
    "telechargements.enWiFiSeulement": "En Wi-Fi seulement",
    "telechargements.chapitresALAvance": "Chapitres a l avance",
    "telechargements.emplacement": "Emplacement",
    "sauvegardeEtRestauration.sauvegarderMaintenant": "Sauvegarder maintenant",
    "sauvegardeEtRestauration.sauvegardeAutomatique": "Sauvegarde automatique",
    "sauvegardeEtRestauration.restaurerDepuisUnFichier": "Restaurer depuis un fichier",
    "iCloud.synchroniserLaProgression": "Synchroniser la progression",
    "iCloud.synchroniserLaBibliotheque": "Synchroniser la bibliotheque",
    "iCloud.dernierEnvoi": "Dernier envoi",
    "stockage.detail": "Detail du stockage",
    "stockage.viderLeCacheDImages": "Vider le cache d images",
    "stockage.supprimerTousLesTelechargements": "Supprimer tous les telechargements",
    "assistance.aide": "Aide",
    "assistance.signalerUnBug": "Signaler un bug",
    "assistance.statistiquesDeLecture": "Statistiques de lecture",
    "aPropos.version": "Version",
    "aPropos.nouveautes": "Nouveautes",
    "aPropos.mentionsLegales": "Mentions legales",
}

VALEURS = {
    "systeme": "Systeme",
    "francais": "Francais",
    "english": "English",
    "espanol": "Espanol",
    "deutsch": "Deutsch",
    "japonais": "Japonais",
    "clair": "Clair",
    "sombre": "Sombre",
    "midnight": "Midnight",
    "obsidian": "Obsidian",
    "slate": "Slate",
    "paper": "Paper",
    "droiteGauche": "Droite a gauche",
    "gaucheDroite": "Gauche a droite",
    "pageUnique": "Page unique",
    "doublePage": "Double page",
    "continuVertical": "Continu vertical",
    "noirOled": "Noir OLED",
    "grisSombre": "Gris sombre",
    "blanc": "Blanc",
    "sepia": "Sepia",
    "jamais": "Jamais",
    "apres1Jour": "Apres 1 jour",
    "apres7Jours": "Apres 7 jours",
    "immediatement": "Immediatement",
    "desactivee": "Desactivee",
    "chaqueJour": "Chaque jour",
    "chaqueSemaine": "Chaque semaine",
    "chaqueMois": "Chaque mois",
    "originale": "Originale",
    "elevee": "Elevee",
    "moyenne": "Moyenne",
    "aAZ": "A a Z",
    "derniereLecture": "Derniere lecture",
    "derniereMiseAJour": "Derniere mise a jour",
    "dateAjout": "Date d ajout",
    "nonLu": "Non lu",
    "croissant": "Croissant",
    "decroissant": "Decroissant",
}

DESCRIPTIONS = {
    "abonnement": (
        "Debloquez la traduction, la colorisation, les suivis, la sauvegarde, "
        "le mode incognito, les serveurs Komga, Kavita, Jellyfin et OPDS, "
        "la synchronisation iCloud et bien plus."
    ),
    "confidentialite": (
        "Navigation privee : l activite de lecture n est pas enregistree dans l historique."
    ),
    "bibliothequeTri": "Ce tri s applique a la grille et au mode liste compacte.",
    "lecteur": "La double page se replie automatiquement en portrait.",
    "bibliothequeComportement": (
        "Deuxieme carte Bibliotheque, comportement, distincte de la carte de tri plus haut."
    ),
    "pontNavigateur": (
        "Le pont laisse une page de catalogue ouverte dans le navigateur "
        "envoyer une serie vers Yum."
    ),
    "stockage": "Les chapitres supprimes restent lisibles depuis leur source.",
    "aPropos": (
        "Yum ne heberge aucun contenu. L application lit les fichiers et les serveurs "
        "que vous lui indiquez. Vous restez responsable de la legalite de vos sources."
    ),
}

AUTRES = {
    "reglages.note": (
        "DESIGN-SPEC.md, section 5.5, note en caption sous la carte A propos. "
        "La section 9 du cahier de developpement y attend la provenance et la licence "
        "du jeu de donnees du detecteur de cases. Aucun modele n est livre a ce stade, "
        "la note dit donc ce qui est vrai aujourd hui",
        "Aucun jeu de donnees tiers n est embarque a ce jour. La provenance et la licence "
        "du modele de detection de cases apparaitront ici des sa livraison.",
    ),
    "reglages.aucunPrereglage": (
        "DESIGN-SPEC.md, section 5.5, etat vide de la ligne Prereglages",
        "Aucun prereglage",
    ),
    "reglages.nombreDePrereglages": (
        "DESIGN-SPEC.md, section 5.5, valeur de la ligne Prereglages",
        "%lld prereglages",
    ),
    "reglages.aucunServiceConnecte": (
        "DESIGN-SPEC.md, section 5.5, etat vide de la ligne Services de suivi",
        "Aucun service connecte",
    ),
    "reglages.nombreDeServices": (
        "DESIGN-SPEC.md, section 5.5, valeur de la ligne Services de suivi",
        "%lld services connectes",
    ),
    "reglages.versionEtCompilation": (
        "DESIGN-SPEC.md, section 5.5, valeur de la ligne Version. "
        "Section 9 du cahier de developpement, numero et numero de compilation",
        "%1$@ (%2$@)",
    ),
    "reglages.couronne": (
        "DESIGN-SPEC.md, section 7, etiquette de la couronne d une fonction verrouillee",
        "Fonction reservee a l abonnement",
    ),
    "reglages.augmenter": (
        "DESIGN-SPEC.md, section 4.1, chevron du haut d un compteur, libelle ecrit selon la section 6",
        "Augmenter",
    ),
    "reglages.diminuer": (
        "DESIGN-SPEC.md, section 4.1, chevron du bas d un compteur, libelle ecrit selon la section 6",
        "Diminuer",
    ),
    "erreur.reglages.titre": (
        "DESIGN-SPEC.md, tableau 6.4, banniere de l ecran Reglages. Le nombre est la valeur reelle",
        "iCloud n a pas synchronise depuis %lld jours",
    ),
    "erreur.reglages.phrase": (
        "DESIGN-SPEC.md, tableau 6.4, banniere de l ecran Reglages",
        "Le compte iCloud de cet appareil n autorise plus Yum. Ouvrez les reglages du systeme, "
        "puis reactivez Yum dans la liste des applications iCloud.",
    ),
    "erreur.reglages.ouvrirLesReglagesDuSysteme": (
        "DESIGN-SPEC.md, tableau 6.5, second bouton de la banniere de l ecran Reglages",
        "Ouvrir les reglages du systeme",
    ),
}


def nouvelles() -> dict[str, tuple[str, str]]:
    entrees: dict[str, tuple[str, str]] = {}

    for cle, valeur in SECTIONS.items():
        entrees[f"reglages.section.{cle}"] = (SECTION, valeur)

    for cle, valeur in LIGNES.items():
        entrees[f"reglages.ligne.{cle}"] = (LIGNE, valeur)

    for cle, valeur in VALEURS.items():
        entrees[f"reglages.valeur.{cle}"] = (VALEUR, valeur)

    for cle, valeur in DESCRIPTIONS.items():
        entrees[f"reglages.description.{cle}"] = (DESCRIPTION, valeur)

    entrees.update(AUTRES)

    return entrees


def main() -> None:
    catalogue = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    langue = catalogue["sourceLanguage"]

    for cle, (commentaire, valeur) in nouvelles().items():
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
