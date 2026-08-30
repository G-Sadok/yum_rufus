import Foundation

//
// NotificationsDeChapitres
//
// Ce qu une verification en arriere plan produit, et la forme sous laquelle
// cela arrive a l utilisateur.
//
// La regle du produit tient en une phrase : une serie, une notification. Elle
// n est pas cosmetique. Une bibliotheque de cinq cents series qui reprend apres
// deux semaines d absence peut decouvrir plusieurs centaines de chapitres d un
// coup ; une notification par chapitre remplirait l ecran de verrouillage,
// ferait couper les notifications de l application par l utilisateur, et la
// fonction serait perdue des le premier usage.
//
// Le regroupement est fait ici, dans le domaine, et non par l identifiant de fil
// du centre de notifications du systeme. Ce dernier ne fait qu empiler
// visuellement des notifications deja emises : l appareil vibrerait toujours
// cent fois. La seule facon de tenir le critere est de n en construire qu une
// par serie, ce que cette fonction garantit et qu un test compte.
//
// Le mode incognito est traite ici plutot que chez l appelant, pour la meme
// raison que le registre d incognito est porte par le magasin qui ecrit : la
// garantie doit vivre au point de passage oblige. Une notification ne peut pas
// etre construite sans passer par `RegroupementDeNotifications`, et cette
// fonction rend une liste vide tant qu une session court.
//

/// Un chapitre paru chez une source depuis la derniere visite.
public struct NouveauChapitre: Sendable, Equatable, Hashable {
    /// Identifiant de la serie dans la base.
    public let serie: UUID

    /// Titre de la serie, tel que la notification l affichera.
    public let titreDeLaSerie: String

    /// Source qui a annonce le chapitre.
    public let source: SourceID

    /// Identifiant du chapitre chez la source.
    public let identifiant: String

    /// Numero annonce, decimal comme partout ailleurs.
    public let numero: Double

    /// Titre du chapitre, quand la source en publie un.
    public let titre: String?

    /// Rang du chapitre dans la serie, qui ordonne la liste.
    public let ordre: Int

    public init(
        serie: UUID,
        titreDeLaSerie: String,
        source: SourceID,
        identifiant: String,
        numero: Double,
        titre: String? = nil,
        ordre: Int
    ) {
        self.serie = serie
        self.titreDeLaSerie = titreDeLaSerie
        self.source = source
        self.identifiant = identifiant
        self.numero = numero
        self.titre = titre
        self.ordre = ordre
    }
}

/// Une notification, c est a dire une serie et ce qui vient d y paraitre.
public struct NotificationDeSerie: Sendable, Equatable, Hashable, Identifiable {
    /// L identite de la notification est celle de la serie, et c est le sujet.
    public var id: UUID {
        serie
    }

    /// Serie concernee.
    public let serie: UUID

    /// Titre de la serie, qui sert de titre a la notification.
    public let titreDeLaSerie: String

    /// Chapitres parus, du plus ancien au plus recent.
    public let chapitres: [NouveauChapitre]

    public init(serie: UUID, titreDeLaSerie: String, chapitres: [NouveauChapitre]) {
        self.serie = serie
        self.titreDeLaSerie = titreDeLaSerie
        self.chapitres = chapitres
    }

    /// Identifiant de fil pour le centre de notifications du systeme.
    ///
    /// Il double le regroupement fait ici : deux verifications successives sur
    /// la meme serie viennent alors se ranger dans la meme pile chez l
    /// utilisateur au lieu d ouvrir deux fils distincts.
    public var identifiantDeRegroupement: String {
        "serie.\(serie.uuidString)"
    }

    /// Nombre de chapitres annonces.
    public var nombreDeChapitres: Int {
        chapitres.count
    }

    /// Chapitre le plus recent, celui que la notification met en avant.
    public var dernierChapitre: NouveauChapitre? {
        chapitres.last
    }
}

/// Construction des notifications a partir de ce qu une verification a trouve.
public enum RegroupementDeNotifications {
    /// Une notification par serie, ou aucune.
    ///
    /// - Parameters:
    ///   - nouveautes: chapitres trouves pendant la verification, dans n
    ///     importe quel ordre.
    ///   - session: etat du mode incognito au moment de l emission, et non au
    ///     debut de la verification. Une session ouverte pendant que les
    ///     sources repondaient doit faire taire ce qui allait partir.
    public static func notifications(
        pour nouveautes: [NouveauChapitre],
        session: SessionIncognito = .inactive
    ) -> [NotificationDeSerie] {
        guard session.estActive == false else {
            return []
        }

        let parSerie = Dictionary(grouping: nouveautes, by: \.serie)

        return parSerie.values.compactMap(notification(pour:)).sorted(by: ordreDAffichage)
    }

    /// Notification d une seule serie, nulle quand rien n y est paru.
    private static func notification(pour chapitres: [NouveauChapitre]) -> NotificationDeSerie? {
        guard let premier = chapitres.first else {
            return nil
        }

        let ordonnes = chapitres.sorted { gauche, droite in
            gauche.ordre == droite.ordre
                ? gauche.numero < droite.numero
                : gauche.ordre < droite.ordre
        }

        return NotificationDeSerie(
            serie: premier.serie,
            titreDeLaSerie: premier.titreDeLaSerie,
            chapitres: ordonnes
        )
    }

    /// Ordre d emission, stable d une execution a l autre.
    ///
    /// Le titre d abord, l identifiant ensuite. Sans ce second critere, deux
    /// series homonymes changeraient de place d une verification a l autre,
    /// selon l ordre dans lequel le dictionnaire de regroupement les a rendues.
    private static func ordreDAffichage(_ gauche: NotificationDeSerie, _ droite: NotificationDeSerie) -> Bool {
        gauche.titreDeLaSerie == droite.titreDeLaSerie
            ? gauche.serie.uuidString < droite.serie.uuidString
            : gauche.titreDeLaSerie.localizedStandardCompare(droite.titreDeLaSerie) == .orderedAscending
    }
}

/// Detection des chapitres parus depuis la derniere visite d une serie.
public enum NouveautesDeSerie {
    /// Les chapitres que cet appareil ne connait pas encore.
    ///
    /// La comparaison porte sur l identifiant du chapitre chez la source, et
    /// jamais sur leur nombre. Une source qui retire un chapitre puis en publie
    /// un autre laisserait le compte inchange, et la nouveaute passerait
    /// inapercue.
    public static func chapitresInedits(
        de serie: SerieSurveillee,
        annonces: [ChapitreDistant]
    ) -> [ChapitreDistant] {
        annonces.filter { serie.chapitresConnus.contains($0.identifiant) == false }
    }

    /// Ce qu il faut annoncer a l utilisateur pour cette serie.
    ///
    /// Une premiere visite ne notifie rien. Ajouter une serie de deux cents
    /// chapitres a sa bibliotheque ferait sinon partir une notification
    /// annoncant deux cents nouveautes, alors que rien n est paru : la veille
    /// prend seulement connaissance de ce qui existait deja.
    public static func nouveautes(
        de serie: SerieSurveillee,
        annonces: [ChapitreDistant]
    ) -> [NouveauChapitre] {
        guard serie.estUnePremiereVisite == false else {
            return []
        }

        return chapitresInedits(de: serie, annonces: annonces).map { chapitre in
            NouveauChapitre(
                serie: serie.id,
                titreDeLaSerie: serie.titre,
                source: serie.source,
                identifiant: chapitre.identifiant,
                numero: chapitre.numero,
                titre: chapitre.titre,
                ordre: chapitre.ordre
            )
        }
    }
}
