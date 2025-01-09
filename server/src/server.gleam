//// DESCRIPCIÓN: Aplicación de prueba del framework `Wisp` de `Gleam`.
//// Se trata de una API REST sobre la PokeApi (`https://pokeapi.co/api/v2`),
//// que obtiene Pokémons (endpoint `/pokemon/:name`)
//// y sus `movimientos` (`moves`) o ataques (técnica que los Pokémon
//// son capaces de aprender y que usan en los combates
//// con el fin de debilitar a sus oponentes).
//// El otro endpoint de la API (`/battle/:name1/:name2`) recrea una batalla
//// ficticia entre los 2 Pokémons que le pasamos en la ruta y determina
//// un ganador del combate.
//// 
//// NOTA: La API posee un caché asincrónico compartido entre procesos,
//// que actúa como una DB en memoria (similar a `Redis`), que evita múltiples
//// solicitudes a la PokeApi (como aconseja hacer la misma) y que mejora
//// la velocidad de respuesta. Usa el modelo de `Actor` de `Erlang` (BEAM VM)
//// y los `Subjects` de `Gleam`, abstracción que facilita el paso de mensajes
//// entre procesos.

import gleam/erlang/process
import mist
import server/cache
import server/context.{Context}
import server/router
import wisp
import wisp/wisp_mist

const custom_port = 8000

pub fn main() {
  // Configurar el logger Wisp para Erlang
  wisp.configure_logger()

  let secret_key_base = wisp.random_string(64)

  // Crea los cachés y los asigna al contexto.
  let assert Ok(pokemon_cache) = cache.new()
  let assert Ok(move_cache) = cache.new()
  let assert Ok(battle_cache) = cache.new()
  let context = Context(pokemon_cache, move_cache, battle_cache)

  // Crea un controlador utilizando la sintaxis de `captura de función`.
  // Esto es similar a una aplicación parcial en otros lenguajes.
  // https://tour.gleam.run/functions/function-captures/
  // https://gleaming.dev/articles/function-capture-in-gleam/
  let handler = router.handle_request(_, context)

  // Inicia el `battle manager` en segundo plano
  // TODO

  // Inicia el servidor `Mist`
  let assert Ok(_) =
    handler
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(custom_port)
    |> mist.start_http

  process.sleep_forever()
}
// USAR `mist.bind("0.0.0.0")` PARA HACER DEPLOY CON DOCKER:
// https://discord.com/channels/768594524158427167/768594524158427170/1312909882822885438
// Solicitudes con cURL:
// curl -v http://localhost:8000/pokemon/bulbasaur | json_pp
