//
// ImagePipeline
//
// Decodage sous echantillonne via Image I/O, cache memoire LRU, cache disque,
// traitements. Une page de 3000 par 4500 pese environ 54 Mo une fois decodee,
// la pleine resolution n est chargee que pendant un zoom actif.
//
// Depend de Core uniquement.
//
