import Core
import Foundation

//
// Libelles de l ecran Rechercher, sections 5.4, 6.2, 6.4 et 6.5 de
// DESIGN-SPEC.md.
//
// Aucune chaine n est ecrite ici. Ce type transporte celles que l application a
// lues dans son catalogue, et sait laquelle correspond a quel etat.
//

/// Libelles de l ecran Rechercher et de ses rangees.
public struct LibellesDeRecherche: Sendable, Equatable {
    /// Espace reserve du champ de la barre d outils, tableau 6.2.
    public let espaceReserve: String

    /// Etiquette d accessibilite du champ, qui n a pas de libelle visible.
    public let etiquetteDuChamp: String

    /// Etiquette du bouton qui vide le champ.
    public let effacerLaRecherche: String

    /// Compteur d une rangee, `%lld resultats`.
    public let compteurDeResultats: String

    /// Compteur d une rangee dont la source annonce d autres pages.
    ///
    /// Une source paginee ne dit pas combien elle connait de series en tout.
    /// Afficher le nombre de la premiere page comme un total serait un chiffre
    /// faux, et la section 6.4 impose que les nombres cites soient reels.
    public let compteurDeResultatsPartiel: String

    /// Lien de l en tete d une rangee, tableau 6.5.
    public let toutVoir: String

    /// Retour depuis la liste complete d une source vers toutes les rangees.
    public let retourAuxResultats: String

    /// Lien de reprise d une ligne d erreur, tableau 6.5.
    public let reessayer: String

    /// Ligne d une source qui n a pas repondu dans le delai, tableau 6.4.
    ///
    /// Deux valeurs : le nom de la source, puis le delai en secondes.
    public let ligneDelaiDepasse: String

    /// Ligne d une source qui n a pas pu etre jointe du tout.
    public let ligneInjoignable: String

    /// Ligne d une source qui a refuse les identifiants ou l acces.
    public let ligneAccesRefuse: String

    /// Ligne d un echec qu aucune des trois autres formes ne decrit.
    public let ligneEchec: String

    /// Titre affiche quand aucune source ne connait le terme cherche.
    public let aucunResultatTitre: String

    /// Phrase affichee quand aucune source ne connait le terme cherche.
    public let aucunResultatPhrase: String

    /// Titre affiche quand aucune source installee ne sait chercher.
    public let aucuneSourceTitre: String

    /// Phrase affichee quand aucune source installee ne sait chercher.
    public let aucuneSourcePhrase: String

    /// Titre affiche quand toutes les sources interrogees ont echoue.
    public let toutesLesSourcesTitre: String

    /// Phrase affichee quand toutes les sources interrogees ont echoue.
    public let toutesLesSourcesPhrase: String

    public init(
        espaceReserve: String,
        etiquetteDuChamp: String,
        effacerLaRecherche: String,
        compteurDeResultats: String,
        compteurDeResultatsPartiel: String,
        toutVoir: String,
        retourAuxResultats: String,
        reessayer: String,
        ligneDelaiDepasse: String,
        ligneInjoignable: String,
        ligneAccesRefuse: String,
        ligneEchec: String,
        aucunResultatTitre: String,
        aucunResultatPhrase: String,
        aucuneSourceTitre: String,
        aucuneSourcePhrase: String,
        toutesLesSourcesTitre: String,
        toutesLesSourcesPhrase: String
    ) {
        self.espaceReserve = espaceReserve
        self.etiquetteDuChamp = etiquetteDuChamp
        self.effacerLaRecherche = effacerLaRecherche
        self.compteurDeResultats = compteurDeResultats
        self.compteurDeResultatsPartiel = compteurDeResultatsPartiel
        self.toutVoir = toutVoir
        self.retourAuxResultats = retourAuxResultats
        self.reessayer = reessayer
        self.ligneDelaiDepasse = ligneDelaiDepasse
        self.ligneInjoignable = ligneInjoignable
        self.ligneAccesRefuse = ligneAccesRefuse
        self.ligneEchec = ligneEchec
        self.aucunResultatTitre = aucunResultatTitre
        self.aucunResultatPhrase = aucunResultatPhrase
        self.aucuneSourceTitre = aucuneSourceTitre
        self.aucuneSourcePhrase = aucuneSourcePhrase
        self.toutesLesSourcesTitre = toutesLesSourcesTitre
        self.toutesLesSourcesPhrase = toutesLesSourcesPhrase
    }
}

/// Assemblage des textes de l ecran Rechercher.
public enum TexteDeRecherche {
    /// Compteur d une rangee, nul tant que la source n a pas repondu.
    ///
    /// Un compteur pose pendant le chargement afficherait zero resultat pour
    /// une source qui n a encore rien dit.
    public static func compteur(
        de groupe: GroupeDeRecherche,
        libelles: LibellesDeRecherche
    ) -> String? {
        guard let nombre = groupe.nombreDeResultats else {
            return nil
        }

        let motif = groupe.ilResteDesPages
            ? libelles.compteurDeResultatsPartiel
            : libelles.compteurDeResultats

        return String(format: motif, nombre)
    }

    /// Texte de la ligne d erreur qui remplace une rangee, section 5.4.
    ///
    /// La ligne nomme la source, et le delai quand c est lui qui a expire. Une
    /// erreur qui ne peut pas nommer sa cause nomme au moins ce qu elle sait,
    /// comme le demande la fin de la section 6.4.
    public static func ligneDErreur(
        source nom: String,
        erreur: ErreurDeSource,
        delaiEnSecondes: Int,
        libelles: LibellesDeRecherche
    ) -> String {
        switch erreur.causeCourte {
        case .delaiDepasse:
            String(format: libelles.ligneDelaiDepasse, nom, delaiEnSecondes)
        case .injoignable:
            String(format: libelles.ligneInjoignable, nom)
        case .accesRefuse:
            String(format: libelles.ligneAccesRefuse, nom)
        case .echec:
            String(format: libelles.ligneEchec, nom)
        }
    }
}
