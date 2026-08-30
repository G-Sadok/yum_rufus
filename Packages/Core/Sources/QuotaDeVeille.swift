import Foundation

//
// QuotaDeVeille
//
// Les limites de la veille de F060, et la comptabilite qui permet de les tenir.
//
// Elles vivent dans leur propre fichier parce qu elles se lisent seules : ce
// sont des nombres et un compteur, sans aucune connaissance des sources, des
// reglages ni du mode incognito. `VeilleDeChapitres` s en sert pour decider,
// et c est la seule direction de dependance entre les deux.
//
// Le mot quota recouvre trois limites distinctes, et les confondre est
// exactement ce qui fait refuser une application a la revue.
//
// 1. La limite du systeme. Une tache de rafraichissement en arriere plan est
//    accordee, jamais exigee, et elle est coupee au bout de quelques dizaines de
//    secondes. Le budget de temps borne donc le travail d une execution, et le
//    nombre de series interrogees en decoule.
// 2. La limite que nous nous imposons. Le systeme apprend des habitudes de
//    l utilisateur et espace les reveils tout seul, mais rien ne garantit qu il
//    ne nous en accorde pas deux a cinq minutes d intervalle. L intervalle
//    minimal et le plafond quotidien refusent alors le travail, au lieu de
//    consommer le budget offert.
// 3. La limite due au serveur d en face. Une source qui echoue est probablement
//    hors ligne ou en train de nous refuser l acces. Reessayer a la cadence
//    normale la martelerait ; le recul double a chaque echec consecutif, jusqu a
//    une journee.
//

/// Les limites que la veille s impose, section 12 pour l esprit et revue de
/// l App Store pour la lettre.
///
/// Aucune de ces valeurs n est un reglage. Ce sont les criteres d acceptation
/// ecrits sous une forme que la suite de tests peut verifier.
public struct QuotaDeVeille: Sendable, Equatable, Hashable {
    /// Temps minimal entre deux verifications.
    public let intervalleMinimal: TimeInterval

    /// Nombre maximal de verifications dans une journee civile.
    public let executionsParJour: Int

    /// Temps de travail accorde a une execution.
    ///
    /// Le systeme coupe une tache de rafraichissement en arriere plan sans
    /// preavis. Une execution qui depasse ce budget est arretee par nous, avec
    /// son etat enregistre, plutot que tuee par le systeme au milieu d une
    /// ecriture.
    public let budgetDeTemps: TimeInterval

    /// Nombre maximal de series interrogees pendant une execution.
    ///
    /// Les series non vues cette fois ci passent en tete du tour suivant, la
    /// rotation garantissant qu aucune n est oubliee.
    public let seriesParExecution: Int

    /// Recul applique apres le premier echec.
    public let reculInitial: TimeInterval

    /// Recul maximal, quels que soient les echecs accumules.
    public let reculMaximal: TimeInterval

    public init(
        intervalleMinimal: TimeInterval,
        executionsParJour: Int,
        budgetDeTemps: TimeInterval,
        seriesParExecution: Int,
        reculInitial: TimeInterval,
        reculMaximal: TimeInterval
    ) {
        self.intervalleMinimal = intervalleMinimal
        self.executionsParJour = max(1, executionsParJour)
        self.budgetDeTemps = budgetDeTemps
        self.seriesParExecution = max(1, seriesParExecution)
        self.reculInitial = reculInitial
        self.reculMaximal = max(reculInitial, reculMaximal)
    }

    /// Quota du produit.
    ///
    /// Quatre heures et six executions par jour se tiennent : les six
    /// executions ne peuvent pas tomber en rafale, et la journee entiere est
    /// couverte sans qu un seul reveil soit gaspille. Vingt cinq secondes
    /// laissent une marge sur les trente secondes que le systeme accorde en
    /// pratique a un rafraichissement.
    public static let parDefaut = QuotaDeVeille(
        intervalleMinimal: 4 * 3600,
        executionsParJour: 6,
        budgetDeTemps: 25,
        seriesParExecution: 20,
        reculInitial: 30 * 60,
        reculMaximal: 24 * 3600
    )

    /// Recul a observer apres ce nombre d echecs consecutifs.
    ///
    /// Il double a chaque echec et s arrete au plafond. Zero echec ne recule
    /// pas : c est l intervalle normal qui s applique alors.
    public func recul(apres echecsConsecutifs: Int) -> TimeInterval {
        guard echecsConsecutifs > 0 else {
            return 0
        }

        // Le doublement est borne avant d etre calcule. Sans cette borne, un
        // compteur d echecs qui aurait derive ferait deborder la puissance de
        // deux avant meme d etre compare au plafond.
        let doublements = min(echecsConsecutifs - 1, 20)
        let recul = reculInitial * pow(2, Double(doublements))

        return min(recul, reculMaximal)
    }

    /// Vrai quand le pire cas d une execution tient dans le budget de temps.
    ///
    /// Sert au test qui confronte le nombre de series interrogees au temps
    /// accorde : une execution qui ne peut pas tenir promet un travail que le
    /// systeme coupera toujours au meme endroit, donc des series jamais vues.
    public func tientDansLeBudget(delaiParSerie: TimeInterval) -> Bool {
        Double(seriesParExecution) * delaiParSerie <= budgetDeTemps
    }
}

/// Ce que la veille retient d une execution a l autre.
public struct EtatDeVeille: Sendable, Equatable, Hashable, Codable {
    /// Derniere execution reellement lancee, reussie ou non.
    public var derniereTentative: Date?

    /// Derniere execution ou toutes les sources interrogees ont repondu.
    public var derniereReussite: Date?

    /// Echecs consecutifs, remis a zero par la premiere reussite.
    public var echecsConsecutifs: Int

    /// Debut du jour civil que compte `executionsDuJour`.
    public var jourCompte: Date?

    /// Executions deja lancees dans ce jour civil.
    public var executionsDuJour: Int

    /// Etat d une installation ou la veille n a jamais tourne.
    public static let neuf = EtatDeVeille()

    public init(
        derniereTentative: Date? = nil,
        derniereReussite: Date? = nil,
        echecsConsecutifs: Int = 0,
        jourCompte: Date? = nil,
        executionsDuJour: Int = 0
    ) {
        self.derniereTentative = derniereTentative
        self.derniereReussite = derniereReussite
        self.echecsConsecutifs = echecsConsecutifs
        self.jourCompte = jourCompte
        self.executionsDuJour = executionsDuJour
    }

    /// Executions deja lancees dans la journee de cette date.
    ///
    /// Le compteur ne vaut que pour son propre jour. Interroge un autre jour,
    /// il repond zero, sans avoir besoin d une remise a zero programmee a
    /// minuit qui ne partirait pas si l application etait fermee.
    public func executions(le date: Date, calendrier: Calendar = .autoupdatingCurrent) -> Int {
        guard let jourCompte, calendrier.isDate(jourCompte, inSameDayAs: date) else {
            return 0
        }

        return executionsDuJour
    }

    /// Enregistre le depart d une execution.
    public mutating func compterUneExecution(le date: Date, calendrier: Calendar = .autoupdatingCurrent) {
        executionsDuJour = executions(le: date, calendrier: calendrier) + 1
        jourCompte = calendrier.startOfDay(for: date)
        derniereTentative = date
    }

    /// Enregistre une execution ou toutes les sources ont repondu.
    public mutating func compterUneReussite(le date: Date) {
        derniereReussite = date
        echecsConsecutifs = 0
    }

    /// Enregistre une execution ou au moins une source a echoue.
    public mutating func compterUnEchec() {
        echecsConsecutifs += 1
    }
}
