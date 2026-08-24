import Core
import Foundation

//
// IndexCentralZip, suite
//
// Reperage de l index central puis lecture de ses entrees. Separe du fichier
// principal pour garder chaque etape lisible : trouver la fin, situer l index,
// puis le decouper sont trois problemes distincts.
//

extension IndexCentralZip {
    /// Lit dans l enregistrement de fin la taille et la position de l index.
    ///
    /// Quand une des valeurs est saturee, le format renvoie vers son extension
    /// ZIP64, qui reprend les memes champs sur soixante quatre bits.
    static func annonceDeLIndex(
        fin: Data,
        queue: Data,
        positionDeFin: UInt64,
        source: some SourceDOctets
    ) throws -> AnnonceDIndex {
        guard let nombreEntrees = LectureBinaire.entier16(fin, a: 10),
              let taille = LectureBinaire.entier32(fin, a: 12),
              let offset = LectureBinaire.entier32(fin, a: 16)
        else {
            throw ErreurDeDocument.conteneurIllisible(chemin: source.nom)
        }

        let sature = UInt32.max
        guard taille == sature || offset == sature || nombreEntrees == UInt16.max else {
            return AnnonceDIndex(
                taille: UInt64(taille),
                offsetAnnonce: UInt64(offset),
                positionDeLEnregistrement: positionDeFin,
                nom: source.nom
            )
        }

        return try annonceZip64(queue: queue, positionDeFin: positionDeFin, source: source)
    }

    /// Lit l enregistrement de fin ZIP64, designe par son localisateur.
    private static func annonceZip64(
        queue: Data,
        positionDeFin: UInt64,
        source: some SourceDOctets
    ) throws -> AnnonceDIndex {
        let positionDuLocalisateur = Int(queue.count) - Int(source.taille - positionDeFin) - tailleLocalisateurZip64

        guard positionDuLocalisateur >= 0,
              LectureBinaire.entier32(queue, a: positionDuLocalisateur) == signatureLocalisateurZip64,
              let position = LectureBinaire.entier64(queue, a: positionDuLocalisateur + 8)
        else {
            throw ErreurDeDocument.conteneurIllisible(chemin: source.nom)
        }

        let enregistrement = try source.lire(a: position, longueur: 56)

        guard LectureBinaire.entier32(enregistrement, a: 0) == signatureFinZip64,
              let taille = LectureBinaire.entier64(enregistrement, a: 40),
              let offset = LectureBinaire.entier64(enregistrement, a: 48)
        else {
            throw ErreurDeDocument.conteneurIllisible(chemin: source.nom)
        }

        return AnnonceDIndex(
            taille: taille,
            offsetAnnonce: offset,
            positionDeLEnregistrement: position,
            nom: source.nom
        )
    }

    /// Situe l index central dans le fichier et mesure l ecart avec l annonce.
    ///
    /// La position annoncee est verifiee par sa signature. Si elle ne repond
    /// pas, la position deduite de la taille de l index est essayee : c est le
    /// cas des archives precedees d octets etrangers.
    static func repereDeLIndex(_ annonce: AnnonceDIndex, source: some SourceDOctets) throws -> RepereDIndex {
        guard annonce.taille <= source.taille, annonce.taille <= annonce.positionDeLEnregistrement else {
            throw ErreurDeDocument.conteneurTronque(chemin: annonce.nom)
        }

        // Un index vide n a pas de signature a verifier, et c est un cas
        // legitime : une archive sans aucune entree reste un ZIP valide.
        guard annonce.taille > 0 else {
            return RepereDIndex(debut: annonce.offsetAnnonce, decalage: 0)
        }

        if try signatureDEntree(a: annonce.offsetAnnonce, source: source) {
            return RepereDIndex(debut: annonce.offsetAnnonce, decalage: 0)
        }

        let deduite = annonce.positionDeLEnregistrement - annonce.taille
        guard try signatureDEntree(a: deduite, source: source) else {
            throw ErreurDeDocument.conteneurIllisible(chemin: annonce.nom)
        }

        return RepereDIndex(debut: deduite, decalage: Int64(bitPattern: deduite &- annonce.offsetAnnonce))
    }

    /// Indique si l index central commence a la position donnee.
    private static func signatureDEntree(a position: UInt64, source: some SourceDOctets) throws -> Bool {
        guard position + 4 <= source.taille else { return false }

        let debut = try source.lire(a: position, longueur: 4)

        return LectureBinaire.entier32(debut, a: 0) == signatureEntree
    }

    /// Decoupe l index central en entrees.
    static func entrees(dans octets: Data, decalage: Int64, source: some SourceDOctets) throws -> [EntreeZip] {
        var resultat: [EntreeZip] = []
        var position = 0

        while position + tailleEnTeteEntree <= octets.count {
            guard LectureBinaire.entier32(octets, a: position) == signatureEntree else {
                throw ErreurDeDocument.conteneurIllisible(chemin: source.nom)
            }

            let (entree, suivante) = try entree(dans: octets, a: position, decalage: decalage, source: source)
            resultat.append(entree)
            position = suivante
        }

        return resultat
    }

    /// Lit une entree de l index central et rend la position de la suivante.
    private static func entree(
        dans octets: Data,
        a position: Int,
        decalage: Int64,
        source: some SourceDOctets
    ) throws -> (EntreeZip, Int) {
        guard let drapeaux = LectureBinaire.entier16(octets, a: position + 8),
              let methode = LectureBinaire.entier16(octets, a: position + 10),
              let crc = LectureBinaire.entier32(octets, a: position + 16),
              let compressee = LectureBinaire.entier32(octets, a: position + 20),
              let decompressee = LectureBinaire.entier32(octets, a: position + 24),
              let longueurNom = LectureBinaire.entier16(octets, a: position + 28),
              let longueurExtra = LectureBinaire.entier16(octets, a: position + 30),
              let longueurCommentaire = LectureBinaire.entier16(octets, a: position + 32),
              let offsetLocal = LectureBinaire.entier32(octets, a: position + 42)
        else {
            throw ErreurDeDocument.conteneurTronque(chemin: source.nom)
        }

        let debutNom = position + tailleEnTeteEntree
        let debutExtra = debutNom + Int(longueurNom)
        let suivante = debutExtra + Int(longueurExtra) + Int(longueurCommentaire)

        guard suivante <= octets.count else {
            throw ErreurDeDocument.conteneurTronque(chemin: source.nom)
        }

        let nom = texte(octets.subdata(in: (octets.startIndex + debutNom)..<(octets.startIndex + debutExtra)))
        let extra = octets.subdata(
            in: (octets.startIndex + debutExtra)..<(octets.startIndex + debutExtra + Int(longueurExtra))
        )
        let tailles = grandesTailles(
            extra: extra,
            annoncees: TaillesDEntree(
                decompressee: UInt64(decompressee),
                compressee: UInt64(compressee),
                offset: UInt64(offsetLocal)
            )
        )
        let offset = try positionCorrigee(tailles.offset, decalage: decalage, source: source)

        return (
            EntreeZip(
                nom: nom,
                drapeaux: drapeaux,
                methode: methode,
                crcAttendu: crc,
                tailleCompressee: tailles.compressee,
                tailleDecompressee: tailles.decompressee,
                offsetEnTeteLocal: offset
            ),
            suivante
        )
    }

    /// Applique a une position annoncee l ecart mesure sur l index central.
    private static func positionCorrigee(
        _ position: UInt64,
        decalage: Int64,
        source: some SourceDOctets
    ) throws -> UInt64 {
        let corrigee = Int64(bitPattern: position) &+ decalage

        guard corrigee >= 0, UInt64(corrigee) < source.taille else {
            throw ErreurDeDocument.conteneurTronque(chemin: source.nom)
        }

        return UInt64(corrigee)
    }

    /// Remplace les tailles saturees par les valeurs du champ additionnel ZIP64.
    ///
    /// Les valeurs de ce champ se suivent sans etiquette, dans un ordre fixe, et
    /// seules celles qui saturent sont presentes. Il faut donc les consommer
    /// dans l ordre en ne prenant que celles qui manquent.
    private static func grandesTailles(extra: Data, annoncees: TaillesDEntree) -> TaillesDEntree {
        guard let champ = champZip64(extra) else { return annoncees }

        var resultat = annoncees
        var position = 0
        let sature = UInt64(UInt32.max)

        func prochaine() -> UInt64? {
            guard let valeur = LectureBinaire.entier64(champ, a: position) else { return nil }
            position += 8
            return valeur
        }

        if resultat.decompressee == sature, let valeur = prochaine() {
            resultat.decompressee = valeur
        }
        if resultat.compressee == sature, let valeur = prochaine() {
            resultat.compressee = valeur
        }
        if resultat.offset == sature, let valeur = prochaine() {
            resultat.offset = valeur
        }

        return resultat
    }

    /// Retrouve le champ additionnel ZIP64 parmi les champs additionnels.
    private static func champZip64(_ extra: Data) -> Data? {
        var position = 0

        while position + 4 <= extra.count {
            guard let identifiant = LectureBinaire.entier16(extra, a: position),
                  let longueur = LectureBinaire.entier16(extra, a: position + 2),
                  position + 4 + Int(longueur) <= extra.count
            else {
                return nil
            }

            let debut = extra.startIndex + position + 4
            if identifiant == 0x0001 {
                return extra.subdata(in: debut..<(debut + Int(longueur)))
            }

            position += 4 + Int(longueur)
        }

        return nil
    }

    /// Decode un nom d entree ou un commentaire.
    ///
    /// Le format n admet que deux encodages : l UTF 8 quand le drapeau 0x0800
    /// est pose, et sinon la page de codes 437 des origines. Le drapeau n est
    /// pas consulte parce qu il ment souvent, et parce que le test est plus sur
    /// que l annonce : une suite d octets valide en UTF 8 l est presque jamais
    /// par accident. La page 437 n existe pas dans Foundation, la latine 1 la
    /// remplace ; elles coincident sous 128, donc sur tous les noms de pages
    /// rencontres, et le decodage ne peut jamais echouer.
    static func texte(_ octets: Data) -> String {
        if let decode = String(data: octets, encoding: .utf8) {
            return decode
        }

        return String(data: octets, encoding: .isoLatin1) ?? ""
    }
}
