import Core
import Foundation

//
// FichiersSmb
//
// L ouverture des fichiers et le listage des dossiers, une fois la session
// ouverte.
//
// Deux choix meritent d etre dits.
//
// L ouverture ne demande que la lecture des donnees et des attributs. Un partage
// monte en lecture seule n a aucune raison de demander un droit d ecriture, et
// le demander ferait refuser l ouverture sur un partage publie en lecture seule,
// ce qui est le cas de la plupart des partages de bibliotheque.
//
// Le listage emploie la classe d information qui rend le nom, la taille, les
// attributs et les dates en une seule fois. Les classes plus legeres
// obligeraient a ouvrir chaque entree pour connaitre sa taille, soit deux allers
// retours par chapitre sur une bibliotheque qui en compte des milliers.
//

extension PartageSmb {
    // MARK: Ouverture

    /// Le descripteur d un chemin, ouvert au premier appel et retenu ensuite.
    func ouvrirDescripteur(_ chemin: String, dossier: Bool) async throws -> Data {
        if let connu = descripteurs[chemin] {
            return connu
        }

        let ouverture = try await creer(chemin, dossier: dossier)
        descripteurs[chemin] = ouverture.descripteur

        return ouverture.descripteur
    }

    /// Ouvre un fichier ou un dossier existant, en lecture seule.
    func creer(_ chemin: String, dossier: Bool) async throws -> OuvertureSmb2 {
        let nom = AuthentificationNtlm.utf16(NomsSmb2.chemin(chemin))

        var corps = EcritureSmb2()
        corps.entier16(57)
        corps.entier8(0)
        corps.entier8(0)
        corps.entier32(2)
        corps.entier64(0)
        corps.entier64(0)
        corps.entier32(Self.lectureDesDonnees | Self.lectureDesAttributs)
        corps.entier32(0)
        corps.entier32(Self.partageDeLecture | Self.partageDEcriture | Self.partageDeSuppression)
        corps.entier32(Self.ouvrirLExistant)
        corps.entier32(dossier ? Self.optionDeDossier : Self.optionDeFichier)
        corps.entier16(UInt16(EnTeteSmb2.taille + 56))
        corps.entier16(UInt16(nom.count))
        corps.entier32(0)
        corps.entier32(0)

        if nom.isEmpty {
            // La norme interdit une longueur nulle sans tampon. Un octet de
            // remplissage vaut la racine du partage.
            corps.entier8(0)
        } else {
            corps.fixe(nom)
        }

        return try await Self.ouverture(dans: echanger(.creer, corps: corps.octets))
    }

    /// Lit la reponse d une ouverture.
    private static func ouverture(dans reponse: ReponseSmb2) throws -> OuvertureSmb2 {
        var lecture = LectureSmb2(reponse.corps)

        guard lecture.entier16() == 89,
              lecture.sauter(6),
              lecture.sauter(8),
              lecture.sauter(8),
              let derniereEcriture = lecture.entier64(),
              lecture.sauter(8),
              lecture.sauter(8),
              let taille = lecture.entier64(),
              let attributs = lecture.entier32(),
              lecture.sauter(4),
              let descripteur = lecture.fixe(16)
        else {
            throw ErreurReseau.reponseIllisible
        }

        return OuvertureSmb2(
            descripteur: descripteur,
            taille: taille,
            derniereEcriture: derniereEcriture,
            estDossier: attributs & PartageSmb.attributDeDossier != 0
        )
    }

    /// Ferme un descripteur, sans se soucier de l echec.
    ///
    /// Un descripteur que le serveur a deja libere, apres une coupure par
    /// exemple, rend une erreur qui n interesse personne : la session est de
    /// toute facon en train d etre abandonnee.
    func fermerDescripteur(_ descripteur: Data) async {
        var corps = EcritureSmb2()
        corps.entier16(24)
        corps.entier16(0)
        corps.entier32(0)
        corps.fixe(descripteur)

        _ = try? await echanger(.fermer, corps: corps.octets)
    }

    // MARK: Listage

    /// Interroge un dossier, un tour a la fois.
    ///
    /// Rend nul quand le serveur annonce qu il n a plus rien, ce qui est sa
    /// facon normale de terminer un listage et non une erreur.
    func interrogerLeDossier(_ descripteur: Data, parent: String) async throws -> [EntreeDePartage]? {
        let motif = AuthentificationNtlm.utf16("*")

        var corps = EcritureSmb2()
        corps.entier16(33)
        corps.entier8(Self.informationsCompletes)
        corps.entier8(0)
        corps.entier32(0)
        corps.fixe(descripteur)
        corps.entier16(UInt16(EnTeteSmb2.taille + 32))
        corps.entier16(UInt16(motif.count))
        corps.entier32(Self.tamponDeListage)
        corps.fixe(motif)

        let reponse = try await echanger(
            .interrogerDossier,
            corps: corps.octets,
            statutsAcceptes: [StatutSmb2.plusAucunFichier]
        )

        guard reponse.entete.statut != StatutSmb2.plusAucunFichier else {
            return nil
        }

        var lecture = LectureSmb2(reponse.corps)

        guard lecture.entier16() == 9,
              let position = lecture.entier16(),
              let longueur = lecture.entier32(),
              let tampon = lecture.tranche(a: Int(position) - EnTeteSmb2.taille, longueur: Int(longueur))
        else {
            throw ErreurReseau.reponseIllisible
        }

        return Self.entrees(dans: tampon, parent: parent)
    }

    /// Decoupe le tampon d un listage en entrees.
    static func entrees(dans tampon: Data, parent: String) -> [EntreeDePartage] {
        var trouvees: [EntreeDePartage] = []
        var debut = 0

        while debut + tailleDUneEntree <= tampon.count {
            var lecture = LectureSmb2(tampon, a: debut)

            guard let suivante = lecture.entier32(),
                  lecture.sauter(4),
                  lecture.sauter(8),
                  lecture.sauter(8),
                  let derniereEcriture = lecture.entier64(),
                  lecture.sauter(8),
                  let taille = lecture.entier64(),
                  lecture.sauter(8),
                  let attributs = lecture.entier32(),
                  let longueurDuNom = lecture.entier32(),
                  lecture.sauter(4),
                  lecture.sauter(26),
                  lecture.sauter(2),
                  lecture.sauter(8),
                  let octetsDuNom = lecture.fixe(Int(longueurDuNom))
            else {
                return trouvees
            }

            let nom = NomsSmb2.nom(NomsSmb2.texte(octetsDuNom))

            // Le dossier lui meme et son parent reviennent dans tout listage.
            // Les garder ferait boucler l analyse a deux niveaux.
            if nom != ".", nom != ".." {
                trouvees.append(
                    EntreeDePartage(
                        chemin: CheminDePartage.joindre(parent, nom),
                        estDossier: attributs & attributDeDossier != 0,
                        taille: taille,
                        dateModification: NomsSmb2.date(derniereEcriture)
                    )
                )
            }

            guard suivante > 0 else {
                return trouvees
            }

            debut += Int(suivante)
        }

        return trouvees
    }

    // MARK: Constantes du protocole

    /// Taille de la partie fixe d une entree de listage, nom exclu.
    static var tailleDUneEntree: Int {
        104
    }

    /// Droit de lire le contenu d un fichier.
    static var lectureDesDonnees: UInt32 {
        0x0000_0001
    }

    /// Droit de lire les attributs d une entree.
    static var lectureDesAttributs: UInt32 {
        0x0000_0080
    }

    static var partageDeLecture: UInt32 {
        0x0000_0001
    }

    static var partageDEcriture: UInt32 {
        0x0000_0002
    }

    static var partageDeSuppression: UInt32 {
        0x0000_0004
    }

    /// Ouvrir une entree qui existe deja, et echouer sinon.
    static var ouvrirLExistant: UInt32 {
        1
    }

    static var optionDeDossier: UInt32 {
        0x0000_0001
    }

    static var optionDeFichier: UInt32 {
        0x0000_0040
    }

    /// Classe d information qui rend nom, taille, attributs et dates ensemble.
    static var informationsCompletes: UInt8 {
        0x25
    }
}
