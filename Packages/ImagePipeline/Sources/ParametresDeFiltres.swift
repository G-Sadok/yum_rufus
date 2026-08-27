import Core
import Foundation

//
// ParametresDeFiltres
//
// Traduction des curseurs du panneau, tous gradues de zero a cent, vers les
// parametres que Core Image attend.
//
// Le calcul est sorti des filtres pour rester verifiable sans GPU. Ce qui compte
// ici tient en trois promesses, et la suite de tests les mesure une par une.
//
// La valeur par defaut d un curseur rend le parametre neutre, exactement. Cent
// pour la luminosite ne touche a rien, cinquante pour le contraste et le gamma
// non plus. Un curseur laisse sur sa position de depart ne doit rien couter et
// rien changer, sans quoi une installation neuve appliquerait deja des filtres.
//
// La reponse est monotone. Pousser un curseur vers le haut pousse toujours le
// parametre dans le meme sens. Un curseur qui rebrousse chemin au milieu de sa
// course est un curseur que l utilisateur ne peut pas apprendre.
//
// Les amplitudes restent modestes. Une page de manga est une oeuvre en noir et
// blanc dense : un contraste multiplie par trois brule les aplats et bouche les
// noirs, et le lecteur n a plus aucun reglage utilisable entre les deux bouts de
// sa course.
//

enum ParametresDeFiltres {
    /// Temperature de reference, celle du blanc de la lumiere du jour.
    static let temperatureNeutre: Double = 6500

    /// Ecart de temperature au bout de la course du curseur de chaleur.
    ///
    /// Le curseur ne peut que rechauffer : sa valeur par defaut est zero, et la
    /// section 5.7 ne prevoit pas de refroidir une planche.
    static let amplitudeDeTemperature: Double = 3000

    /// Force d accentuation au bout de la course du curseur de nettete.
    static let plafondDeNettete: Double = 0.8

    /// Decalage de luminosite passe a `CIColorControls`.
    ///
    /// De moins un a zero. Le curseur part de cent, ou il ne change rien, et ne
    /// fait qu assombrir, comme la ligne `Luminosite du lecteur` de la section
    /// 5.5 : personne n eclaircit une planche au dela de ce que le fichier
    /// porte, on la baisse pour lire la nuit.
    static func luminosite(_ valeur: Double) -> Double {
        (borne(valeur) - 100) / 100
    }

    /// Facteur de contraste passe a `CIColorControls`, de 0,5 a 1,5.
    static func contraste(_ valeur: Double) -> Double {
        0.5 + borne(valeur) / 100
    }

    /// Exposant passe a `CIGammaAdjust`, de 2 a 0,5, un au milieu de la course.
    ///
    /// La progression est geometrique et non lineaire : le gamma est un
    /// exposant, et une progression lineaire rendrait la moitie basse de la
    /// course inutilisable pendant que la moitie haute changerait tout.
    static func gamma(_ valeur: Double) -> Double {
        pow(2, (50 - borne(valeur)) / 50)
    }

    /// Force passee a `CISharpenLuminance`, de zero au plafond de nettete.
    static func nettete(_ valeur: Double) -> Double {
        borne(valeur) / 100 * plafondDeNettete
    }

    /// Point neutre declare a `CITemperatureAndTint`, en kelvins.
    ///
    /// Le filtre ramene le blanc annonce par ce point vers le blanc cible. Lui
    /// annoncer un blanc plus froid que la lumiere du jour revient a lui dire
    /// que la planche a ete eclairee au bleu, et il la rechauffe d autant. La
    /// cible, elle, ne bouge pas : c est la reference du produit.
    static func temperature(_ valeur: Double) -> Double {
        temperatureNeutre + borne(valeur) / 100 * amplitudeDeTemperature
    }

    /// Valeur ramenee dans les bornes communes a tous les curseurs du produit.
    private static func borne(_ valeur: Double) -> Double {
        BornesDeReglage.pourcentage.contraindre(valeur)
    }
}
