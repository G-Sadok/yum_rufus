//
// CatalogueDeReglages
//
// Toutes les lignes de l ecran Reglages, section 5.5 de DESIGN-SPEC.md.
//
// Le catalogue est la source unique de trois choses : l ordre des sections et
// de leurs lignes, la variante de chaque ligne, et sa valeur par defaut. La
// base ne porte que ce que l utilisateur a change. Une cle absente de la table
// veut dire que la ligne n a jamais ete touchee, et le catalogue tranche.
//
// Ce partage evite le piege du semis a la migration. Une migration ne s execute
// qu une fois : semer les valeurs par defaut laisserait les installations
// existantes sans les lignes ajoutees ensuite, et le code devrait de toute
// facon savoir repondre a une cle absente. Autant qu il le sache une seule
// fois, ici.
//

/// Les lignes de reglage, dans l ordre impose par la section 5.5.
public enum CatalogueDeReglages {
    /// Toutes les lignes, section apres section, ligne apres ligne.
    public static let toutesLesLignes: [LigneDeReglage] =
        lignesDesSectionsUnASix + lignesDesSectionsSeptADouze + lignesDesSectionsTreizeADixSept

    /// Lignes d une section, dans l ordre du tableau.
    public static func lignes(de section: SectionDeReglages) -> [LigneDeReglage] {
        parSection[section] ?? []
    }

    /// Ligne portant cet identifiant, nulle quand le catalogue l ignore.
    ///
    /// Le catalogue couvre tous les cas de `IdentifiantDeReglage`, et la suite
    /// de tests le verifie. L optionnel existe parce que le compilateur ne peut
    /// pas le prouver, pas parce qu un appelant devrait s attendre a un trou.
    public static func ligne(_ identifiant: IdentifiantDeReglage) -> LigneDeReglage? {
        parIdentifiant[identifiant]
    }

    /// Valeur par defaut d une ligne.
    ///
    /// Une ligne inconnue rend `aucune`, qui est aussi la reponse honnete : il
    /// n y a rien a persister pour une ligne qui n existe pas.
    public static func valeurParDefaut(de identifiant: IdentifiantDeReglage) -> ValeurDeReglage {
        ligne(identifiant)?.valeurParDefaut ?? .aucune
    }

    /// Lignes qui ecrivent une valeur en base.
    public static let lignesPersistees: [LigneDeReglage] =
        toutesLesLignes.filter(\.estPersistee)

    /// Valeurs par defaut des seules lignes persistees.
    public static let valeursParDefaut: [IdentifiantDeReglage: ValeurDeReglage] =
        Dictionary(
            lignesPersistees.map { ($0.id, $0.valeurParDefaut) },
            uniquingKeysWith: { premiere, _ in premiere }
        )

    private static let parSection: [SectionDeReglages: [LigneDeReglage]] =
        Dictionary(grouping: toutesLesLignes, by: \.section)

    private static let parIdentifiant: [IdentifiantDeReglage: LigneDeReglage] =
        Dictionary(
            toutesLesLignes.map { ($0.id, $0) },
            uniquingKeysWith: { premiere, _ in premiere }
        )
}

// MARK: Fabriques de lignes

extension LigneDeReglage {
    /// Ligne a interrupteur, variante 1 de la section 4.1.
    static func interrupteur(
        _ identifiant: IdentifiantDeReglage,
        _ section: SectionDeReglages,
        actifParDefaut: Bool,
        premium: FormeDeLignePremium? = nil
    ) -> LigneDeReglage {
        LigneDeReglage(
            id: identifiant,
            section: section,
            variante: .interrupteur,
            premium: premium,
            valeurParDefaut: .booleen(actifParDefaut)
        )
    }

    /// Ligne a valeur et menu, variante 2 de la section 4.1.
    static func menu<Choix: ChoixDeReglage>(
        _ identifiant: IdentifiantDeReglage,
        _ section: SectionDeReglages,
        _ choix: Choix.Type,
        premium: FormeDeLignePremium? = nil
    ) -> LigneDeReglage {
        LigneDeReglage(
            id: identifiant,
            section: section,
            variante: .valeurEtMenu,
            premium: premium,
            valeurParDefaut: .choix(Choix.parDefaut.rawValue),
            choix: Choix.valeursPersistees
        )
    }

    /// Ligne a valeur et menu dont les choix ne viennent pas d un
    /// `ChoixDeReglage`, comme le tri de la bibliotheque ou le sens de lecture.
    static func menu(
        _ identifiant: IdentifiantDeReglage,
        _ section: SectionDeReglages,
        choix: [String],
        defaut: String
    ) -> LigneDeReglage {
        LigneDeReglage(
            id: identifiant,
            section: section,
            variante: .valeurEtMenu,
            valeurParDefaut: .choix(defaut),
            choix: choix
        )
    }

    /// Ligne de navigation, variante 3 de la section 4.1.
    static func navigation(
        _ identifiant: IdentifiantDeReglage,
        _ section: SectionDeReglages,
        premium: FormeDeLignePremium? = nil
    ) -> LigneDeReglage {
        LigneDeReglage(id: identifiant, section: section, variante: .navigation, premium: premium)
    }

    /// Ligne a curseur, variante 4 de la section 4.1.
    static func curseur(
        _ identifiant: IdentifiantDeReglage,
        _ section: SectionDeReglages,
        defaut: Double,
        bornes: BornesDeReglage
    ) -> LigneDeReglage {
        LigneDeReglage(
            id: identifiant,
            section: section,
            variante: .curseur,
            valeurParDefaut: .curseur(defaut),
            bornes: bornes
        )
    }

    /// Ligne a compteur, variante 5 de la section 4.1.
    static func compteur(
        _ identifiant: IdentifiantDeReglage,
        _ section: SectionDeReglages,
        defaut: Int,
        bornes: BornesDeReglage
    ) -> LigneDeReglage {
        LigneDeReglage(
            id: identifiant,
            section: section,
            variante: .compteur,
            valeurParDefaut: .compteur(defaut),
            bornes: bornes
        )
    }

    /// Ligne qui montre une valeur sans permettre de la changer.
    ///
    /// La valeur affichee est calculee par l ecran, jamais persistee : la
    /// version de l application et la date du dernier envoi iCloud ne sont pas
    /// des choix de l utilisateur.
    static func valeurEnLectureSeule(
        _ identifiant: IdentifiantDeReglage,
        _ section: SectionDeReglages
    ) -> LigneDeReglage {
        LigneDeReglage(id: identifiant, section: section, variante: .valeurEtMenu)
    }
}
