import Core
import Foundation
import Testing
@testable import DesignSystem

/// Compare les jetons de la feuille de configuration au tableau de la section
/// 4.9 de DESIGN-SPEC.md, lu sur le disque.
///
/// Le document fait foi. Une valeur qui change dans le tableau et pas dans le
/// code fait virer cette suite au rouge, ce qui est exactement le but : la
/// feuille d installation d une extension est une feuille de configuration, et
/// une seconde largeur inventee pour elle passerait sinon inapercue.
struct FeuilleDeConfigurationTests {
    /// Le tableau 4.9, reconnu par une propriete qui n appartient qu a lui.
    private func tableau() throws -> [String: String] {
        let trouve = try LectureDeTableaux.tableauDeProprietes(contenantLaPropriete: "Bouton de test")
        let lu = try #require(trouve)

        return LectureDeTableaux.valeursParPropriete(lu)
    }

    @Test("La feuille a les dimensions du tableau 4.9")
    func dimensions() throws {
        let valeurs = try tableau()

        #expect(LectureDeTableaux.premierNombre(valeurs["Largeur"]) == Jetons.Feuille.largeur)
        #expect(
            LectureDeTableaux.premierNombre(valeurs["Hauteur, cas de reference"])
                == Jetons.Feuille.hauteurDeReference
        )
        #expect(LectureDeTableaux.premierNombre(valeurs["Rayon"]) == Jetons.Feuille.rayon)
        #expect(
            LectureDeTableaux.premierNombre(valeurs["Elevation"])
                == Double(Jetons.Feuille.elevation.rawValue)
        )
    }

    @Test("Le champ et son etiquette suivent le tableau 4.9")
    func champ() throws {
        let valeurs = try tableau()
        let mesuresDuChamp = LectureDeTableaux.nombres(dans: valeurs["Champ"])

        #expect(mesuresDuChamp == [
            Jetons.Feuille.largeurDeChamp,
            Jetons.Feuille.hauteurDeChamp,
            Jetons.Feuille.rayonDeChamp,
        ])
        #expect(
            LectureDeTableaux.nombres(dans: valeurs["Etiquette de champ"]).last
                == Jetons.Feuille.ecartApresLEtiquette
        )
        #expect(
            LectureDeTableaux.premierNombre(valeurs["Ecart entre deux champs"])
                == Jetons.Feuille.ecartEntreChamps
        )
    }

    @Test("Les boutons suivent le tableau 4.9")
    func boutons() throws {
        let valeurs = try tableau()

        #expect(
            LectureDeTableaux.premierNombre(valeurs["Bouton de test"])
                == Jetons.Feuille.largeurDuBoutonDeTest
        )

        let pied = LectureDeTableaux.nombres(dans: valeurs["Boutons de pied"])

        #expect(pied == [
            Jetons.Feuille.largeurDeBouton,
            Jetons.Feuille.hauteurDeBouton,
            Jetons.Feuille.rayonDeBouton,
        ])
        #expect(
            LectureDeTableaux.premierNombre(valeurs["Retour de test"])
                == Jetons.Feuille.pastilleDeRetour
        )
    }

    /// La liste des domaines n emprunte que l echelle d espacements de la
    /// section 1.7. Une valeur hors echelle y serait une valeur inventee, le
    /// document ne chiffrant pas cette liste.
    @Test("La liste des domaines reste dans l echelle des espacements")
    func echelleDesEspacements() {
        let empruntes = [
            Jetons.InstallationDExtension.ecartEntreDomaines,
            Jetons.InstallationDExtension.ecartApresLeGlyphe,
            Jetons.InstallationDExtension.ecartEntreBlocs,
        ]

        #expect(empruntes.allSatisfy { Jetons.Espace.echelle.contains($0) })
    }
}

/// Couvre ce que la feuille d installation presente, sans la dessiner.
///
/// Le troisieme critere de la section 4.3 porte sur ce que l utilisateur voit :
/// la liste des domaines, entiere. Ces tests verifient que le contenu remis a
/// la vue porte bien cette liste entiere, et les libelles qui l accompagnent.
struct ContenuDInstallationDExtensionTests {
    private static let libelles = LibellesDInstallationDExtension(
        versionEtLangue: "%@, %@",
        etiquetteDesDomaines: "Domaines",
        phraseDesDomaines: "Phrase",
        mentionDesSousDomaines: "Sous domaines",
        mentionDeResponsabilite: "Responsabilite",
        confirmationDeLecture: "J ai lu la liste",
        etiquetteDUnDomaine: "Domaine %@",
        annuler: "Annuler",
        installer: "Installer"
    )

    @Test("Le sous titre assemble la version et la langue")
    func sousTitre() throws {
        let avertissement = try avertissementDeTest()
        let assemble = TexteDInstallationDExtension.versionEtLangue(
            de: avertissement,
            libelles: Self.libelles
        )

        #expect(assemble == "v1.4, fr")
    }

    @Test("Chaque domaine porte une etiquette d accessibilite qui le nomme")
    func etiquetteDAccessibilite() throws {
        let avertissement = try avertissementDeTest()
        let premier = try #require(avertissement.domaines.first)

        #expect(
            TexteDInstallationDExtension.etiquette(de: premier, libelles: Self.libelles)
                == "Domaine images.exemple.net"
        )
    }

    /// La liste remise a la vue est la liste complete. Une liste tronquee
    /// serait une liste que l utilisateur peut ne pas avoir lue, et la
    /// confirmation ne vaudrait plus rien.
    @Test("Le contenu porte la liste complete des domaines")
    func listeComplete() throws {
        let avertissement = try avertissementDeTest()
        let contenu = ContenuDInstallationDExtension(
            avertissement: avertissement,
            afficheLaResponsabilite: true,
            libelles: Self.libelles,
            annuler: ActionDEtat(libelle: "Annuler") {},
            installer: ActionDEtat(libelle: "Installer") {}
        )

        #expect(contenu.avertissement.domainesAffiches == ["*.images.exemple.net", "api.exemple.net"])
        #expect(contenu.avertissement.couvreDesSousDomaines)
        #expect(contenu.afficheLaResponsabilite)
    }

    /// Un avertissement construit depuis un manifeste minimal.
    private func avertissementDeTest() throws -> AvertissementDInstallation {
        let manifeste = try ManifesteDExtension.lire(Data(
            """
            {
              "identifiant": "exemple.catalogue",
              "nom": "Catalogue Exemple",
              "version": "1.4",
              "langue": "fr",
              "capacites": ["telechargement"],
              "domaines": ["api.exemple.net", "*.images.exemple.net"],
              "regles": {
                "adresseDeBase": "https://api.exemple.net",
                "chapitres": {
                  "requete": { "chemin": "/c/{identifiantSerie}", "format": "json" },
                  "elements": { "json": "$.items[*]" },
                  "champs": { "identifiant": { "json": "$.id" } }
                },
                "pages": {
                  "requete": { "chemin": "/p/{identifiantChapitre}", "format": "json" },
                  "elements": { "json": "$.items[*]" },
                  "champs": { "emplacement": { "json": "$.url" } }
                }
              }
            }
            """.utf8
        ))

        return AvertissementDInstallation(manifeste: manifeste)
    }
}
