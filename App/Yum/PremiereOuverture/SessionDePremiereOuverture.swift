import Core
import DesignSystem
import Observation
import Storage

//
// Etat du parcours de premiere ouverture cote application, section 5.10 de
// DESIGN-SPEC.md.
//
// La session relie trois choses que le paquet metier ne connait pas : la base,
// qui retient que le parcours a ete fait, le magasin du sens de lecture, qui
// recoit la decision de la premiere etape, et la ligne de l ecran Reglages qui
// rejoue le parcours.
//
// Les decisions sont appliquees au moment ou elles sont prises, pas a la fin.
// Quelqu un qui ferme l application a la deuxieme etape garde le sens de
// lecture qu il vient de choisir, et le parcours revient au lancement suivant
// parce qu il n a pas ete mene a son terme.
//
// Une base absente ne fait pas tomber le parcours. Il s ouvre, il se traverse,
// et rien n est ecrit : c est preferable a un premier lancement bloque par un
// echec d ouverture de fichier.
//

/// Parcours de premiere ouverture, du premier lancement jusqu a son rejeu.
@MainActor
@Observable
final class SessionDePremiereOuverture {
    /// Ligne de l ecran Reglages qui rejoue le parcours.
    static let ligneDeRejeu: IdentifiantDeReglage = .revoirLaPremiereOuverture

    /// Etat du parcours, tel que le paquet Core le tient.
    private(set) var parcours = ParcoursDePremiereOuverture()

    /// Vrai quand l utilisateur a demande l essai premium.
    ///
    /// La session ne vend rien elle meme : elle note la demande, et la coquille
    /// ouvre le mur premium avec elle, section 10 du cahier de developpement.
    private(set) var essaiDemande = false

    private let magasin: MagasinDuParcoursDePremiereOuverture?
    private let sensDeLecture: MagasinDeSensDeLecture?

    /// Construit la session autour de la base ouverte au lancement.
    ///
    /// - Parameter base: base ouverte, nulle quand l ouverture a echoue.
    init(base: BaseDeDonnees?) {
        magasin = base.map(MagasinDuParcoursDePremiereOuverture.init(base:))
        sensDeLecture = base.map(MagasinDeSensDeLecture.init(base:))
        parcours = (try? magasin?.parcours()) ?? ParcoursDePremiereOuverture()
    }

    /// Ouvre le parcours au premier lancement, et a lui seul.
    func ouvrirAuLancement() {
        parcours.ouvrirAuLancement()
    }

    /// Rejoue le parcours depuis l ecran Reglages.
    ///
    /// - Parameter identifiant: ligne de reglages cliquee.
    /// - Returns: vrai quand la ligne est celle du rejeu et que le parcours
    ///   vient de se rouvrir.
    @discardableResult
    func repondre(a identifiant: IdentifiantDeReglage) -> Bool {
        guard identifiant == Self.ligneDeRejeu else { return false }

        parcours.rejouer()

        return true
    }

    /// Commandes passees a la vue.
    ///
    /// L ajout d une source et le lien vers les douze types restent inertes.
    /// L ecran Parcourir porte l ajout reel et n est pas encore monte dans la
    /// coquille : une ligne qui declencherait une connexion vers nulle part
    /// laisserait `Connexion en cours` a l ecran pour toujours. Le bouton
    /// Passer reste donc offert, et la deuxieme etape se traverse sans mentir.
    var commandes: CommandesDePremiereOuverture {
        CommandesDePremiereOuverture(
            choisirLeSens: { [weak self] sens in self?.choisirLeSens(sens) },
            ajouterLaSource: { _ in },
            voirToutesLesSources: {},
            executer: { [weak self] commande in self?.executer(commande) }
        )
    }

    // MARK: Decisions

    /// Premiere etape. Le sens est ecrit tout de suite, pas a la fin.
    private func choisirLeSens(_ sens: SensDeLecture) {
        parcours.choisirLeSens(sens)

        try? sensDeLecture?.definirLeSensGlobal(sens)
    }

    /// Applique une commande, et sort du parcours quand il est fait.
    private func executer(_ commande: CommandeDePremiereOuverture) {
        guard parcours.executer(commande) else { return }

        if parcours.dejaFait {
            try? magasin?.marquerFait()
        }
    }
}
