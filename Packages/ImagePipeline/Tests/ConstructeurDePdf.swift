import CoreGraphics
import Foundation

//
// ConstructeurDePdf
//
// Fabrique des PDF de test, en clair ou proteges par mot de passe.
//
// Le fichier est produit par le contexte PDF de Core Graphics plutot que copie
// depuis un jeu d echantillons. Un echantillon binaire dans le depot ne dirait
// pas comment il a ete fait, ne pourrait pas etre decline en quatre cents pages
// pour la mesure d ouverture, et son chiffrement ne pourrait pas etre regenere
// quand la cle change. Ici tout est explicite, y compris le mot de passe.
//
// Chaque page est remplie d un gris qui depend de son rang. Un test peut donc
// verifier que la page rendue est bien celle demandee, sans supposer une valeur
// exacte : la conversion vers l espace de travail deplace les niveaux, mais elle
// conserve leur ordre.
//

enum ConstructeurDePdf {
    /// Format A4 en points, celui que produisent les scanners par defaut.
    static let tailleA4 = CGSize(width: 595, height: 842)

    /// Octets d un PDF de `pages` pages.
    ///
    /// - Parameters:
    ///   - pages: nombre de pages a produire.
    ///   - taille: dimensions de la boite media, en points.
    ///   - origine: coin bas gauche de la boite media. Une origine non nulle est
    ///     legale et piege les rendus qui supposent zero.
    ///   - motDePasse: protege le document quand il est fourni.
    static func donnees(
        pages: Int,
        taille: CGSize = tailleA4,
        origine: CGPoint = .zero,
        motDePasse: String? = nil
    ) -> Data? {
        let sortie = NSMutableData()

        guard let consommateur = CGDataConsumer(data: sortie) else { return nil }

        var boite = CGRect(origin: origine, size: taille)
        var informations: [CFString: Any] = [:]

        if let motDePasse {
            informations[kCGPDFContextUserPassword] = motDePasse
            informations[kCGPDFContextOwnerPassword] = motDePasse
        }

        guard let contexte = CGContext(
            consumer: consommateur,
            mediaBox: &boite,
            informations as CFDictionary
        ) else {
            return nil
        }

        for rang in 0..<pages {
            contexte.beginPDFPage(nil)
            contexte.setFillColor(gray: niveauDeGris(rang), alpha: 1)
            contexte.fill(boite)
            contexte.endPDFPage()
        }

        contexte.closePDF()

        return sortie as Data
    }

    /// Ecrit un PDF dans le dossier indique et rend son emplacement.
    static func fichier(
        dans dossier: URL,
        nom: String = "chapitre.pdf",
        pages: Int,
        taille: CGSize = tailleA4,
        origine: CGPoint = .zero,
        motDePasse: String? = nil
    ) throws -> URL {
        let emplacement = dossier.appending(path: nom)

        guard let contenu = donnees(
            pages: pages,
            taille: taille,
            origine: origine,
            motDePasse: motDePasse
        ) else {
            throw ErreurDeConstruction.contexteRefuse
        }

        try contenu.write(to: emplacement)

        return emplacement
    }

    /// Gris de remplissage de la page de ce rang, croissant avec le rang.
    ///
    /// Les niveaux sont largement espaces pour qu aucune conversion d espace
    /// colorimetrique ne puisse les faire se croiser.
    static func niveauDeGris(_ rang: Int) -> CGFloat {
        min(0.9, 0.05 + CGFloat(rang) * 0.15)
    }

    /// Composante de gris lue au centre de l image, entre 0 et 255.
    ///
    /// La matrice produite par le rendu est du RGBA aligne. Sur un gris les
    /// trois composantes sont egales, lire la deuxieme evite donc d avoir a
    /// raisonner sur l ordre des octets.
    static func grisAuCentre(_ image: CGImage) -> Int? {
        guard let fournies = image.dataProvider?.data else { return nil }

        let octets = fournies as Data
        let position = (image.height / 2) * image.bytesPerRow + (image.width / 2) * 4 + 1

        guard position < octets.count else { return nil }

        return Int(octets[octets.startIndex + position])
    }

    enum ErreurDeConstruction: Error {
        /// Le systeme a refuse le contexte PDF, rien n a pu etre ecrit.
        case contexteRefuse
    }
}
