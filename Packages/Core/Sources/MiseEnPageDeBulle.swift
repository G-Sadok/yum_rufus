//
// MiseEnPageDeBulle
//
// Le placement du texte traduit dans le rectangle de sa bulle, section 8 du
// cahier de developpement.
//
// C est la piece qui tient le critere de la fonctionnalite : le texte traduit
// reste lisible et ne deborde pas de la bulle. Les deux moities du critere se
// contredisent des que la traduction est plus longue que l original, ce qui est
// la regle et non l exception entre le japonais et le francais. Il faut donc
// choisir, et le choix est ecrit ici plutot que laisse au moteur de rendu.
//
// La regle appliquee, dans cet ordre.
//
// 1. Le texte est essaye au plus grand corps du gabarit, puis au corps suivant,
//    jusqu au plus petit. Le premier corps ou tout entre gagne.
// 2. Le plus petit corps est un plancher de lisibilite, jamais franchi. Le
//    document fixe le bas de son echelle typographique a onze points, et un
//    texte plus petit qu une mention legale n est plus une traduction, c est une
//    tache.
// 3. Si rien n entre au plancher, le texte est coupe et la coupe est signalee.
//    Un texte tronque se voit et se corrige, un texte qui deborde masque le
//    dessin autour de la bulle et fait passer la surimpression pour un defaut
//    d affichage.
//
// Le debordement n est donc jamais un cas possible en sortie, et la suite de
// tests le verifie ligne par ligne plutot que de le supposer.
//
// La mesure du texte n est pas faite ici. Elle depend de la police reellement
// posee a l ecran, qui appartient au systeme de design, et un calcul approche
// au caractere se tromperait exactement la ou il ne faut pas, sur les lignes
// presque pleines. `MesureDeTexte` est donc un protocole, la couche vue en
// fournit une implantation exacte, et la suite de tests en fournit une dont elle
// connait le resultat au point pres.
//

/// Ce qui sait mesurer un texte dans la police reellement posee a l ecran.
public protocol MesureDeTexte: Sendable {
    /// Largeur d un fragment sans retour a la ligne, en points.
    func largeur(de fragment: String, corps: Double) -> Double

    /// Hauteur occupee par une ligne, interligne compris, en points.
    func hauteurDeLigne(corps: Double) -> Double
}

/// Bornes typographiques dans lesquelles une bulle traduite se compose.
///
/// Les valeurs viennent du systeme de design, jamais de ce paquet. Le modele
/// sait comment remplir une bulle, il ne sait pas a quelle taille le produit
/// ecrit.
public struct GabaritDeBulle: Sendable, Hashable {
    /// Corps le plus grand essaye.
    public let corpsMaximal: Double

    /// Corps le plus petit accepte, plancher de lisibilite.
    public let corpsMinimal: Double

    /// Ecart entre deux corps essayes.
    public let pas: Double

    /// Marge laissee entre le texte et le bord de la bulle, sur chaque cote.
    public let margeInterne: Double

    /// Marque posee a la fin d un texte coupe.
    public let marqueDeTroncature: String

    public init(
        corpsMaximal: Double,
        corpsMinimal: Double,
        pas: Double,
        margeInterne: Double,
        marqueDeTroncature: String
    ) {
        self.corpsMaximal = max(corpsMaximal, corpsMinimal)
        self.corpsMinimal = corpsMinimal
        self.pas = max(pas, 0.5)
        self.margeInterne = max(margeInterne, 0)
        self.marqueDeTroncature = marqueDeTroncature
    }

    /// Corps essayes, du plus grand au plus petit, plancher compris.
    public var corpsEssayes: [Double] {
        var corps: [Double] = []
        var courant = corpsMaximal

        while courant > corpsMinimal {
            corps.append(courant)
            courant -= pas
        }

        corps.append(corpsMinimal)

        return corps
    }
}

/// Texte d une bulle une fois compose, pret a etre pose a l ecran.
public struct TexteDeBulleMisEnPage: Sendable, Equatable {
    /// Lignes du texte, dans l ordre.
    public let lignes: [String]

    /// Corps retenu, en points.
    public let corps: Double

    /// Hauteur d une ligne au corps retenu, en points.
    public let hauteurDeLigne: Double

    /// Largeur disponible entre les deux marges, en points.
    public let largeurUtile: Double

    /// Hauteur disponible entre les deux marges, en points.
    public let hauteurUtile: Double

    /// Vrai quand le texte n a pas tenu et a du etre coupe.
    public let estTronque: Bool

    /// Vrai quand rien n a pu etre pose, bulle trop petite pour un seul mot.
    public var estVide: Bool {
        lignes.isEmpty
    }

    /// Hauteur occupee par le bloc de texte, en points.
    public var hauteurDuBloc: Double {
        Double(lignes.count) * hauteurDeLigne
    }

    /// Texte compose, lignes jointes par un retour a la ligne.
    public var texte: String {
        lignes.joined(separator: "\n")
    }
}

/// Composition du texte traduit dans le rectangle de sa bulle.
public enum MiseEnPageDeBulle {
    /// Compose un texte dans une bulle, sans jamais deborder.
    ///
    /// - Parameters:
    ///   - texte: texte traduit, dans la langue cible.
    ///   - cadre: rectangle de la bulle, en points a l ecran.
    ///   - gabarit: bornes typographiques venues du systeme de design.
    ///   - mesure: mesure du texte dans la police reellement posee.
    /// - Returns: les lignes a poser, le corps retenu, et le drapeau de coupe.
    public static func composer(
        _ texte: String,
        dans cadre: CadreEnPoints,
        gabarit: GabaritDeBulle,
        mesure: any MesureDeTexte
    ) -> TexteDeBulleMisEnPage {
        let largeurUtile = cadre.largeur - 2 * gabarit.margeInterne
        let hauteurUtile = cadre.hauteur - 2 * gabarit.margeInterne

        guard largeurUtile > 0, hauteurUtile > 0 else {
            return vide(gabarit: gabarit, mesure: mesure, largeur: 0, hauteur: 0)
        }

        for corps in gabarit.corpsEssayes {
            let hauteurDeLigne = mesure.hauteurDeLigne(corps: corps)
            let lignes = decouper(texte, largeur: largeurUtile, corps: corps, mesure: mesure)
            let hauteur = Double(lignes.count) * hauteurDeLigne

            guard lignes.isEmpty == false, hauteur <= hauteurUtile else { continue }

            return TexteDeBulleMisEnPage(
                lignes: lignes,
                corps: corps,
                hauteurDeLigne: hauteurDeLigne,
                largeurUtile: largeurUtile,
                hauteurUtile: hauteurUtile,
                estTronque: false
            )
        }

        return couper(
            texte,
            largeurUtile: largeurUtile,
            hauteurUtile: hauteurUtile,
            gabarit: gabarit,
            mesure: mesure
        )
    }

    /// Texte coupe au plancher de lisibilite, quand rien n entre.
    ///
    /// Les lignes gardees sont celles qui tiennent en hauteur, et la derniere
    /// recoit la marque de coupe. La marque est posee en retirant des
    /// caracteres tant que la ligne depasse, jamais en laissant la ligne
    /// s allonger : c est la seule facon de garantir qu une bulle coupee ne
    /// deborde pas non plus.
    private static func couper(
        _ texte: String,
        largeurUtile: Double,
        hauteurUtile: Double,
        gabarit: GabaritDeBulle,
        mesure: any MesureDeTexte
    ) -> TexteDeBulleMisEnPage {
        let corps = gabarit.corpsMinimal
        let hauteurDeLigne = mesure.hauteurDeLigne(corps: corps)
        let toutes = decouper(texte, largeur: largeurUtile, corps: corps, mesure: mesure)
        let tenables = hauteurDeLigne > 0 ? Int(hauteurUtile / hauteurDeLigne) : 0
        let gardees = Array(toutes.prefix(max(0, tenables)))

        guard gardees.isEmpty == false else {
            return vide(
                gabarit: gabarit,
                mesure: mesure,
                largeur: largeurUtile,
                hauteur: hauteurUtile
            )
        }

        var lignes = gardees

        if gardees.count < toutes.count {
            lignes[lignes.count - 1] = marquer(
                gardees[gardees.count - 1],
                largeur: largeurUtile,
                corps: corps,
                gabarit: gabarit,
                mesure: mesure
            )
        }

        return TexteDeBulleMisEnPage(
            lignes: lignes,
            corps: corps,
            hauteurDeLigne: hauteurDeLigne,
            largeurUtile: largeurUtile,
            hauteurUtile: hauteurUtile,
            estTronque: gardees.count < toutes.count
        )
    }

    /// Composition vide, quand la bulle ne peut rien accueillir.
    private static func vide(
        gabarit: GabaritDeBulle,
        mesure: any MesureDeTexte,
        largeur: Double,
        hauteur: Double
    ) -> TexteDeBulleMisEnPage {
        TexteDeBulleMisEnPage(
            lignes: [],
            corps: gabarit.corpsMinimal,
            hauteurDeLigne: mesure.hauteurDeLigne(corps: gabarit.corpsMinimal),
            largeurUtile: max(0, largeur),
            hauteurUtile: max(0, hauteur),
            estTronque: true
        )
    }

    /// Ligne portant la marque de coupe, raccourcie jusqu a tenir en largeur.
    private static func marquer(
        _ ligne: String,
        largeur: Double,
        corps: Double,
        gabarit: GabaritDeBulle,
        mesure: any MesureDeTexte
    ) -> String {
        let marque = gabarit.marqueDeTroncature
        var restant = ligne

        while restant.isEmpty == false {
            let essai = restant + marque

            if mesure.largeur(de: essai, corps: corps) <= largeur {
                return essai
            }

            restant.removeLast()
        }

        return mesure.largeur(de: marque, corps: corps) <= largeur ? marque : ligne
    }

    /// Lignes obtenues en repliant le texte dans une largeur donnee.
    ///
    /// Le repli se fait au mot, et au caractere pour un mot plus large que la
    /// ligne. Un mot trop long existe reellement : une onomatopee translitteree
    /// ou un nom propre compose depassent souvent la largeur d une bulle
    /// etroite, et le laisser deborder reviendrait a renoncer au critere sur le
    /// cas precis ou il compte.
    static func decouper(
        _ texte: String,
        largeur: Double,
        corps: Double,
        mesure: any MesureDeTexte
    ) -> [String] {
        var lignes: [String] = []

        for paragraphe in texte.split(separator: "\n", omittingEmptySubsequences: false) {
            let mots = paragraphe.split(separator: " ").map(String.init)

            guard mots.isEmpty == false else { continue }

            var courante = ""

            for mot in mots {
                let candidate = courante.isEmpty ? mot : courante + " " + mot

                if mesure.largeur(de: candidate, corps: corps) <= largeur {
                    courante = candidate
                    continue
                }

                if courante.isEmpty == false {
                    lignes.append(courante)
                    courante = ""
                }

                let morceaux = decouperAuCaractere(
                    mot,
                    largeur: largeur,
                    corps: corps,
                    mesure: mesure
                )

                guard morceaux.isEmpty == false else { continue }

                lignes.append(contentsOf: morceaux.dropLast())
                courante = morceaux[morceaux.count - 1]
            }

            if courante.isEmpty == false {
                lignes.append(courante)
            }
        }

        return lignes
    }

    /// Morceaux d un mot plus large que la ligne, coupes au caractere.
    ///
    /// Rend une suite vide quand un seul caractere ne tient pas : la bulle est
    /// alors trop etroite pour porter quoi que ce soit, et l appelant le traite
    /// comme une composition vide plutot que de poser un caractere qui deborde.
    private static func decouperAuCaractere(
        _ mot: String,
        largeur: Double,
        corps: Double,
        mesure: any MesureDeTexte
    ) -> [String] {
        var morceaux: [String] = []
        var courant = ""

        for caractere in mot {
            let candidat = courant + String(caractere)

            if mesure.largeur(de: candidat, corps: corps) <= largeur {
                courant = candidat
                continue
            }

            guard courant.isEmpty == false else { return [] }

            morceaux.append(courant)
            courant = String(caractere)

            if mesure.largeur(de: courant, corps: corps) > largeur {
                return []
            }
        }

        if courant.isEmpty == false {
            morceaux.append(courant)
        }

        return morceaux
    }
}
