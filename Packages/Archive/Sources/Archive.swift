//
// Archive
//
// Lecture des conteneurs de pages : ZIP, CBZ, TAR et CBT ici, RAR, RAR5, 7z et
// LZH plus tard par un pont vers libarchive.
//
// Le ZIP est traite sans dependance externe. Son index central suffit a offrir
// l acces aleatoire exige par la section 5.3, la seule methode de compression
// a connaitre est le deflate, que le cadre Compression du systeme decode, et
// tout tient en quelques centaines de lignes. Faire entrer libarchive pour cela
// couterait une dependance native, une compilation croisee et une surface
// d attaque, pour un format que l on sait lire.
//
// Le TAR suit, pour la raison inverse : il ne compresse rien, mais il ne porte
// aucun index. La section 5.3 impose donc de le balayer une fois et de garder
// l index sur disque, ce que font `IndexTar` et `CacheDIndexDArchive`.
//
// L extraction ne decompresse jamais plus que l entree demandee, et ne charge
// jamais l archive entiere en memoire : le fichier est projete en memoire, le
// noyau ne remonte que les pages touchees.
//
// Depend de Core uniquement.
//
