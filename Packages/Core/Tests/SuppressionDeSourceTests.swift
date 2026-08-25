import Core
import Foundation
import Testing

/// Couvre le deuxieme critere de la fonctionnalite : la suppression d une
/// source supprime ses identifiants.
///
/// Le trousseau du systeme survit a la desinstallation sur macOS. Une source
/// retiree sans purge y laisse un mot de passe que plus rien ne lit et que plus
/// rien ne peut effacer, ce qui rend ces tests moins anodins qu ils en ont
/// l air.
struct SuppressionDeSourceTests {
    /// Erreur de test, pour eprouver l isolation des echecs.
    struct RefusDeTest: Error {}

    @Test("Supprimer une source efface ses identifiants")
    func suppressionEffaceLesIdentifiants() async {
        let identifiant = SourceID()
        let trousseau = MagasinDIdentifiantsEnMemoire()
        await trousseau.enregistrer(
            .basique(compte: "lecteur", motDePasse: "mot-de-passe-du-serveur"),
            pour: identifiant
        )

        let echecs = await SuppressionDeSource(traces: [trousseau]).supprimer(identifiant)

        #expect(echecs.isEmpty)
        #expect(await trousseau.identifiants(pour: identifiant) == .aucun)
    }

    @Test("La suppression retire la source du registre et du trousseau en un seul appel")
    func suppressionParcourtToutesLesTraces() async {
        let source = SourceDeTest(nom: "Serveur")
        let registre = RegistreDeSources()
        await registre.inscrire(source)

        let trousseau = MagasinDIdentifiantsEnMemoire()
        await trousseau.enregistrer(.cleDApi("cle-api-jellyfin"), pour: source.id)

        let echecs = await SuppressionDeSource(traces: [registre, trousseau]).supprimer(source.id)

        #expect(echecs.isEmpty)
        #expect(await registre.nombreDeSources == 0)
        #expect(await trousseau.sourcesConnues.isEmpty)
    }

    @Test("Les identifiants d une source jamais inscrite au registre sont purges quand meme")
    func purgeMemeSansInscription() async {
        let identifiant = SourceID()
        let registre = RegistreDeSources()
        let trousseau = MagasinDIdentifiantsEnMemoire()
        await trousseau.enregistrer(.cleDApi("cle-orpheline"), pour: identifiant)

        await SuppressionDeSource(traces: [registre, trousseau]).supprimer(identifiant)

        #expect(await trousseau.sourcesConnues.isEmpty)
    }

    @Test("Seules les identifiants de la source supprimee partent")
    func suppressionCiblee() async {
        let supprimee = SourceID()
        let conservee = SourceID()
        let trousseau = MagasinDIdentifiantsEnMemoire()
        await trousseau.enregistrer(.cleDApi("cle-supprimee"), pour: supprimee)
        await trousseau.enregistrer(.cleDApi("cle-conservee"), pour: conservee)

        await SuppressionDeSource(traces: [trousseau]).supprimer(supprimee)

        #expect(await trousseau.identifiants(pour: supprimee) == .aucun)
        #expect(await trousseau.identifiants(pour: conservee) == .cleDApi("cle-conservee"))
    }

    @Test("Un trousseau qui refuse n empeche pas le registre d oublier la source")
    func unEchecNInterromptPasLeParcours() async {
        let source = SourceDeTest(nom: "Serveur")
        let registre = RegistreDeSources()
        await registre.inscrire(source)

        let trousseau = TrousseauQuiRefuse(erreur: RefusDeTest())

        let echecs = await SuppressionDeSource(traces: [registre, trousseau]).supprimer(source.id)

        #expect(await registre.nombreDeSources == 0)
        #expect(echecs.count == 1)
        #expect(echecs.first?.trace == "trousseau")
    }

    @Test("Un echec de suppression est journalisable sans nommer la source")
    func echecJournalisableSansDonneePersonnelle() async {
        let trousseau = TrousseauQuiRefuse(erreur: ErreurDeTrousseau.refusParLeSysteme(code: -25300))

        let echecs = await SuppressionDeSource(traces: [trousseau]).supprimer(SourceID())

        #expect(echecs.first?.codeDeJournal == "suppression.trousseau.trousseau.refus.-25300")
    }

    @Test("Supprimer une source sans identifiants ne leve pas")
    func suppressionIdempotente() async {
        let trousseau = MagasinDIdentifiantsEnMemoire()

        let echecs = await SuppressionDeSource(traces: [trousseau]).supprimer(SourceID())

        #expect(echecs.isEmpty)
    }
}
