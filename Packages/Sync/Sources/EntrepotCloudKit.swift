#if canImport(CloudKit)
    import CloudKit
    import Core
    import Foundation

//
    // EntrepotCloudKit
//
    // Le journal de changements, publie dans la base privee de l utilisateur.
//
    // Une zone dediee et non la zone par defaut. La zone par defaut ne sait pas
    // rendre ses changements depuis un jeton : il faudrait relire la base entiere
    // a chaque demarrage, ce qui coute un aller retour proportionnel a la
    // bibliotheque, et non a ce qui a change. Une zone personnalisee donne
    // `recordZoneChanges`, donc un echange proportionnel au nombre de pages
    // tournees depuis la derniere fois.
//
    // L ecriture arbitre avant d ecraser. CloudKit, laisse a lui meme, applique le
    // dernier ecrivain : un appareil qui revient apres trois jours hors ligne
    // ecraserait alors ce qui a ete lu entre temps ailleurs, et la resolution par
    // horodatage ne servirait plus a rien puisque le serveur l aurait deja
    // contournee. La ligne existante est donc relue et comparee par
    // `ResolutionDeConflit` avant tout envoi.
//
    // Les erreurs de CloudKit sont traduites en `ErreurDEntrepot` et jamais
    // remontees telles quelles. Le moteur doit distinguer trois choses et trois
    // seulement : ce qui se retente tel quel, ce qui demande de repartir du debut,
    // et ce qui ne sert a rien de retenter. Un `CKError` brut remonte jusqu au
    // moteur ferait ecrire cette distinction a chaque appelant.
//

    /// Le journal de changements publie dans la base privee iCloud.
    public struct EntrepotCloudKit: EntrepotDeSynchronisation {
        private let base: CKDatabase
        private let zone: CKRecordZone.ID

        /// Nom du type d enregistrement, une ligne de journal.
        static let typeDEnregistrement = "ChangementDeSynchronisation"

        /// Nom de la zone dediee.
        public static let nomDeZone = "JournalDeSynchronisation"

        /// Champs d une ligne, nommes comme dans `ChangementSynchronise`.
        private enum Champ {
            static let charge = "charge"
            static let horodatage = "horodatage"
            static let appareil = "appareil"
            static let supprime = "supprime"
        }

        /// Construit l entrepot sur la base privee du conteneur donne.
        ///
        /// - Parameters:
        ///   - conteneur: conteneur CloudKit de l application.
        ///   - zone: zone dediee, celle du produit par defaut.
        public init(
            conteneur: CKContainer = .default(),
            zone: CKRecordZone.ID = CKRecordZone.ID(zoneName: EntrepotCloudKit.nomDeZone)
        ) {
            base = conteneur.privateCloudDatabase
            self.zone = zone
        }

        // MARK: Envoi

        public func pousser(_ changements: [ChangementSynchronise]) async throws {
            guard changements.isEmpty == false else {
                return
            }

            try await creerLaZoneSiBesoin()

            var aEcrire: [CKRecord] = []

            for changement in changements {
                guard let enregistrement = try await enregistrementARetenir(pour: changement) else {
                    continue
                }

                aEcrire.append(enregistrement)
            }

            guard aEcrire.isEmpty == false else {
                return
            }

            do {
                _ = try await base.modifyRecords(saving: aEcrire, deleting: [], savePolicy: .changedKeys)
            } catch {
                throw Self.traduire(error)
            }
        }

        /// Enregistrement a ecrire pour ce changement, nul quand le distant tient
        /// deja une version qui gagne.
        private func enregistrementARetenir(pour changement: ChangementSynchronise) async throws -> CKRecord? {
            let identifiant = CKRecord.ID(recordName: changement.cle.texte, zoneID: zone)
            let existant = try await enregistrement(identifiant)

            if let existant, let distant = Self.lire(existant) {
                guard ResolutionDeConflit.gagnant(distant, changement).changement == changement else {
                    return nil
                }
            }

            let enregistrement = existant ?? CKRecord(recordType: Self.typeDEnregistrement, recordID: identifiant)

            enregistrement[Champ.charge] = changement.charge as CKRecordValue
            enregistrement[Champ.horodatage] = changement.horodatage as CKRecordValue
            enregistrement[Champ.appareil] = changement.appareil as CKRecordValue
            enregistrement[Champ.supprime] = (changement.supprime ? 1 : 0) as CKRecordValue

            return enregistrement
        }

        /// Enregistrement distant, nul quand il n existe pas encore.
        private func enregistrement(_ identifiant: CKRecord.ID) async throws -> CKRecord? {
            do {
                return try await base.record(for: identifiant)
            } catch let erreur as CKError where erreur.code == .unknownItem {
                return nil
            } catch {
                throw Self.traduire(error)
            }
        }

        /// Cree la zone dediee si elle n existe pas encore.
        ///
        /// L operation est idempotente et cout un aller retour. Elle n est tentee
        /// qu a l envoi : un appareil qui ne fait que recevoir n a pas a creer la
        /// zone, il la trouvera creee par celui qui ecrit.
        private func creerLaZoneSiBesoin() async throws {
            do {
                _ = try await base.modifyRecordZones(saving: [CKRecordZone(zoneID: zone)], deleting: [])
            } catch let erreur as CKError where erreur.code == .serverRecordChanged {
                return
            } catch {
                throw Self.traduire(error)
            }
        }

        // MARK: Reception

        public func tirer(depuis jeton: Data?) async throws -> LotDistant {
            do {
                let resultat = try await base.recordZoneChanges(
                    inZoneWith: zone,
                    since: Self.jeton(depuis: jeton)
                )

                let changements = resultat.modificationResultsByID.values
                    .compactMap { resultat -> ChangementSynchronise? in
                        guard let enregistrement = try? resultat.get().record else {
                            return nil
                        }

                        return Self.lire(enregistrement)
                    }

                return LotDistant(
                    changements: changements,
                    jeton: Self.donnees(depuis: resultat.changeToken),
                    suite: resultat.moreComing
                )
            } catch let erreur as CKError where erreur.code == .changeTokenExpired {
                throw ErreurDEntrepot.jetonPerime
            } catch let erreur as CKError where erreur.code == .zoneNotFound || erreur.code == .userDeletedZone {
                // La zone n existe pas encore : personne n a rien publie. Ce n est
                // pas une panne, c est l etat normal d une premiere installation.
                return LotDistant(changements: [], jeton: nil)
            } catch {
                throw Self.traduire(error)
            }
        }

        // MARK: Traduction

        /// Ligne de journal portee par un enregistrement, nulle quand il vient
        /// d une version que celle ci ne sait pas lire.
        static func lire(_ enregistrement: CKRecord) -> ChangementSynchronise? {
            guard let cle = CleDeChangement.lire(enregistrement.recordID.recordName),
                  let charge = enregistrement[Champ.charge] as? Data,
                  let horodatage = enregistrement[Champ.horodatage] as? Date,
                  let appareil = enregistrement[Champ.appareil] as? String
            else {
                return nil
            }

            let supprime = (enregistrement[Champ.supprime] as? Int) ?? 0

            return ChangementSynchronise(
                cle: cle,
                charge: charge,
                horodatage: horodatage,
                appareil: appareil,
                supprime: supprime != 0
            )
        }

        /// Jeton de serveur relu depuis sa forme archivee.
        private static func jeton(depuis donnees: Data?) -> CKServerChangeToken? {
            guard let donnees else {
                return nil
            }

            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: donnees)
        }

        /// Forme archivee d un jeton de serveur.
        private static func donnees(depuis jeton: CKServerChangeToken?) -> Data? {
            guard let jeton else {
                return nil
            }

            return try? NSKeyedArchiver.archivedData(withRootObject: jeton, requiringSecureCoding: true)
        }

        /// Traduit une erreur du systeme en erreur d entrepot.
        ///
        /// Les codes retenus sont ceux qui changent la conduite du moteur. Tout le
        /// reste devient un refus, qui laisse le journal intact et sera retente au
        /// tic suivant.
        static func traduire(_ erreur: any Error) -> ErreurDEntrepot {
            guard let erreur = erreur as? CKError else {
                return .reseauIndisponible
            }

            switch erreur.code {
            case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited,
                 .zoneBusy:
                return .reseauIndisponible

            case .notAuthenticated, .accountTemporarilyUnavailable, .managedAccountRestricted:
                return .compteIndisponible

            case .changeTokenExpired:
                return .jetonPerime

            case .zoneNotFound, .userDeletedZone:
                return .zoneAbsente

            default:
                return .refuse(code: erreur.errorCode)
            }
        }
    }
#endif
