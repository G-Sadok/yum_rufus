//
// ArbitreDeDecodage
//
// Arbitre entre le decodage de la page visible et celui des precharges.
//
// La regle de la section 6.2 est asymetrique, et il faut la lire dans le bon
// sens : la precharge cede, la page visible n attend pas. Un arbitre qui ferait
// patienter la page visible derriere une precharge en cours respecterait la
// lettre du critere en trahissant son intention, puisque c est exactement ce
// que l utilisateur ressentirait comme une tourne de page lente.
//
// D ou la forme retenue. La page visible declare son passage et decode sans
// demander la permission. La precharge demande un creneau avant chaque
// decodage, et attend qu aucune page visible ne soit en production.
//
// Ce que l arbitre garantit : aucun decodage de precharge ne commence pendant
// qu une page visible est en production. Ce qu il ne garantit pas : un
// decodage de precharge deja commence n est pas interrompu, un decodage etant
// indivisible une fois lance. Celui la s achevera en tache de fond, a priorite
// utilitaire, sur un autre fil que celui de la page visible. Le prix est borne
// a un decodage, et le payer serait moins cher que la solution inverse, qui
// consisterait a faire attendre la page visible.
//

/// Arbitre le decodage de la page visible face aux precharges.
public actor ArbitreDeDecodage {
    private var pagesVisiblesEnProduction = 0
    private var attentes: [CheckedContinuation<Void, Never>] = []

    public init() {}

    /// Vrai tant qu au moins une page visible est en production.
    public var estOccupe: Bool {
        pagesVisiblesEnProduction > 0
    }

    /// Declare qu une page visible entre en production.
    ///
    /// La production couvre la lecture des octets et le decodage, pas seulement
    /// le decodage. Une precharge lancee pendant la lecture des octets
    /// arriverait au decodage juste au moment ou la page visible y arrive
    /// aussi, ce que le creneau doit precisement eviter.
    public func commencerUnePageVisible() {
        pagesVisiblesEnProduction += 1
    }

    /// Declare qu une page visible sort de production, et libere les precharges.
    public func terminerUnePageVisible() {
        pagesVisiblesEnProduction = max(0, pagesVisiblesEnProduction - 1)

        guard pagesVisiblesEnProduction == 0 else {
            return
        }

        let liberees = attentes
        attentes.removeAll()

        for attente in liberees {
            attente.resume()
        }
    }

    /// Attend qu aucune page visible ne soit en production.
    ///
    /// La boucle et non un simple `if` : plusieurs precharges peuvent etre
    /// liberees ensemble, et une nouvelle page visible peut entrer en
    /// production avant qu elles ne reprennent la main.
    public func attendreUnCreneau() async {
        while pagesVisiblesEnProduction > 0 {
            await withCheckedContinuation { suite in
                attentes.append(suite)
            }
        }
    }
}
