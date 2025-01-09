//// Rutas definidas en nuestra aplicación.
////
//// Usamos un único controlador para todas las solicitudes
//// y enrutamos la solicitud según los segmentos de la ruta.
//// Esto nos permite mantener toda la lógica de nuestra aplicación
//// en un solo lugar y agregar nuevas rutas fácilmente.

// import gleam/io

import client.{Model}
import client/api.{Loaded}
import cors_builder as cors
import gleam/http
import gleam/json
import gleam/option.{None}
import gleam/result
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html
import server/cache
import server/context.{type Context}
import server/pokeapi.{get_moves_for_pokemon, get_pokemon}
import shared/pokemon.{Pokemon, encode_pokemon}
import wisp.{type Request, type Response}

/// Configura el middleware para CORS
fn cors() {
  cors.new()
  // "*" o "http://localhost:1234"
  |> cors.allow_origin("*")
  |> cors.allow_method(http.Get)
  |> cors.allow_method(http.Post)
  |> cors.allow_header("Content-Type")
}

/// Middleware que sirve los ficheros estáticos
/// de la carpeta `priv` del servidor.
/// Asimismo realiza `log` de las solcitudes y respuestas
fn static_middleware(req: Request, fun: fn() -> Response) -> Response {
  use <- wisp.log_request(req)

  let assert Ok(priv) = wisp.priv_directory("server")

  wisp.serve_static(req, under: "/static", from: priv, next: fun)
}

/// Enruta la solicitud al controlador apropiado según los segmentos de ruta.
pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- cors.wisp_middleware(req, cors())
  use <- static_middleware(req)

  case wisp.path_segments(req) {
    // Home
    [] -> home(ctx)

    // `/pokemon`
    ["pokemon"] -> get_all_pokemon_handler(ctx)

    // `/pokemon/:name`.
    ["pokemon", name] -> get_pokemon_handler(ctx, name)

    // Cualquier ruta que no coincida.
    _ -> wisp.not_found()
  }
}

fn page_scaffold(content: Element(a), init_json: String) -> Element(a) {
  html.html([attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute("charset", "UTF-8")]),
      html.meta([
        attribute("content", "width=device-width, initial-scale=1.0"),
        attribute.name("viewport"),
      ]),
      html.meta([
        attribute(
          "content",
          "Fullstack demo app built in Gleam with Lustre & Wisp frameworks to show to user the Pokémon stats",
        ),
        attribute.name("description"),
      ]),
      html.meta([attribute("content", "notranslate"), attribute.name("google")]),
      html.link([
        attribute.type_("image/gif"),
        attribute.href("/static/img/bulbasaur.gif"),
        attribute.rel("shortcut icon"),
      ]),
      html.title([], "Pokédex"),
      html.link([
        attribute.href("/static/client.min.css"),
        attribute.rel("stylesheet"),
      ]),
      html.script(
        [attribute.src("/static/client.min.mjs"), attribute.type_("module")],
        "
  ",
      ),
      html.script(
        [attribute.type_("application/json"), attribute.id("model")],
        init_json,
      ),
      html.link([
        attribute.href("https://fonts.googleapis.com"),
        attribute.rel("preconnect"),
      ]),
      html.link([
        attribute("crossorigin", ""),
        attribute.href("https://fonts.gstatic.com"),
        attribute.rel("preconnect"),
      ]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href(
          "https://fonts.googleapis.com/css2?family=Kanit:ital,wght@0,100;0,200;0,300;0,400;0,500;0,600;0,700;0,800;0,900;1,100;1,200;1,300;1,400;1,500;1,600;1,700;1,800;1,900&display=swap",
        ),
      ]),
      html.style(
        [],
        "
    .scroller {
      scrollbar-gutter: stable;
      scrollbar-color: transparent transparent;
      scrollbar-width: thin;
      transition: scrollbar-color 2s ease-in-out;
    }

    .scroller:hover {
      scrollbar-color: #ff62d4 transparent;
    }
  ",
      ),
    ]),
    html.body([], [html.div([attribute.id("app")], [content])]),
  ])
}

fn encode_all_pokemon(all_pokemon: List(String)) -> String {
  json.array(all_pokemon, json.string) |> json.to_string
}

fn home(ctx: Context) -> Response {
  let all_pokemon = cache.get_keys(ctx.pokemon_cache)
  let model =
    Model(
      all_pokemon: Loaded(all_pokemon),
      current_pokemon: Loaded(None),
      pokemon_search: "",
    )
  let content =
    client.view(model)
    |> page_scaffold(encode_all_pokemon(all_pokemon))

  wisp.response(200)
  |> wisp.set_header("Content-Type", "text/html")
  |> wisp.html_body(content |> element.to_document_string_builder())
}

/// Controlador de la ruta /pokemon.
/// Obtiene todos los nombres de Pokémon que se encuentran
/// actualmente en la memoria caché y los devuelve como JSON.
fn get_all_pokemon_handler(ctx: Context) {
  let pokemon = cache.get_keys(ctx.pokemon_cache)
  // Function captures: https://tour.gleam.run/functions/function-captures/
  let encode = json.array(_, json.string)
  pokemon |> encode |> json.to_string_tree |> wisp.json_response(200)
}

/// Obtiene un Pokémon de la PokeAPI.
///
/// También obtendrá los movimientos del Pokémon
/// y almacenará en caché el resultado.
fn fetch_pokemon(ctx: Context, name: String) {
  case cache.get(ctx.pokemon_cache, name) {
    Ok(pokemon) -> Ok(pokemon)
    Error(_) -> {
      // io.println("Making a request to the PokeApi…")
      use pokemon <- result.try(get_pokemon(name))
      use moves <- result.try(get_moves_for_pokemon(pokemon, ctx.move_cache))
      let pokemon_with_moves =
        Pokemon(
          id: pokemon.id,
          name: pokemon.name,
          base_experience: pokemon.base_experience,
          base_stats: pokemon.base_stats,
          moves: moves,
        )
      cache.set(ctx.pokemon_cache, name, pokemon_with_moves)
      Ok(pokemon_with_moves)
    }
  }
}

/// Controlador de la ruta `/pokemon/:name`.
/// Obtiene el Pokémon solicitado, lo codifica como JSON y lo devuelve.
fn get_pokemon_handler(ctx: Context, name: String) -> Response {
  // wisp.ok()
  // |> wisp.json_body(
  //   json.to_string_tree(json.object([#("name", json.string(name))])),
  // )
  case fetch_pokemon(ctx, name) {
    Ok(pokemon) -> {
      encode_pokemon(pokemon)
      |> json.to_string_tree
      |> wisp.json_response(200)
    }
    Error(msg) -> error_response(msg)
  }
}

/// Crea una respuesta de error a partir de un mensaje.
fn error_response(msg: String) -> Response {
  json.object([#("error", json.string(msg))])
  |> json.to_string_tree
  |> wisp.json_response(500)
}
/// Controlador para la ruta `/battle/:name1/:name2`.
/// Obtiene ambos Pokémons, lucha entre ellos y devuelve al ganador.
/// Nota: cualquier función puede prescindir del retorno si
/// se puede inferir el tipo de retorno de la misma.
// `/battle/:name1/:name2`.
// ["battle", name1, name2] -> get_battle_handler(name1, name2)
// fn get_battle_handler(name1: String, name2: String) {
//   wisp.ok()
//   |> wisp.json_body(
//     json.to_string_tree(
//       json.object([
//         #("name1", json.string(name1)),
//         #("name2", json.string(name2)),
//       ]),
//     ),
//   )
// }

// COMANDO DE GENERACIÓN DE LOS FICHEROS ESTÁTICOS EN EL CLIENTE:
// gleam run -m lustre/dev build --minify --outdir=../server/priv

// COMANDOS PARA LA BÚSQUEDA Y SUTITUCIÓN DE LAS RUTAS DE ESTÁTICOS
// DEL CLIENTE EN EL SERVIDOR:
// grep -rlZ "/static/" server/ | xargs -0 sed -i "s|/static/|/static/|"
// grep -rlZ "static/client.min.css" server/ | xargs -0 sed -i "s|static/client.min.css|static/client.min.css|"
// grep -rlZ "static/client.min.mjs" server/ | xargs -0 sed -i "s|static/client.min.mjs|static/client.min.mjs|"

// REFERENCIAS (CORS):
// https://hexdocs.pm/cors_builder/
// The basics for a fullstack SPA in Gleam =>
// https://keii.dev/posts/the-basics-for-a-fullstack-spa-in-gleam
// https://github.com/dinkelspiel/kirakira
