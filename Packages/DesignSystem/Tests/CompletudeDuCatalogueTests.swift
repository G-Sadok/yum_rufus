import Core
import Foundation
import Testing

//
// Couvre les trois premiers criteres de F064 : les quatre langues sont
// completes, un test echoue des qu une cle manque dans une langue, et aucune
// chaine visible n echappe au catalogue.
//
// La regle est volontairement symetrique. Une cle sans traduction fait echouer
// le test, et une langue presente dans le catalogue mais absente de
// `LangueDeLInterface` le fait echouer aussi. Sans le second sens, une langue
// a moitie traduite pourrait entrer dans le fichier sans que rien ne le dise,
// et l application tomberait en clair sur la langue source a l ecran.
//

struct CompletudeDuCatalogueTests {
    // MARK: Completude

    @Test("La langue source du catalogue est celle que le modele declare")
    func langueSource() throws {
        #expect(try CatalogueDeChaines.langueSource() == LangueDeLInterface.source.codeBCP47)
    }

    @Test("Chaque cle du catalogue porte une valeur dans les quatre langues livrees")
    func aucuneCleManquante() throws {
        let catalogue = try CatalogueDeChaines.chargerToutesLesLangues()
        let attendues = Set(LangueDeLInterface.allCases.map(\.codeBCP47))

        #expect(catalogue.isEmpty == false)

        for (cle, traductions) in catalogue {
            let presentes = Set(traductions.keys)
            let manquantes = attendues.subtracting(presentes).sorted()

            #expect(
                manquantes.isEmpty,
                "La cle \(cle) n est pas traduite en \(manquantes.joined(separator: ", "))"
            )
        }
    }

    @Test("Le catalogue ne porte aucune langue absente du modele")
    func aucuneLangueInconnue() throws {
        let catalogue = try CatalogueDeChaines.chargerToutesLesLangues()
        let attendues = Set(LangueDeLInterface.allCases.map(\.codeBCP47))

        for (cle, traductions) in catalogue {
            let inconnues = Set(traductions.keys).subtracting(attendues).sorted()

            #expect(
                inconnues.isEmpty,
                "La cle \(cle) porte la langue non declaree \(inconnues.joined(separator: ", "))"
            )
        }
    }

    @Test("Aucune traduction n est vide ni laissee a relire")
    func traductionsAbouties() throws {
        let catalogue = try CatalogueDeChaines.chargerToutesLesLangues()

        for (cle, traductions) in catalogue {
            for (langue, unite) in traductions {
                #expect(
                    unite.value.isEmpty == false,
                    "La cle \(cle) porte une valeur vide en \(langue)"
                )
                #expect(
                    unite.state == "translated",
                    "La cle \(cle) est marquee \(unite.state) en \(langue)"
                )
            }
        }
    }

    // MARK: Fidelite des motifs de format

    @Test("Chaque traduction porte exactement les memes valeurs a substituer que la source")
    func motifsDeFormatIdentiques() throws {
        let catalogue = try CatalogueDeChaines.chargerToutesLesLangues()
        let source = LangueDeLInterface.source.codeBCP47

        for (cle, traductions) in catalogue {
            guard let reference = traductions[source] else { continue }

            let attendus = Specificateur.formesTriees(de: reference.value)

            for (langue, unite) in traductions where langue != source {
                #expect(
                    Specificateur.formesTriees(de: unite.value) == attendus,
                    "La cle \(cle) ne substitue pas les memes valeurs en \(langue)"
                )
            }
        }
    }

    @Test("Une chaine qui porte plusieurs valeurs les numerote, dans toutes les langues")
    func plusieursValeursSontNumerotees() throws {
        let catalogue = try CatalogueDeChaines.chargerToutesLesLangues()

        for (cle, traductions) in catalogue {
            for (langue, unite) in traductions {
                let specificateurs = Specificateur.tous(dans: unite.value)

                guard specificateurs.count > 1 else { continue }

                let positions = specificateurs.compactMap(\.position).sorted()

                // Sans numero, l ordre des arguments suit l ordre du texte. Une
                // langue qui place le complement avant le nombre echangerait
                // alors silencieusement les deux valeurs a l affichage.
                #expect(
                    positions == Array(1...specificateurs.count),
                    "La cle \(cle) porte plusieurs valeurs non numerotees en \(langue)"
                )
            }
        }
    }
}

/// Un motif de substitution lu dans une chaine de format.
struct Specificateur: Hashable {
    /// Forme du motif sans son numero, par exemple `lld`, `@` ou `.1f`.
    let forme: String

    /// Numero de l argument, nul quand le motif n en porte pas.
    let position: Int?

    /// Formes de tous les motifs d une chaine, triees.
    ///
    /// Le tri retire l ordre du texte, qui change legitimement d une langue a
    /// l autre des lors que les motifs sont numerotes.
    static func formesTriees(de texte: String) -> [String] {
        tous(dans: texte).map(\.forme).sorted()
    }

    /// Motifs d une chaine, dans l ordre du texte.
    static func tous(dans texte: String) -> [Specificateur] {
        let caracteres = Array(texte)
        var trouves: [Specificateur] = []
        var index = 0

        while index < caracteres.count {
            guard caracteres[index] == "%" else {
                index += 1
                continue
            }

            var curseur = index + 1

            guard curseur < caracteres.count else { break }

            // Un pourcent double ne substitue rien, il en ecrit un.
            if caracteres[curseur] == "%" {
                index = curseur + 1
                continue
            }

            var position: Int?
            var chiffres = ""
            var apres = curseur

            while apres < caracteres.count, caracteres[apres].isNumber {
                chiffres.append(caracteres[apres])
                apres += 1
            }

            if chiffres.isEmpty == false, apres < caracteres.count, caracteres[apres] == "$" {
                position = Int(chiffres)
                curseur = apres + 1
            }

            var forme = ""

            while curseur < caracteres.count, drapeaux.contains(caracteres[curseur]) {
                forme.append(caracteres[curseur])
                curseur += 1
            }

            while curseur < caracteres.count, longueurs.contains(caracteres[curseur]) {
                forme.append(caracteres[curseur])
                curseur += 1
            }

            guard curseur < caracteres.count else { break }

            forme.append(caracteres[curseur])
            trouves.append(Specificateur(forme: forme, position: position))
            index = curseur + 1
        }

        return trouves
    }

    private static let drapeaux = Set("0123456789.+- #'")
    private static let longueurs = Set("hlLqjzt")
}
