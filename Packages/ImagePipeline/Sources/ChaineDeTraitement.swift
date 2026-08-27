import Core

//
// ChaineDeTraitement
//
// La chaine complete de la section 6.3, du fichier decode a la page affichee.
//
// Jusqu ici chaque etape vivait seule : le rognage savait rogner, la division
// savait couper, les filtres savent filtrer, et rien ne disait dans quel ordre
// les enchainer. L ordre est pourtant la seule chose que la section 6.3 impose,
// et c est ce type qui le porte, en un seul endroit.
//
// Deux etapes manquent encore, l amelioration et la colorisation par IA, qui
// appartiennent a l etape 9 de la livraison. Elles ne sont pas oubliees, elles
// sont declarees absentes : `etapesAVenir` les nomme, et `etapesImplementees`
// les exclut. Le jour ou elles arrivent, elles se glissent a leur rang sans que
// rien d autre bouge.
//
// La chaine ne remonte aucune erreur. Chaque etape rend la page telle quelle
// quand elle echoue, et l enchainement herite de cette promesse : il rend
// toujours de quoi afficher.
//

/// La chaine de traitement des images, dans l ordre de la section 6.3.
public struct ChaineDeTraitement: Sendable {
    /// Etape 1.
    public let rognage: RognageAutomatique

    /// Etape 2.
    public let division: DivisionDImageLarge

    /// Etapes 3, et 6 a 10.
    public let filtres: ChaineDeFiltres

    public init(
        rognage: RognageAutomatique = RognageAutomatique(),
        division: DivisionDImageLarge = DivisionDImageLarge(),
        filtres: ChaineDeFiltres = ChaineDeFiltres()
    ) {
        self.rognage = rognage
        self.division = division
        self.filtres = filtres
    }

    /// Chaine construite depuis les reglages des trois etapes reglables.
    public init(
        rognage: ReglagesDeRognage,
        division: ReglagesDeDivision,
        filtres: ReglagesDeFiltres
    ) {
        self.init(
            rognage: RognageAutomatique(reglages: rognage),
            division: DivisionDImageLarge(reglages: division),
            filtres: ChaineDeFiltres(reglages: filtres)
        )
    }

    /// Les dix etapes de la section 6.3, dans l ordre.
    public static let etapes = EtapeDeTraitement.chaine

    /// Les huit etapes que la chaine sait appliquer aujourd hui.
    public static let etapesImplementees: [EtapeDeTraitement] =
        ([.rognageAutomatique, .divisionDesImagesLarges] + ChaineDeFiltres.etapesPrisesEnCharge)
            .dansLOrdreDeLaChaine

    /// Les deux etapes declarees par la section 6.3 et non encore livrees.
    ///
    /// Elles appartiennent a l etape 9 de la livraison. Les nommer ici evite
    /// qu un lecteur du code prenne leur absence pour un oubli.
    public static let etapesAVenir: [EtapeDeTraitement] =
        etapes.filter { etapesImplementees.contains($0) == false }

    /// Pages a afficher pour cette page decodee, dans l ordre de lecture.
    ///
    /// Une planche coupee en deux rend deux pages, toute autre page en rend une.
    /// Chaque page rendue a traverse la chaine entiere, dans l ordre.
    ///
    /// Les filtres passent apres la coupe et non avant. Le cout est le meme,
    /// deux moities font le nombre de pixels de la planche, et le rang de la
    /// section 6.3 est respecte : la division est deuxieme, tous les filtres
    /// viennent apres.
    public func pages(de page: ImageDePage, sens: SensDeLecture) -> [ImageDePage] {
        division
            .pages(de: rognage.rogner(page), sens: sens)
            .map { filtres.appliquer(a: $0) }
    }

    /// Page traitee sans etre coupee, pour les modes qui ne divisent pas.
    public func page(de page: ImageDePage) -> ImageDePage {
        filtres.appliquer(a: rognage.rogner(page))
    }

    /// Etapes que cette chaine appliquerait reellement a une page de cette
    /// taille, dans l ordre de la section 6.3.
    ///
    /// Sert au journal et aux tests. Une etape armee mais sans effet, comme la
    /// division d une page plus haute que large, n y figure pas.
    public func etapesAppliquees(a taille: TailleEnPixels) -> [EtapeDeTraitement] {
        var appliquees: [EtapeDeTraitement] = []

        if rognage.reglages.actif {
            appliquees.append(.rognageAutomatique)
        }

        if division.doitDiviser(taille) {
            appliquees.append(.divisionDesImagesLarges)
        }

        return (appliquees + filtres.etapes).dansLOrdreDeLaChaine
    }
}
