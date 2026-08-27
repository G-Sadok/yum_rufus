import Core
import Foundation
import LocalAuthentication

//
// Authentification locale, section 11 du cahier de developpement.
//
// Le document dit `LocalAuthentication`, avec repli sur le code de l appareil.
// Le repli n a pas a etre programme : `deviceOwnerAuthentication` est
// exactement cette politique, biometrie d abord et code ensuite, presentee par
// le systeme lui meme. Programmer un second essai a la main donnerait deux
// feuilles la ou le systeme en montre une.
//
// Le type est un acteur parce que `LAContext` n est pas `Sendable`. Chaque appel
// cree le sien et ne le laisse jamais franchir la frontiere de l acteur : un
// contexte reutilise garderait en cache le resultat de l authentification
// precedente, et l application se rouvrirait sans rien demander.
//

/// Authentification par le systeme, avec repli sur le code de l appareil.
actor AuthentificationParLeSysteme: AuthentificationLocale {
    func moyensDisponibles() async -> Set<MoyenDeDeverrouillage> {
        let contexte = LAContext()
        var moyens: Set<MoyenDeDeverrouillage> = []

        if contexte.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            moyens.insert(.biometrie)
        }

        // La politique du proprietaire couvre le code de l appareil. Elle
        // repond vrai des qu un code existe, avec ou sans capteur.
        if contexte.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
            moyens.insert(.codeDeLAppareil)
        }

        return moyens
    }

    func deverrouiller(raison: String) async throws -> MoyenDeDeverrouillage {
        let moyens = await moyensDisponibles()

        guard let moyen = PolitiqueDeDeverrouillage.moyen(parmi: moyens) else {
            throw ErreurDeVerrouillage.aucunMoyenDisponible
        }

        let contexte = LAContext()

        let reussi: Bool = try await withCheckedThrowingContinuation { suite in
            contexte.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: raison
            ) { accorde, erreur in
                if accorde {
                    suite.resume(returning: true)
                } else {
                    suite.resume(throwing: Self.traduire(erreur))
                }
            }
        }

        guard reussi else {
            throw ErreurDeVerrouillage.echecDeLAuthentification
        }

        return moyen
    }

    /// Traduit l erreur du systeme en erreur du domaine.
    ///
    /// Les trois formes d annulation, celle de l utilisateur, celle de
    /// l application et celle du systeme, se rangent ensemble : aucune n est une
    /// panne, et l ecran n a rien a dire dans ces cas la.
    private static func traduire(_ erreur: (any Error)?) -> ErreurDeVerrouillage {
        guard let code = (erreur as? LAError)?.code else {
            return .echecDeLAuthentification
        }

        switch code {
        case .userCancel, .appCancel, .systemCancel:
            return .annuleParLUtilisateur

        case .passcodeNotSet, .biometryNotAvailable, .biometryNotEnrolled:
            return .aucunMoyenDisponible

        default:
            return .echecDeLAuthentification
        }
    }
}
