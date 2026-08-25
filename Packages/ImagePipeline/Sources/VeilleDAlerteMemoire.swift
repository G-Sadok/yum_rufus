import Dispatch

//
// VeilleDAlerteMemoire
//
// Branche les alertes memoire du systeme sur le cache memoire de pages.
//
// La source d alertes est abstraite pour deux raisons, et la seconde compte
// autant que la premiere.
//
// D abord parce que le paquet ImagePipeline ne doit dependre d aucune couche
// d interface. La notification `didReceiveMemoryWarning` appartient a UIKit et
// n existe pas sur macOS, l employer ici enfermerait le cache dans une seule
// plateforme. La pression memoire de Dispatch dit la meme chose, sur les deux
// systemes, sans rien importer de plus que la bibliotheque de concurrence.
//
// Ensuite parce qu une source de pression memoire ne se declenche pas sur
// commande. Sans abstraction, le chemin qui va de l alerte au cache ne serait
// verifiable par aucun test, et le critere de la fonctionnalite reposerait sur
// un appel direct a la reaction, c est a dire sur rien.
//

/// Source d alertes memoire.
public protocol SourceDAlerteMemoire: Sendable {
    /// Commence a observer, en appelant la reaction a chaque alerte.
    ///
    /// Observer une seconde fois remplace l observation precedente.
    func observer(_ reaction: @escaping @Sendable () async -> Void) async

    /// Cesse d observer.
    func arreter() async
}

/// Source adossee a la pression memoire signalee par le systeme.
public actor SourceDAlerteMemoireDuSysteme: SourceDAlerteMemoire {
    private var source: (any DispatchSourceMemoryPressure)?

    public init() {}

    public func observer(_ reaction: @escaping @Sendable () async -> Void) async {
        await arreter()

        let nouvelle = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )

        nouvelle.setEventHandler {
            Task { await reaction() }
        }

        // Une source Dispatch nait suspendue, et liberer une source suspendue
        // termine le processus. Elle est donc reprise ici, avant d etre retenue.
        nouvelle.resume()
        source = nouvelle
    }

    public func arreter() async {
        source?.cancel()
        source = nil
    }
}

/// Vide le cache memoire, sauf la page visible, a chaque alerte memoire.
public actor VeilleDAlerteMemoire {
    private let cache: CacheMemoireDePages
    private let source: any SourceDAlerteMemoire

    public init(
        cache: CacheMemoireDePages,
        source: any SourceDAlerteMemoire = SourceDAlerteMemoireDuSysteme()
    ) {
        self.cache = cache
        self.source = source
    }

    /// Commence a surveiller la memoire.
    public func demarrer() async {
        let cache = cache

        await source.observer {
            await cache.reagirAUneAlerteMemoire()
        }
    }

    /// Cesse de surveiller la memoire.
    public func arreter() async {
        await source.arreter()
    }
}
