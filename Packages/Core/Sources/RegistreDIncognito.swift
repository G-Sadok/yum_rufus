import Foundation

//
// RegistreDIncognito
//
// L etat courant du mode incognito, partage par toutes les couches qui
// ecrivent.
//
// Le choix du type est dicte par les appelants. La sauvegarde de position part
// depuis le moteur de lecture toutes les deux secondes, la consignation de
// l historique part depuis une transaction deja ouverte, et ni l une ni l autre
// ne peut suspendre son fil pour demander l etat d un acteur. Le registre expose
// donc une lecture synchrone, ce qui interdit l acteur et impose un verrou.
//
// La question du mode incognito se pose au plus pres de l ecriture, pas au plus
// pres de l interface. Un decorateur pose autour du magasin aurait laisse
// ouverts tous les chemins qui ne passent pas par lui, et il n existe aucun
// moyen de prouver qu il n en apparaitra jamais. Le registre est donc porte par
// le magasin lui meme, qui est le seul point d ecriture de la progression et de
// l historique.
//

/// Etat courant du mode incognito, lisible depuis n importe quel fil.
///
/// `@unchecked Sendable` est sur ici parce que le seul etat mutable de la classe
/// est `session`, et que tous ses acces, en lecture comme en ecriture, passent
/// par `verrou`. Aucune reference vers l interieur n est publiee : `sessionCourante`
/// rend une copie de valeur, `SessionIncognito` etant une structure.
public final class RegistreDIncognito: @unchecked Sendable {
    private let verrou = NSLock()
    private var session: SessionIncognito

    /// Construit un registre dans l etat donne, inactif par defaut.
    public init(_ session: SessionIncognito = .inactive) {
        self.session = session
    }

    /// Session au moment de la question.
    public var sessionCourante: SessionIncognito {
        verrou.withLock { session }
    }

    /// Vrai quand une session incognito court.
    public var estActif: Bool {
        sessionCourante.estActive
    }

    /// Ouvre une session incognito.
    public func demarrer(le date: Date = Date()) {
        verrou.withLock { session.demarrer(le: date) }
    }

    /// Ferme la session incognito.
    public func arreter() {
        verrou.withLock { session.arreter() }
    }

    /// Vrai quand cette ecriture peut partir dans l etat courant.
    public func autorise(_ ecriture: EcritureDeSession) -> Bool {
        verrou.withLock { session.autorise(ecriture) }
    }
}
