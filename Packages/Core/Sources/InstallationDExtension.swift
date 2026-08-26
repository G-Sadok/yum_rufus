import CryptoKit
import Foundation

//
// InstallationDExtension
//
// Le troisieme critere de la section 4.3 : l utilisateur voit la liste des
// domaines avant d installer, et doit confirmer.
//
// Le critere est tenu par la forme des types et non par la discipline de
// l appelant. `ConfirmationDesDomaines` n a pas d initialiseur public qui
// prendrait une empreinte : la seule facon d en obtenir une est de partir d un
// `AvertissementDInstallation`, lui meme construit depuis un manifeste. Une
// couche qui voudrait installer sans montrer la liste n aurait litteralement
// pas de valeur a passer.
//
// L empreinte de la liste est portee par la confirmation, et verifiee au moment
// d installer. Sans elle, il suffirait de montrer une liste, de recuperer un
// oui, puis d installer un manifeste different. Ce n est pas une precaution
// theorique : le paquet est telecharge, et rien n oblige le depot a rendre deux
// fois le meme document.
//

/// Ce que l utilisateur lit avant d installer une extension.
///
/// Le type ne porte que ce qui s affiche. Il ne porte pas le manifeste, pour
/// que l ecran ne puisse pas installer par ses propres moyens ce qu il est en
/// train de presenter.
public struct AvertissementDInstallation: Sendable, Hashable {
    public let identifiantDExtension: String
    public let nomDeLExtension: String
    public let version: VersionDExtension

    /// Langue du catalogue, au format BCP 47.
    public let langue: String

    /// Les domaines declares, tries, sans doublon.
    public let domaines: [DomaineAutorise]

    /// Ce que l extension pourra faire une fois installee.
    public let capacites: SourceCapacites

    /// Empreinte de la liste des domaines, ce sur quoi porte la confirmation.
    public let empreinteDesDomaines: String

    public init(manifeste: ManifesteDExtension) {
        identifiantDExtension = manifeste.identifiant
        nomDeLExtension = manifeste.nom
        version = manifeste.version
        langue = manifeste.langue
        domaines = manifeste.listeBlanche.domaines
        capacites = manifeste.capacites
        empreinteDesDomaines = Self.empreinte(de: manifeste.listeBlanche.domaines)
    }

    /// Les domaines, sous la forme textuelle que la vue affiche.
    public var domainesAffiches: [String] {
        domaines.map(\.texte)
    }

    /// Vrai quand l extension demande a joindre des sous domaines.
    ///
    /// L information merite d etre distinguee a l ecran : `*.exemple.net`
    /// couvre un nombre de machines que l utilisateur ne peut pas enumerer,
    /// la ou `api.exemple.net` en couvre une.
    public var couvreDesSousDomaines: Bool {
        domaines.contains { $0.inclutLesSousDomaines }
    }

    /// Empreinte stable d une liste de domaines.
    ///
    /// Les domaines sont deja tries et dedoublonnes par
    /// `ListeBlancheDeDomaines`, donc deux manifestes qui declarent les memes
    /// domaines dans un ordre different rendent la meme empreinte. C est
    /// voulu : l ordre d ecriture ne change pas ce que l utilisateur autorise.
    static func empreinte(de domaines: [DomaineAutorise]) -> String {
        let assemblee = domaines.map(\.texte).joined(separator: "\n")
        let condensat = SHA256.hash(data: Data(assemblee.utf8))

        return condensat.map { String(format: "%02x", $0) }.joined()
    }
}

/// La preuve que l utilisateur a lu la liste des domaines et l a acceptee.
///
/// Le seul initialiseur public part d un avertissement. C est ce qui rend le
/// troisieme critere structurel plutot que declaratif.
public struct ConfirmationDesDomaines: Sendable, Hashable {
    /// Empreinte de la liste effectivement montree.
    public let empreinteDesDomaines: String

    /// Extension pour laquelle la confirmation a ete donnee.
    public let identifiantDExtension: String

    /// Instant de la confirmation, conserve pour la fiche de l extension.
    public let instant: Date

    /// Confirme la liste que cet avertissement presente.
    public init(avertissement: AvertissementDInstallation, instant: Date) {
        empreinteDesDomaines = avertissement.empreinteDesDomaines
        identifiantDExtension = avertissement.identifiantDExtension
        self.instant = instant
    }

    /// Vrai quand cette confirmation porte sur ce manifeste la.
    func correspond(a manifeste: ManifesteDExtension) -> Bool {
        identifiantDExtension == manifeste.identifiant
            && empreinteDesDomaines == AvertissementDInstallation.empreinte(de: manifeste.listeBlanche.domaines)
    }
}

/// Une extension installee, avec la trace de ce que l utilisateur a accepte.
public struct ExtensionInstallee: Sendable, Hashable {
    public let manifeste: ManifesteDExtension

    /// La confirmation qui a autorise l installation.
    ///
    /// Elle est conservee et non jetee : la fiche de l extension montre a
    /// l utilisateur ce qu il a accepte et quand, et une mise a jour du paquet
    /// qui changerait la liste redemandera une confirmation.
    public let confirmation: ConfirmationDesDomaines

    public init(manifeste: ManifesteDExtension, confirmation: ConfirmationDesDomaines) {
        self.manifeste = manifeste
        self.confirmation = confirmation
    }

    /// La liste blanche qui s applique aux requetes de cette extension.
    public var listeBlanche: ListeBlancheDeDomaines {
        manifeste.listeBlanche
    }
}

/// Un paquet verifie, et ce que l utilisateur doit lire avant de l installer.
public struct PaquetPretAInstaller: Sendable, Hashable {
    public let manifeste: ManifesteDExtension
    public let avertissement: AvertissementDInstallation

    public init(manifeste: ManifesteDExtension, avertissement: AvertissementDInstallation) {
        self.manifeste = manifeste
        self.avertissement = avertissement
    }
}

/// Ce qui transforme un paquet telecharge en extension installee.
public struct InstallateurDExtensions: Sendable {
    private let verificateur: VerificateurDeSignature

    public init(verificateur: VerificateurDeSignature = VerificateurDeSignature()) {
        self.verificateur = verificateur
    }

    /// Verifie un paquet et prepare ce que l utilisateur doit lire.
    ///
    /// La signature est verifiee ici, avant l affichage, et non a
    /// l installation. Montrer la liste des domaines d un paquet non signe
    /// reviendrait a demander a l utilisateur d arbitrer une question de
    /// securite que l application sait deja trancher.
    ///
    /// - Throws: `ErreurDExtension`, dans le cas qui nomme le refus.
    public func preparer(enveloppe: Data) throws -> PaquetPretAInstaller {
        let manifeste = try verificateur.verifier(enveloppe: enveloppe)

        return PaquetPretAInstaller(
            manifeste: manifeste,
            avertissement: AvertissementDInstallation(manifeste: manifeste)
        )
    }

    /// Installe l extension, si et seulement si la confirmation la couvre.
    ///
    /// - Throws: `ErreurDExtension.confirmationNeCorrespondPas` quand la
    ///   confirmation porte sur une autre extension ou sur une autre liste de
    ///   domaines.
    public func installer(
        _ manifeste: ManifesteDExtension,
        confirmation: ConfirmationDesDomaines?
    ) throws -> ExtensionInstallee {
        guard let confirmation else {
            throw ErreurDExtension.domainesNonConfirmes
        }
        guard confirmation.correspond(a: manifeste) else {
            throw ErreurDExtension.confirmationNeCorrespondPas
        }

        return ExtensionInstallee(manifeste: manifeste, confirmation: confirmation)
    }
}

/// Les extensions installees, dans l ordre d installation.
///
/// Un acteur, comme `RegistreDeSources`, et pour la meme raison : la liste est
/// un etat mutable partage entre l ecran Parcourir, la feuille d installation
/// et les requetes en cours.
public actor RegistreDExtensions {
    private var installees: [ExtensionInstallee] = []

    public init() {}

    /// Les extensions installees, dans l ordre.
    public var toutes: [ExtensionInstallee] {
        installees
    }

    public var nombre: Int {
        installees.count
    }

    /// Installe l extension, ou remplace celle qui portait deja cet
    /// identifiant.
    ///
    /// Le remplacement conserve la position, comme dans `RegistreDeSources` :
    /// mettre a jour une extension ne doit pas la faire sauter en fin de liste
    /// sous les yeux de l utilisateur.
    public func inscrire(_ extensionInstallee: ExtensionInstallee) {
        let identifiant = extensionInstallee.manifeste.identifiant

        if let position = installees.firstIndex(where: { $0.manifeste.identifiant == identifiant }) {
            installees[position] = extensionInstallee
        } else {
            installees.append(extensionInstallee)
        }
    }

    /// Retire une extension, et rend vrai quand elle y etait.
    @discardableResult
    public func desinstaller(_ identifiant: String) -> Bool {
        guard let position = installees.firstIndex(where: { $0.manifeste.identifiant == identifiant }) else {
            return false
        }

        installees.remove(at: position)

        return true
    }

    /// L extension portant cet identifiant, ou nul.
    public func installee(_ identifiant: String) -> ExtensionInstallee? {
        installees.first { $0.manifeste.identifiant == identifiant }
    }
}
