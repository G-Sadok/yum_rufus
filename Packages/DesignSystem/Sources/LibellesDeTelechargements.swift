import Core
import Foundation

//
// Textes de la file de telechargement, section 4.11 de DESIGN-SPEC.md.
//
// Aucun mot n est ecrit ici. Le paquet DesignSystem sait ou poser un libelle,
// pas comment le formuler : les chaines viennent du catalogue de l application.
//
// La sous ligne est composee ici plutot que par l application, comme celle d une
// ligne de chapitre : elle depend de l etat de la tache, et le document donne
// trois formes differentes pour trois etats. Les laisser a l appelant reviendrait
// a esperer que chaque ecran refasse le meme calcul de la meme facon.
//
// Le poids est mis en forme ici pour la meme raison, avec les motifs du
// catalogue. Un formateur du systeme rendrait une chaine qui depend de la langue
// de l appareil, et la suite de tests ne pourrait plus verifier que la sous
// ligne du document, `Termine  32 Mo`, est bien celle qui s affiche.
//

/// Textes de la file de telechargement.
public struct LibellesDeTelechargements: Sendable, Equatable {
    /// Titre de l ecran.
    public let titre: String

    /// Description posee sous le panneau, qui dit ce que la file fait.
    public let description: String

    /// Motif du chapitre, `Chapitre %@`.
    public let chapitreNumerote: String

    /// Motif de la sous ligne en cours, `%1$lld sur %2$lld pages`.
    public let pagesFaites: String

    /// Sous ligne d une tache qui attend son tour.
    public let enAttente: String

    /// Motif de la sous ligne d une tache terminee, `Termine  %@`.
    public let termineAvecPoids: String

    /// Sous ligne d une tache terminee dont le poids est inconnu.
    public let termine: String

    /// Sous ligne d une tache mise en pause.
    public let enPause: String

    /// Sous ligne d une tache annulee.
    public let annulee: String

    /// Motifs de poids, du plus petit au plus grand.
    public let poidsEnOctets: String
    public let poidsEnKo: String
    public let poidsEnMo: String
    public let poidsEnGo: String

    /// Commande qui met une ligne en pause.
    public let mettreEnPause: String

    /// Commande qui remet une ligne dans la file.
    public let reprendre: String

    /// Commande qui fait passer une ligne devant les autres.
    public let passerEnPremier: String

    /// Commande qui retire une ligne de la file.
    public let annuler: String

    /// Etiquette d accessibilite du bouton de commandes d une ligne.
    public let options: String

    /// Titre de l etat vide.
    public let videTitre: String

    /// Phrase de l etat vide, qui dit quoi faire.
    public let videPhrase: String

    /// Libelle de l action de l etat vide.
    public let videAction: String

    public init(
        titre: String,
        description: String,
        chapitreNumerote: String,
        pagesFaites: String,
        enAttente: String,
        termineAvecPoids: String,
        termine: String,
        enPause: String,
        annulee: String,
        poidsEnOctets: String,
        poidsEnKo: String,
        poidsEnMo: String,
        poidsEnGo: String,
        mettreEnPause: String,
        reprendre: String,
        passerEnPremier: String,
        annuler: String,
        options: String,
        videTitre: String,
        videPhrase: String,
        videAction: String
    ) {
        self.titre = titre
        self.description = description
        self.chapitreNumerote = chapitreNumerote
        self.pagesFaites = pagesFaites
        self.enAttente = enAttente
        self.termineAvecPoids = termineAvecPoids
        self.termine = termine
        self.enPause = enPause
        self.annulee = annulee
        self.poidsEnOctets = poidsEnOctets
        self.poidsEnKo = poidsEnKo
        self.poidsEnMo = poidsEnMo
        self.poidsEnGo = poidsEnGo
        self.mettreEnPause = mettreEnPause
        self.reprendre = reprendre
        self.passerEnPremier = passerEnPremier
        self.annuler = annuler
        self.options = options
        self.videTitre = videTitre
        self.videPhrase = videPhrase
        self.videAction = videAction
    }
}

/// Assemblage des textes d une ligne de la file.
public enum TexteDeTelechargement {
    /// Titre d une ligne, `Berserk  Chapitre 43`.
    ///
    /// La serie d abord, le chapitre ensuite. Une file melange des series, et
    /// l utilisateur y cherche une serie avant d y chercher un numero.
    public static func titre(
        de tache: TelechargementAffiche,
        libelles: LibellesDeTelechargements
    ) -> String {
        let numerote = String(
            format: libelles.chapitreNumerote,
            TexteDeChapitre.numero(tache.numeroDeChapitre)
        )

        return TexteDeChapitre.joindre([tache.titreDeLaSerie, numerote])
    }

    /// Sous ligne d une ligne, selon son etat.
    ///
    /// Les trois formes du tableau de la section 4.11 sont servies telles
    /// quelles. Les trois etats que le tableau ne dessine pas, pause, echec et
    /// annulation, disent ce qui s est passe plutot que de reprendre le compte
    /// de pages, qui ne bouge plus.
    public static func sousLigne(
        de tache: TelechargementAffiche,
        libelles: LibellesDeTelechargements
    ) -> String {
        switch tache.etat {
        case .enCours:
            String(format: libelles.pagesFaites, tache.pagesTerminees, tache.nombreDePages)

        case .enAttente:
            libelles.enAttente

        case .termine:
            termine(de: tache, libelles: libelles)

        case .suspendu:
            libelles.enPause

        case .annule:
            libelles.annulee

        case .echoue:
            // Le message vient de la cause reelle, section 4.10. Sans lui la
            // ligne dirait qu il s est passe quelque chose sans dire quoi.
            tache.messageErreur ?? libelles.enAttente
        }
    }

    /// Sous ligne d une tache terminee, `Termine  32 Mo`.
    static func termine(
        de tache: TelechargementAffiche,
        libelles: LibellesDeTelechargements
    ) -> String {
        let octets = tache.octetsTotal ?? tache.octetsRecus

        guard octets > 0 else {
            return libelles.termine
        }

        return String(format: libelles.termineAvecPoids, poids(octets, libelles: libelles))
    }

    /// Poids mis en forme, du plus petit multiple qui tienne en trois chiffres.
    ///
    /// Le calcul vit dans `TexteDePoids`, partage avec les ecrans de stockage de
    /// la section 15 : un chapitre qui pese `32 Mo` dans la file doit peser
    /// `32 Mo` dans l ecran de detail, et deux calculs separes finiraient par ne
    /// pas dire la meme chose.
    public static func poids(_ octets: Int, libelles: LibellesDeTelechargements) -> String {
        TexteDePoids.poids(octets, motifs: libelles.motifsDePoids)
    }

    /// Etiquette lue par VoiceOver, qui porte tout ce que la ligne montre.
    ///
    /// L etat en fait partie et arrive en dernier. La section 7 interdit qu une
    /// information passe par la couleur seule, et l indicateur d etat ne dit
    /// rien d autre que sa couleur et son epaisseur.
    public static func etiquette(
        de tache: TelechargementAffiche,
        libelles: LibellesDeTelechargements
    ) -> String {
        TexteDeChapitre.joindre([
            titre(de: tache, libelles: libelles),
            sousLigne(de: tache, libelles: libelles),
        ])
    }
}
