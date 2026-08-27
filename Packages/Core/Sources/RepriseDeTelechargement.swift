import Foundation

//
// RepriseDeTelechargement
//
// Ou reprend un telechargement interrompu, et comment le demander au serveur.
//
// Une interruption arrive a deux endroits, et les deux se reparent
// differemment. Entre deux pages, il suffit de reprendre a la page suivante.
// Au milieu d une page, il faut reprendre au milieu du fichier, sinon les
// octets deja recus sont jetes a chaque coupure et un chapitre lourd sur une
// liaison instable ne se termine jamais.
//
// Le second cas passe par l entete `Range` de HTTP. Trois reponses sont
// possibles et une seule est celle qu on esperait. Le serveur peut servir la
// tranche demandee, et c est une reprise. Il peut ignorer l entete et renvoyer
// le fichier entier, ce qui n est pas une erreur mais oblige a jeter le
// fragment plutot qu a lui coller un doublon devant. Il peut refuser la tranche
// parce que le fichier a change de taille depuis, et il faut alors repartir de
// zero sur cette page. Confondre les trois produit une page corrompue qui ne se
// voit qu a l ouverture du chapitre, longtemps apres.
//

/// Ce qui a deja ete pose sur le disque pour un chapitre.
///
/// Les pages completes se comptent depuis le debut et sans trou. Une page
/// manquante au milieu arrete le compte : le moteur ecrit les pages dans
/// l ordre de lecture, un trou veut donc dire que le fichier suivant vient
/// d une tentative anterieure dont on ne sait pas si elle etait complete.
public struct InventaireDeTelechargement: Sendable, Equatable, Hashable {
    /// Nombre de pages completes, comptees depuis la premiere et sans trou.
    public let pagesCompletes: Int

    /// Octets deja ecrits du fragment de la page suivante.
    public let octetsDuFragment: Int

    public init(pagesCompletes: Int = 0, octetsDuFragment: Int = 0) {
        self.pagesCompletes = max(0, pagesCompletes)
        self.octetsDuFragment = max(0, octetsDuFragment)
    }

    /// Inventaire d un chapitre dont rien n a encore ete ecrit.
    public static let vierge = InventaireDeTelechargement()
}

/// Ou repartir dans un chapitre.
public struct PointDeReprise: Sendable, Equatable, Hashable {
    /// Page a telecharger, indexee a partir de zero.
    public let pageIndex: Int

    /// Octets deja recus de cette page, a ne pas redemander.
    public let octetsDejaRecus: Int

    public init(pageIndex: Int, octetsDejaRecus: Int = 0) {
        self.pageIndex = pageIndex
        self.octetsDejaRecus = octetsDejaRecus
    }

    /// Vrai quand la page repart de son debut.
    public var repartDeZero: Bool {
        octetsDejaRecus == 0
    }
}

/// Ce que le serveur a repondu a une demande de reprise.
public enum AccueilDeLaReprise: Sendable, Equatable {
    /// Le serveur sert la tranche demandee. Les octets recus se collent apres le
    /// fragment deja ecrit.
    case tranche

    /// Le serveur ignore la demande et renvoie tout. Le fragment est jete, les
    /// octets recus remplacent le fichier.
    case fichierEntier

    /// Le serveur refuse la tranche. La page repart de zero.
    case refusee
}

/// Calcul du point de reprise et de sa traduction en HTTP.
public enum RepriseDeTelechargement {
    /// Code de statut d une reponse partielle.
    public static let codePartiel = 206

    /// Code de statut d une tranche refusee.
    public static let codeTrancheInvalide = 416

    /// Nom de l entete qui demande une tranche.
    public static let enteteDeDemande = "Range"

    /// Nom de l entete qui decrit la tranche servie.
    public static let enteteDeReponse = "Content-Range"

    /// Ou reprendre, d apres ce qui est deja sur le disque.
    ///
    /// - Parameters:
    ///   - inventaire: ce qui a deja ete ecrit pour ce chapitre.
    ///   - nombreDePages: longueur du chapitre annoncee par la source.
    /// - Returns: le point de reprise, ou nil quand tout le chapitre est deja
    ///   la. Nil et non un point sur une page inexistante : un appelant qui
    ///   ignorerait le cas demanderait au serveur la page numero vingt cinq d un
    ///   chapitre qui en compte vingt cinq.
    public static func point(
        depuis inventaire: InventaireDeTelechargement,
        nombreDePages: Int
    ) -> PointDeReprise? {
        guard nombreDePages > 0 else {
            return nil
        }
        guard inventaire.pagesCompletes < nombreDePages else {
            return nil
        }

        return PointDeReprise(
            pageIndex: inventaire.pagesCompletes,
            octetsDejaRecus: inventaire.octetsDuFragment
        )
    }

    /// Valeur de l entete `Range` pour reprendre a cet octet.
    ///
    /// - Returns: nil quand rien n a encore ete recu. Un `bytes=0-` serait
    ///   accepte par la plupart des serveurs, mais il ferait repondre 206 la ou
    ///   200 est attendu, et le code de la reponse ne dirait plus rien de ce qui
    ///   s est passe.
    public static func enteteDePlage(a partir: Int) -> String? {
        guard partir > 0 else {
            return nil
        }

        return "bytes=\(partir)-"
    }

    /// Ce que le serveur a repondu, une fois la demande de tranche partie.
    ///
    /// - Parameters:
    ///   - code: code de statut de la reponse.
    ///   - contentRange: entete `Content-Range` de la reponse, quand il existe.
    ///   - attendu: premier octet demande.
    ///
    /// Le refus est un cas rendu et non une erreur levee : il se repare en
    /// repartant de zero sur la page, ce qui reste un telechargement qui
    /// aboutit.
    public static func accueil(code: Int, contentRange: String?, attendu: Int) -> AccueilDeLaReprise {
        guard attendu > 0 else {
            return .fichierEntier
        }

        if code == codeTrancheInvalide {
            return .refusee
        }
        guard code == codePartiel else {
            // Tout autre code de succes veut dire que le serveur a servi la
            // ressource entiere sans tenir compte de la demande.
            return .fichierEntier
        }
        guard let debut = premierOctet(de: contentRange), debut == attendu else {
            // Un 206 dont la tranche ne commence pas ou il faut est pire qu un
            // 200 : coller ces octets au fragment fabriquerait un fichier dont
            // le milieu manque, et rien ne le signalerait.
            return .refusee
        }

        return .tranche
    }

    /// Premier octet decrit par un entete `Content-Range`.
    ///
    /// La forme attendue est `bytes 200-1023/1024`. Une forme inconnue rend nil,
    /// ce que l accueil traite comme un refus.
    public static func premierOctet(de contentRange: String?) -> Int? {
        guard let contentRange else {
            return nil
        }

        let sansUnite = contentRange
            .replacingOccurrences(of: "bytes", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let tiret = sansUnite.firstIndex(of: "-") else {
            return nil
        }

        return Int(sansUnite[sansUnite.startIndex..<tiret])
    }
}
