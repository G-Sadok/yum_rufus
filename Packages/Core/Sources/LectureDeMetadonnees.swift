import Foundation

//
// LectureDeMetadonnees
//
// Application de l ordre de priorite de la section 5.3 : `ComicInfo.xml`
// d abord, `ComicBookInfo` du commentaire d archive en secours.
//
// La regle qui gouverne tout ce fichier tient en une phrase : lire des
// metadonnees ne peut pas echouer. Aucune fonction ne leve, aucune erreur du
// conteneur ne remonte, et le pire resultat possible est nul. Un chapitre
// s ouvre avec ou sans metadonnees ; l inverse ferait dependre la lecture d un
// fichier annexe ecrit par un outil tiers.
//

/// Compose les metadonnees d un document a partir de ses deux sources.
public enum LectureDeMetadonnees {
    /// Lit les metadonnees d un document ouvert.
    ///
    /// - Returns: nul quand ni le fichier `ComicInfo.xml` ni le commentaire de
    ///   l archive n apportent quoi que ce soit d exploitable.
    public static func metadonnees(de document: any DocumentLocal) -> MetadonneesComic? {
        // La lecture rend un optionnel, et le `try?` en ajoute un second. Les
        // deux niveaux se valent ici, une entree illisible et une entree
        // absente donnent le meme resultat, d ou l aplatissement.
        let octets = (try? document.donneesDeMetadonnees()).flatMap(\.self)
        let prioritaires = octets.flatMap(AnalyseurDeComicInfo.analyser)
        let secours = document.commentaireDeConteneur.flatMap(AnalyseurDeComicBookInfo.analyser)

        return composer(prioritaires: prioritaires, secours: secours)
    }

    /// Assemble les deux sources selon leur priorite.
    ///
    /// Le secours ne remplace jamais un champ que le prioritaire a rempli, il
    /// comble les trous. Ecarter le commentaire des qu un `ComicInfo.xml`
    /// existe perdrait le resume des archives ou le fichier XML se limite au
    /// nom de la serie, ce qui est le cas le plus courant.
    public static func composer(
        prioritaires: MetadonneesComic?,
        secours: MetadonneesComic?
    ) -> MetadonneesComic? {
        switch (prioritaires, secours) {
        case let (.some(prioritaires), .some(secours)): prioritaires.complete(par: secours)
        case let (.some(prioritaires), .none): prioritaires
        case let (.none, .some(secours)): secours
        case (.none, .none): nil
        }
    }
}
