//// Este módulo contiene los tipos y funciones para decodificar y codificar
//// datos de un Pokémon de PokeAPI. La PokeAPI devuelve datos JSON que
//// necesitamos decodificar en nuestros propios tipos, y también necesitamos
//// codificar nuestros tipos en JSON para enviarlos de vuelta al cliente.
////
//// Los tipos y funciones con el prefijo `Api` o `api_` (respectivamente)
//// se utilizan para interactuar con la PokeAPI.
//// Todos los demás tipos son internos a nuestra aplicación.

import gleam/dynamic
import gleam/json.{int, nullable, object, preprocessed_array, string}
import gleam/list
import gleam/option.{type Option}
import gleam/result

/// Información sobre un recurso
pub type ApiResourceInfo {
  // ↓↓ Este es el constructor del tipo. ↓↓
  ApiResourceInfo(name: String, url: String)
}

/// Un decodificador para un objeto ApiResourceInfo
fn api_resource_info_decoder() {
  dynamic.decode2(
    ApiResourceInfo,
    dynamic.field("name", dynamic.string),
    dynamic.field("url", dynamic.string),
  )
}

/// Decodifica la información de un recurso dinámico y extrae su nombre
fn api_resource_info_name_decoder(maybe_api_resource_info: dynamic.Dynamic) {
  let decoder = api_resource_info_decoder()
  case decoder(maybe_api_resource_info) {
    Error(err) -> Error(err)
    Ok(api_resource_info) -> Ok(api_resource_info.name)
  }
}

/// Una única estadística tal como es devuelta por la PokeAPI
pub type ApiStat {
  ApiStat(base_stat: Int, effort: Int, name: String)
}

/// Un decodificador para un objeto ApiStat.
///
/// Extrae el campo stat.name de la respuesta de la API.
fn api_stat_decoder() {
  dynamic.decode3(
    ApiStat,
    dynamic.field("base_stat", dynamic.int),
    dynamic.field("effort", dynamic.int),
    dynamic.field("stat", api_resource_info_name_decoder),
  )
}

/// Busca una `base_stat` en una lista de `stats` (estadísticas)
fn get_base_stat(stats: List(ApiStat), stat: String) -> Result(Int, Nil) {
  case list.find(stats, fn(pokemon_stat) { pokemon_stat.name == stat }) {
    Ok(pokemon_stat) -> Ok(pokemon_stat.base_stat)
    Error(_) -> Error(Nil)
  }
}

/// Las estadísticas de un Pokémon
pub type Stats {
  Stats(hp: Int, atk: Int, def: Int, sp_atk: Int, sp_def: Int, speed: Int)
}

/// Convierte una lista de `ApiStat` en un objeto `Stats`
fn api_stats_to_stats(api_stats: List(ApiStat)) -> Result(Stats, Nil) {
  use hp <- result.try(get_base_stat(api_stats, "hp"))
  use atk <- result.try(get_base_stat(api_stats, "attack"))
  use def <- result.try(get_base_stat(api_stats, "defense"))
  use sp_atk <- result.try(get_base_stat(api_stats, "special-attack"))
  use sp_def <- result.try(get_base_stat(api_stats, "special-defense"))
  use speed <- result.try(get_base_stat(api_stats, "speed"))

  Ok(Stats(hp, atk, def, sp_atk, sp_def, speed))
}

/// Decodifica un objeto `Stats` de la representación de la PokeAPI
/// e.g.(https://pokeapi.co/api/v2/pokemon/1/):
/// ```json
/// [
///   {
///     "base_stat": 45,
///     "effort": 0,
///     "stat": {
///       "name": "hp",
///       "url": "https://pokeapi.co/api/v2/stat/1/"
///     }
///   },
///   ...
/// ]
/// ```
fn api_stats_decoder(maybe_stats: dynamic.Dynamic) {
  let decoder = dynamic.list(api_stat_decoder())
  case decoder(maybe_stats) {
    Error(err) -> Error(err)
    Ok(stats) -> {
      case api_stats_to_stats(stats) {
        Ok(stats) -> Ok(stats)
        // No lo completamos por ahora, pero podríamos
        // proporcionar un mensaje de error más detallado
        Error(_) -> Error([dynamic.DecodeError("", "", [""])])
      }
    }
  }
}

/// Codifica un objeto `Stats` en un objeto JSON
fn encode_stats(stats: Stats) {
  object([
    #("hp", int(stats.hp)),
    #("atk", int(stats.atk)),
    #("def", int(stats.def)),
    #("sp_atk", int(stats.sp_atk)),
    #("sp_def", int(stats.sp_def)),
    #("speed", int(stats.speed)),
  ])
}

/// Información sobre un movimiento devuelto por laPokeAPI
/// como parte del recurso Pokemon
pub type ApiPokemonMove {
  ApiPokemonMove(move: ApiResourceInfo)
}

/// Decodifica un movimiento de Pokémon obtenido desde PokeAPI
fn api_pokemon_api_move_decoder() {
  dynamic.decode1(
    ApiPokemonMove,
    dynamic.field("move", api_resource_info_decoder()),
  )
}

/// Un Pokémon tal como lo devuelve la PokeAPI
pub type ApiPokemon {
  ApiPokemon(
    id: Int,
    name: String,
    base_experience: Int,
    base_stats: Stats,
    moves: List(ApiPokemonMove),
  )
}

/// Decodifica un Pokémon desde la PokeAPI
pub fn api_pokemon_decoder() {
  dynamic.decode5(
    ApiPokemon,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("base_experience", dynamic.int),
    dynamic.field("stats", api_stats_decoder),
    dynamic.field("moves", dynamic.list(api_pokemon_api_move_decoder())),
  )
}

/// El movimiento de un Pokémon
pub type Move {
  Move(
    id: Int,
    name: String,
    accuracy: Option(Int),
    pp: Int,
    priority: Int,
    power: Option(Int),
    type_: String,
    damage_class: String,
  )
}

/// Decodifica un movimiento desde la PokeAPI.
///
/// Extrae type_.name y damage_class.name de la respuesta de la API.
pub fn api_move_decoder() {
  dynamic.decode8(
    Move,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("accuracy", dynamic.optional(dynamic.int)),
    dynamic.field("pp", dynamic.int),
    dynamic.field("priority", dynamic.int),
    dynamic.field("power", dynamic.optional(dynamic.int)),
    dynamic.field("type", api_resource_info_name_decoder),
    dynamic.field("damage_class", api_resource_info_name_decoder),
  )
}

/// Codifica un objeto `Move` en un objeto JSON
fn encode_move(move: Move) {
  object([
    #("id", int(move.id)),
    #("name", string(move.name)),
    #("accuracy", nullable(move.accuracy, int)),
    #("pp", int(move.pp)),
    #("priority", int(move.priority)),
    #("power", nullable(move.power, int)),
    #("type", string(move.type_)),
    #("damage_class", string(move.damage_class)),
  ])
}

/// Un Pokémon con todos los detalles de sus movimientos
pub type Pokemon {
  Pokemon(
    id: Int,
    name: String,
    base_experience: Int,
    base_stats: Stats,
    moves: List(Move),
  )
}

/// Codifica un objeto `Pokemon` en un objeto JSON
pub fn encode_pokemon(pokemon: Pokemon) {
  object([
    #("id", int(pokemon.id)),
    #("name", string(pokemon.name)),
    #("base_experience", int(pokemon.base_experience)),
    #("base_stats", encode_stats(pokemon.base_stats)),
    #("moves", preprocessed_array(list.map(pokemon.moves, encode_move))),
  ])
}

fn stats_decoder() {
  dynamic.decode6(
    Stats,
    dynamic.field("hp", dynamic.int),
    dynamic.field("atk", dynamic.int),
    dynamic.field("def", dynamic.int),
    dynamic.field("sp_atk", dynamic.int),
    dynamic.field("sp_def", dynamic.int),
    dynamic.field("speed", dynamic.int),
  )
}

fn move_decoder() {
  dynamic.decode8(
    Move,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("accuracy", dynamic.optional(dynamic.int)),
    dynamic.field("pp", dynamic.int),
    dynamic.field("priority", dynamic.int),
    dynamic.field("power", dynamic.optional(dynamic.int)),
    dynamic.field("type", dynamic.string),
    dynamic.field("damage_class", dynamic.string),
  )
}

pub fn pokemon_decoder() {
  dynamic.decode5(
    Pokemon,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("base_experience", dynamic.int),
    dynamic.field("base_stats", stats_decoder()),
    dynamic.field("moves", dynamic.list(move_decoder())),
  )
}
