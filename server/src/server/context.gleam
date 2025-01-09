import server/cache.{type Cache}
import shared/pokemon.{type Move, type Pokemon}

/// Un tipo de contexto simple que se puede adjuntar a
/// cada solicitud para proporcionar acceso a los cachés.
pub type Context {
  Context(
    pokemon_cache: Cache(Pokemon),
    move_cache: Cache(Move),
    battle_cache: Cache(Pokemon),
  )
}
