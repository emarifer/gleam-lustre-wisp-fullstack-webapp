//// Funciones para interactuar con PokeApi (https://pokeapi.co/).
////
//// Siempre que sea posible, los resultados de estas funciones se analizan en
//// con los tipos definidos en el módulo `app/pokemon`, para facilitar
//// el trabajo con los datos en el resto de la aplicación.

import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/otp/task
import gleam/result
import server/cache.{type Cache}
import shared/pokemon.{
  type ApiPokemon, type Move, api_move_decoder, api_pokemon_decoder,
}

const pokeapi_url = "https://pokeapi.co/api/v2"

/// Hace una `request` (solicitud) a la PokeAPI.
fn make_request(path: String) -> Result(Response(String), String) {
  let assert Ok(req) = request.to(pokeapi_url <> path)

  let resp_result =
    httpc.send(req)
    |> result.replace_error("Failed to make request to PokeAPI: " <> path)

  use resp <- result.try(resp_result)

  case resp.status {
    200 -> Ok(resp)
    _ ->
      Error(
        "Got status " <> int.to_string(resp.status) <> " from PokeAPI: " <> path,
      )
  }
}

/// Obtiene un `Pokemon` por su nombre desde la PokeAPI.
///
/// Nota: esta función no utiliza el caché, ya que devuelve un ApiPokemon,
/// que no tiene todos los datos de movimiento asociados. Almacenamos en caché
/// los movimientos por separado para evitar realizar múltiples solicitudes
/// para el mismo movimiento y luego almacenamos en caché
/// los datos completos del Pokémon más tarde.
pub fn get_pokemon(name: String) -> Result(ApiPokemon, String) {
  use resp <- result.try(make_request("/pokemon/" <> name))

  case json.decode(from: resp.body, using: api_pokemon_decoder()) {
    Ok(pokemon) -> Ok(pokemon)
    Error(_) -> Error("Failed to decode Pokemon")
  }
}

/// Obtiene un movimiento por su nombre desde la PokeAPI.
/// También almacenará en caché el movimiento en el caché proporcionado.
fn get_move(name: String, move_cache: Cache(Move)) -> Result(Move, String) {
  case cache.get(move_cache, name) {
    Ok(move) -> Ok(move)
    Error(_) -> {
      use resp <- result.try(make_request("/move/" <> name))

      case json.decode(from: resp.body, using: api_move_decoder()) {
        Ok(move) -> {
          cache.set(move_cache, name, move)
          Ok(move)
        }
        Error(_) -> Error("Failed to decode Move")
      }
    }
  }
}

/// Obtiene todos los movimientos de un Pokémon.
/// Devuelve el primer error encontrado, si lo hay.
pub fn get_moves_for_pokemon(
  api_pokemon: ApiPokemon,
  move_cache: Cache(Move),
) -> Result(List(Move), String) {
  let results =
    list.map(api_pokemon.moves, fn(move) {
      task.async(fn() { get_move(move.move.name, move_cache) })
    })
    |> list.map(fn(handle) {
      task.try_await(handle, 3000)
      |> result.replace_error("Failed to fetch move")
      |> result.flatten
    })
    |> result.partition

  case results.1 {
    [] -> Ok(results.0)
    [err, ..] -> Error("Error fetching moves: " <> err)
  }
}
