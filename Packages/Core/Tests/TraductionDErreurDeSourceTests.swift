import Core
import Foundation
import Testing

/// Couvre le point de passage unique par lequel toute erreur levee par une
/// source devient une erreur du domaine.
///
/// C est ce qui rend le troisieme critere verifiable de bout en bout : une
/// panne d URLSession ne traverse pas le registre en `NSError` opaque, elle
/// arrive a la vue sous forme de cas nomme, avec son message.
struct TraductionDErreurDeSourceTests {
    private static let source = "Serveur de test"

    // MARK: Traduction

    @Test("Une erreur de transport devient une erreur reseau du domaine")
    func transportTraduit() {
        let traduite = ErreurDeSource.depuis(URLError(.timedOut), source: Self.source)

        #expect(traduite == .reseau(.delaiDepasse, source: Self.source))
    }

    @Test("Une erreur de conteneur garde son message precis")
    func documentTraduit() {
        let origine = ErreurDeDocument.conteneurTronque(chemin: "/tmp/Serie/Chapitre 1.cbz")
        let traduite = ErreurDeSource.depuis(origine, source: Self.source)

        #expect(traduite == .document(origine, source: Self.source))
        #expect(traduite.messageUtilisateur.contains("Chapitre 1.cbz"))
        #expect(traduite.messageUtilisateur.contains("incomplet"))
    }

    @Test("Une erreur deja typee traverse sans etre deguisee")
    func erreurDuDomaineInchangee() {
        let origine = ErreurDeSource.mangaIntrouvable(identifiant: "abc")

        #expect(ErreurDeSource.depuis(origine, source: Self.source) == origine)
    }

    @Test("Une annulation devient une erreur reseau annulee")
    func annulationTraduite() {
        let traduite = ErreurDeSource.depuis(CancellationError(), source: Self.source)

        #expect(traduite == .reseau(.annulee, source: Self.source))
    }

    @Test("Une erreur inconnue est nommee par son type, jamais par sa description")
    func erreurInconnueNommeeParSonType() {
        let traduite = ErreurDeSource.depuis(ErreurQuelconque(), source: Self.source)

        #expect(traduite == .echecInattendu(source: Self.source, raison: "ErreurQuelconque"))
    }

    @Test("Un chemin de fichier ne fuit pas dans le code de journal")
    func journalSansChemin() {
        let origine = ErreurDeDocument.conteneurTronque(chemin: "/Users/quelquun/Manga/Serie.cbz")
        let traduite = ErreurDeSource.depuis(origine, source: Self.source)

        #expect(traduite.codeDeJournal == "source.document")
        #expect(traduite.codeDeJournal.contains("quelquun") == false)
        #expect(traduite.codeDeJournal.contains(Self.source) == false)
    }

    // MARK: Messages

    @Test("Le message d une panne reseau nomme la source et la cause")
    func messageDePanneReseau() {
        let erreur = ErreurDeSource.reseau(.authentificationRefusee, source: Self.source)

        #expect(erreur.messageUtilisateur.contains(Self.source))
        #expect(erreur.messageUtilisateur.contains(ErreurReseau.authentificationRefusee.messageUtilisateur))
    }

    @Test("Le message d un echec inattendu ne montre pas le nom du type interne")
    func messageDEchecInattendu() {
        let erreur = ErreurDeSource.echecInattendu(source: Self.source, raison: "ErreurQuelconque")

        #expect(erreur.messageUtilisateur.contains(Self.source))
        #expect(erreur.messageUtilisateur.contains("ErreurQuelconque") == false)
    }

    @Test("Les trois nouveaux cas portent un message a deux phrases")
    func messagesComplets() {
        let cas: [ErreurDeSource] = [
            .reseau(.horsLigne, source: Self.source),
            .document(.aucunePage(chemin: "a.cbz"), source: Self.source),
            .echecInattendu(source: Self.source, raison: "X"),
        ]

        for erreur in cas {
            #expect(erreur.messageUtilisateur.hasSuffix("."), "\(erreur)")
            #expect(erreur.messageUtilisateur.split(separator: ".").count >= 2, "\(erreur)")
        }
    }

    // MARK: Etat de connexion

    @Test("L etat de connexion suit la panne reseau sous jacente")
    func etatSuitLaPanne() {
        #expect(ErreurDeSource.reseau(.horsLigne, source: Self.source).etatDeConnexion == .injoignable)
        #expect(
            ErreurDeSource.reseau(.authentificationRefusee, source: Self.source).etatDeConnexion
                == .identifiantsInvalides
        )
    }

    @Test("Un dossier perdu rend la source injoignable, pas en erreur")
    func dossierPerduInjoignable() {
        #expect(ErreurDeSource.accesAuDossierPerdu(source: Self.source).etatDeConnexion == .injoignable)
        #expect(ErreurDeSource.sourceInjoignable(source: Self.source).etatDeConnexion == .injoignable)
    }

    @Test("Une capacite manquante n est pas un probleme de connexion")
    func capaciteManquanteNEstPasUneConnexion() {
        let erreur = ErreurDeSource.capaciteIndisponible(capacite: .filtres, source: Self.source)

        #expect(erreur.etatDeConnexion == .erreur)
    }
}
