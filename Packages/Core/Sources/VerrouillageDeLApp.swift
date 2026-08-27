import Foundation

//
// VerrouillageDeLApp
//
// Le verrouillage de la section 11 du cahier de developpement : authentification
// locale, avec repli sur le code de l appareil, et verrouillage au bout de trente
// secondes en arriere plan.
//
// Le delai est ecrit une seule fois, ici, et la suite de tests le confronte a la
// phrase du document plutot qu a une copie posee a cote.
//
// La bascule n est pas un minuteur mais une fonction du temps. Un minuteur ne
// survit pas a une suspension du processus, et l application peut etre gelee par
// le systeme pendant qu elle est en arriere plan : au retour, l echeance n aurait
// jamais sonne et l ecran s ouvrirait sans rien demander. En comparant deux dates,
// le verrouillage est vrai des que le delai est passe, que le processus ait
// tourne ou non.
//
// L application garde tout de meme une echeance, `dateDeVerrouillagePrevue`, pour
// poser un reveil quand elle continue de tourner en arriere plan. C est un
// confort d affichage, pas la regle : la regle reste la comparaison de dates.
//

/// Etat du verrou de l application.
public enum EtatDeVerrouillage: String, Sendable, Equatable, CaseIterable {
    /// L application est utilisable.
    case ouvert

    /// L application demande une authentification avant de montrer quoi que ce
    /// soit.
    case verrouille

    /// Vrai quand l ecran de verrouillage est a l affiche.
    public var demandeUneAuthentification: Bool {
        self == .verrouille
    }
}

/// Moyen par lequel l utilisateur rouvre l application.
public enum MoyenDeDeverrouillage: String, Sendable, Equatable, CaseIterable {
    /// Face ID ou Touch ID.
    case biometrie

    /// Code de l appareil, repli exige par la section 11.
    case codeDeLAppareil
}

/// Ce qui peut empecher un deverrouillage.
///
/// Chaque cas nomme sa cause et porte sa sortie, comme l exige la regle de
/// gestion d erreur du projet. Le libelle affiche vient du catalogue de chaines,
/// jamais d ici.
public enum ErreurDeVerrouillage: Error, Sendable, Equatable {
    /// L appareil n a ni biometrie ni code. Le verrou ne peut pas s armer, sans
    /// quoi l application deviendrait inaccessible a son proprietaire.
    case aucunMoyenDisponible

    /// L authentification a ete tentee et refusee.
    case echecDeLAuthentification

    /// L utilisateur a renonce. Ce n est pas une panne, l ecran ne dit rien.
    case annuleParLUtilisateur
}

/// Demande une authentification au systeme.
///
/// Le protocole vit dans `Core` pour que la regle de verrouillage se teste sans
/// LocalAuthentication, qui exige un appareil reel et une interaction humaine.
/// L implantation qui parle au systeme vit dans la cible de l application.
public protocol AuthentificationLocale: Sendable {
    /// Moyens que l appareil accepte aujourd hui.
    func moyensDisponibles() async -> Set<MoyenDeDeverrouillage>

    /// Demande l authentification et rend le moyen qui a servi.
    ///
    /// - Parameter raison: phrase montree par le systeme, prise dans le
    ///   catalogue de chaines.
    /// - Throws: `ErreurDeVerrouillage` quand l authentification echoue, est
    ///   annulee, ou qu aucun moyen n existe.
    func deverrouiller(raison: String) async throws -> MoyenDeDeverrouillage
}

/// Choix du moyen d authentification, section 11.
///
/// Le document dit `LocalAuthentication`, avec repli sur le code de l appareil.
/// Le repli n est pas un second essai apres un echec de la biometrie, c est le
/// moyen retenu quand la biometrie n existe pas ou n est pas configuree. Un
/// appareil sans capteur doit pouvoir armer le verrou.
public enum PolitiqueDeDeverrouillage {
    /// Moyen retenu parmi ceux que l appareil accepte, nul quand il n en accepte
    /// aucun.
    public static func moyen(
        parmi disponibles: Set<MoyenDeDeverrouillage>
    ) -> MoyenDeDeverrouillage? {
        if disponibles.contains(.biometrie) {
            return .biometrie
        }

        return disponibles.contains(.codeDeLAppareil) ? .codeDeLAppareil : nil
    }

    /// Vrai quand le reglage peut s armer sur cet appareil.
    ///
    /// Faux sur un appareil sans code : armer le verrou y enfermerait la
    /// bibliotheque derriere une porte que personne ne peut ouvrir.
    public static func peutSArmer(avec disponibles: Set<MoyenDeDeverrouillage>) -> Bool {
        moyen(parmi: disponibles) != nil
    }
}

/// Verrou de l application, section 11.
public struct VerrouillageDeLApp: Sendable, Equatable {
    /// Duree passee en arriere plan au dela de laquelle l application se
    /// verrouille, section 11.
    public static let delaiEnArrierePlan: TimeInterval = 30

    /// Vrai quand le reglage `Verrouillage de l app` est actif.
    public private(set) var estArme: Bool

    /// Etat du verrou a la derniere observation.
    public private(set) var etat: EtatDeVerrouillage

    /// Instant du dernier passage en arriere plan, nul au premier plan.
    public private(set) var passeEnArrierePlanLe: Date?

    public init(
        estArme: Bool = false,
        etat: EtatDeVerrouillage = .ouvert,
        passeEnArrierePlanLe: Date? = nil
    ) {
        self.estArme = estArme
        self.etat = etat
        self.passeEnArrierePlanLe = passeEnArrierePlanLe
    }

    // MARK: Reglage

    /// Arme le verrou.
    ///
    /// L application ne se verrouille pas pour autant : le reglage decide de ce
    /// qui se passera au prochain passage en arriere plan, il ne ferme pas la
    /// porte sous les doigts de celui qui vient de le toucher.
    public mutating func armer() {
        estArme = true
    }

    /// Desarme le verrou et rouvre l application.
    ///
    /// Laisser l ecran de verrouillage en place apres avoir coupe le reglage
    /// donnerait une application fermee par une regle qui ne s applique plus.
    public mutating func desarmer() {
        estArme = false
        etat = .ouvert
        passeEnArrierePlanLe = nil
    }

    // MARK: Cycle de vie

    /// Note le passage en arriere plan.
    ///
    /// La date est retenue meme quand le verrou n est pas arme. C est
    /// `estArme` qui decide, au moment de la question, et non l enregistrement :
    /// une condition posee ici ferait dependre le resultat de l ordre dans
    /// lequel le reglage et le cycle de vie sont arrives.
    public mutating func passerEnArrierePlan(le date: Date) {
        passeEnArrierePlanLe = date
    }

    /// Etat du verrou a cet instant.
    ///
    /// Le seuil est atteint des que le delai est ecoule, bornes comprises. Une
    /// comparaison stricte laisserait ouverte l application revenue exactement a
    /// la trentieme seconde, ce que le document ne prevoit pas.
    public func etat(a instant: Date) -> EtatDeVerrouillage {
        guard etat == .ouvert, estArme, let depuis = passeEnArrierePlanLe else {
            return etat
        }

        let ecoule = instant.timeIntervalSince(depuis)

        return ecoule >= Self.delaiEnArrierePlan ? .verrouille : .ouvert
    }

    /// Instant ou le verrou se fermera, nul quand rien ne l attend.
    ///
    /// Sert a poser un reveil pendant que l application tourne encore en arriere
    /// plan, pour qu elle soit deja verrouillee quand elle revient a l ecran.
    public var dateDeVerrouillagePrevue: Date? {
        guard etat == .ouvert, estArme, let depuis = passeEnArrierePlanLe else {
            return nil
        }

        return depuis.addingTimeInterval(Self.delaiEnArrierePlan)
    }

    /// Verrouille si le delai est ecoule, sans rien changer sinon.
    public mutating func verrouillerSiLeDelaiEstEcoule(a instant: Date) {
        etat = etat(a: instant)
    }

    /// Retour au premier plan a cet instant.
    ///
    /// Le compte a rebours repart de zero a chaque retour. Deux passages courts
    /// separes par un usage reel ne s additionnent pas : ce que le document
    /// mesure, c est une absence continue de trente secondes.
    public mutating func revenirAuPremierPlan(le instant: Date) {
        etat = etat(a: instant)
        passeEnArrierePlanLe = nil
    }

    /// Rouvre l application apres une authentification reussie.
    public mutating func deverrouiller() {
        etat = .ouvert
        passeEnArrierePlanLe = nil
    }
}
