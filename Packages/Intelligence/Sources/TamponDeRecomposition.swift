//
// TamponDeRecomposition
//
// Fond les tuiles traitees les unes dans les autres et rend la page.
//
// Poser les tuiles cote a cote laisserait une ligne visible a chaque raccord,
// pour la raison exposee dans TuilageDeTraitement : au bord de son entree, le
// modele extrapole, et deux tuiles voisines extrapolent differemment. Le
// recouvrement n existe que pour donner de quoi fondre.
//
// La fusion est une moyenne ponderee, pas une juxtaposition. Chaque tuile
// apporte un poids qui vaut un en son milieu et descend jusqu au bord sur la
// largeur du recouvrement. Dans la zone commune, le poids de la tuile qui finit
// descend pendant que celui de la tuile qui commence monte, et la somme des
// contributions divisee par la somme des poids passe continument de l une a
// l autre. Il n y a donc aucune ligne ou la valeur saute : le raccord n est pas
// cache, il n existe pas.
//
// Deux consequences de cette regle meritent d etre dites.
//
// Un bord de tuile qui est aussi un bord de page ne recoit pas de rampe. Rien ne
// vient s y fondre, et une rampe y ferait tendre le poids vers zero sans que
// personne ne compense, ce qui delaverait les quatre bords de la planche.
//
// Un modele qui rend la meme valeur quel que soit le decoupage retrouve
// exactement cette valeur apres fusion, puisque la moyenne ponderee de valeurs
// egales est cette valeur. La recomposition n ajoute donc aucune erreur qui lui
// soit propre, et la suite de tests le verifie sur un modele de ce genre.
//
// La memoire est bornee par une fenetre. Les tuiles arrivent ligne par ligne, et
// une ligne de tuiles ne peut plus rien recevoir des que la suivante commence.
// Le tampon ne garde donc en flottants qu une bande de la hauteur d une tuile
// sortie, qu il vide dans la page a mesure. Accumuler la page entiere en
// flottants couterait huit fois son poids en octets, ce qui est exactement la
// troisieme erreur du cahier.
//

/// Accumulateur pondere des tuiles traitees, sur une bande glissante.
struct TamponDeRecomposition {
    /// Largeur de la page produite.
    let largeur: Int

    /// Hauteur de la page produite.
    let hauteur: Int

    /// Hauteur de la bande tenue en flottants.
    let hauteurDeFenetre: Int

    /// Ligne de la page correspondant a la premiere ligne de la fenetre.
    private(set) var origine = 0

    private var sommes: [Float]
    private var poids: [Float]
    private var pixels: [UInt8]

    /// Prepare un tampon pour une page de ces dimensions.
    init(largeur: Int, hauteur: Int, hauteurDeFenetre: Int) {
        self.largeur = max(1, largeur)
        self.hauteur = max(1, hauteur)
        self.hauteurDeFenetre = min(max(1, hauteurDeFenetre), self.hauteur)

        let canaux = MatriceDePixels.octetsParPixel

        sommes = [Float](repeating: 0, count: self.largeur * self.hauteurDeFenetre * canaux)
        poids = [Float](repeating: 0, count: self.largeur * self.hauteurDeFenetre)
        pixels = [UInt8](repeating: 0, count: self.largeur * self.hauteur * canaux)
    }

    /// Ajoute une tuile surelevee a la fenetre, ponderee par ses deux rampes.
    ///
    /// La tuile doit tenir entierement dans la fenetre courante. C est le cas
    /// par construction : la fenetre est videe jusqu au sommet de la ligne de
    /// tuiles avant que ses tuiles ne soient deposees.
    mutating func deposer(
        _ tuile: MatriceDePixels,
        origineX: Int,
        origineY: Int,
        poidsHorizontal: [Float],
        poidsVertical: [Float]
    ) {
        let canaux = MatriceDePixels.octetsParPixel

        for ligne in 0..<tuile.hauteur {
            let ligneDeFenetre = origineY + ligne - origine

            guard ligneDeFenetre >= 0, ligneDeFenetre < hauteurDeFenetre else { continue }

            let poidsDeLigne = poidsVertical[ligne]
            let departDeTuile = ligne * tuile.largeur * canaux
            let departDeFenetre = ligneDeFenetre * largeur

            for colonne in 0..<tuile.largeur {
                let colonneDePage = origineX + colonne

                guard colonneDePage >= 0, colonneDePage < largeur else { continue }

                let poidsDuPixel = poidsDeLigne * poidsHorizontal[colonne]
                let source = departDeTuile + colonne * canaux
                let arrivee = (departDeFenetre + colonneDePage) * canaux

                for canal in 0..<canaux {
                    sommes[arrivee + canal] += poidsDuPixel * Float(tuile.octets[source + canal])
                }

                poids[departDeFenetre + colonneDePage] += poidsDuPixel
            }
        }
    }

    /// Ecrit dans la page toutes les lignes situees avant celle ci, puis fait
    /// glisser la fenetre jusqu a elle.
    ///
    /// Une ligne videe ne peut plus rien recevoir. C est vrai par construction :
    /// les tuiles arrivent du haut vers le bas, et une ligne de tuiles ne
    /// touche jamais au dessus de sa propre origine.
    mutating func avancer(jusqua ligne: Int) {
        let arret = min(max(ligne, origine), hauteur)

        guard arret > origine else { return }

        for ligneDePage in origine..<arret {
            normaliser(ligneDePage)
        }

        glisser(de: arret - origine)
        origine = arret
    }

    /// Vide la fenetre entiere et rend la page produite.
    mutating func terminer() -> MatriceDePixels? {
        avancer(jusqua: hauteur)

        return MatriceDePixels(largeur: largeur, hauteur: hauteur, octets: pixels)
    }

    /// Ecrit une ligne de la fenetre dans la page, poids divise.
    ///
    /// Un pixel sans poids reste noir. Le cas n arrive pas sur une page tuilee,
    /// puisque chaque pixel appartient a au moins une tuile et que le poids
    /// d une tuile ne descend jamais jusqu a zero, mais le laisser sans garde
    /// ferait une division par zero le jour ou la geometrie changerait.
    private mutating func normaliser(_ ligneDePage: Int) {
        let canaux = MatriceDePixels.octetsParPixel
        let departDeFenetre = (ligneDePage - origine) * largeur
        let departDePage = ligneDePage * largeur

        for colonne in 0..<largeur {
            let poidsDuPixel = poids[departDeFenetre + colonne]

            guard poidsDuPixel > 0 else { continue }

            let source = (departDeFenetre + colonne) * canaux
            let arrivee = (departDePage + colonne) * canaux

            for canal in 0..<canaux {
                let valeur = (sommes[source + canal] / poidsDuPixel).rounded()

                pixels[arrivee + canal] = UInt8(min(max(valeur, 0), 255))
            }
        }
    }

    /// Fait remonter le contenu de la fenetre et remet la queue a zero.
    private mutating func glisser(de lignes: Int) {
        let canaux = MatriceDePixels.octetsParPixel
        let conservees = max(0, hauteurDeFenetre - lignes)

        for ligne in 0..<conservees {
            let source = (ligne + lignes) * largeur
            let arrivee = ligne * largeur

            for colonne in 0..<largeur {
                poids[arrivee + colonne] = poids[source + colonne]

                for canal in 0..<canaux {
                    sommes[(arrivee + colonne) * canaux + canal] =
                        sommes[(source + colonne) * canaux + canal]
                }
            }
        }

        for ligne in conservees..<hauteurDeFenetre {
            let depart = ligne * largeur

            for colonne in 0..<largeur {
                poids[depart + colonne] = 0

                for canal in 0..<canaux {
                    sommes[(depart + colonne) * canaux + canal] = 0
                }
            }
        }
    }
}
