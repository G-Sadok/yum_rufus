//
// Sources
//
// Implementations de `SourceProvider`, le protocole unique de la section 4.1
// du cahier de developpement. Le protocole et les entites qu il fait circuler
// vivent dans Core, pour que la bibliotheque, le lecteur et la couche vue
// parlent aux sources sans jamais dependre de ce paquet.
//
// La premiere implementation est le dossier local, avec son signet de
// securite. Les sources distantes, iCloud Drive, Komga, Kavita, Jellyfin,
// OPDS, SMB, NFS, WebDAV et les extensions declaratives, arrivent ensuite et se
// rangent ici.
//
// Depend de Core, et d Archive pour compter les pages d un chapitre range dans
// un conteneur. Cette seconde dependance evite de dupliquer la lecture d index
// central, et ne cree aucun cycle : Archive ne connait que Core.
//
