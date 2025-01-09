import client/api.{
  type CanLoad, LoadError, Loaded, Loading, fetch_all_pokemon, fetch_pokemon,
}
import client/shared.{button, header, pokemon_search}
import gleam/dynamic
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre
import lustre/attribute.{class}
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import lustre_http.{type HttpError}
import plinth/browser/document
import plinth/browser/element as browser_element
import shared/pokemon.{type Pokemon}

pub fn main() {
  let assert Ok(json_string) =
    document.query_selector("#model")
    |> result.map(browser_element.inner_text)

  let initial_pokemon =
    json.decode(json_string, dynamic.list(dynamic.string))
    |> result.map(fn(lst) { Loaded(lst) })
    |> result.unwrap(Loading)

  let app = lustre.application(init, update, view)

  let assert Ok(_) = lustre.start(app, "#app", initial_pokemon)

  Nil
}

pub type Model {
  Model(
    current_pokemon: CanLoad(Option(Pokemon), String),
    all_pokemon: CanLoad(List(String), String),
    pokemon_search: String,
  )
}

// Lista predeterminada:
// ["bellsprout", "cherubi", "chimchar", "dialga", "zorua"]

fn init(initial_pokemon) -> #(Model, effect.Effect(Msg)) {
  #(
    Model(
      current_pokemon: Loaded(None),
      all_pokemon: initial_pokemon,
      // ↑↑ all_pokemon: Loading ↑↑
      pokemon_search: "",
    ),
    // fetch_all_pokemon(ApiReturnedAllPokemon),
    effect.none(),
  )
}

pub type Msg {
  UserSelectedPokemon(String)
  UserUpdatedPokemonSearchTerm(String)
  UserClickedSearchButton

  ApiReturnedPokemon(Result(Pokemon, HttpError))
  ApiReturnedAllPokemon(Result(List(String), HttpError))
  // AppRequestedAllPokemon
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([class("flex flex-col gap-12")], [
    header(),
    main_content(model.pokemon_search, model.current_pokemon, model.all_pokemon),
  ])
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserSelectedPokemon(pokemon_name) ->
      handle_user_selected_pokemon(model, pokemon_name)
    UserUpdatedPokemonSearchTerm(search_term) -> #(
      Model(..model, pokemon_search: search_term),
      effect.none(),
    )
    UserClickedSearchButton -> handle_user_clicked_search_button(model)

    ApiReturnedPokemon(Ok(pokemon)) ->
      handle_api_returned_pokemon_ok(model, pokemon)
    ApiReturnedPokemon(Error(err)) -> #(
      Model(
        ..model,
        current_pokemon: LoadError(
          "Error fetching Pokemon: " <> string.inspect(err),
        ),
      ),
      effect.none(),
    )
    ApiReturnedAllPokemon(Ok(pokemon_names)) -> #(
      Model(
        ..model,
        all_pokemon: Loaded(pokemon_names |> list.sort(string.compare)),
      ),
      effect.none(),
    )
    ApiReturnedAllPokemon(Error(err)) -> #(
      Model(
        ..model,
        all_pokemon: LoadError(
          "Error fetching Pokemon: " <> string.inspect(err),
        ),
      ),
      effect.none(),
    )
  }
}

// ========================
// Manejadores de mensajes
// ========================

fn handle_api_returned_pokemon_ok(
  model: Model,
  pokemon: Pokemon,
) -> #(Model, effect.Effect(Msg)) {
  let default_return = #(
    Model(..model, current_pokemon: Loaded(Some(pokemon))),
    effect.none(),
  )

  case model.all_pokemon {
    Loaded(pokemon_names) -> {
      case list.contains(pokemon_names, pokemon.name) {
        // Si el Pokémon no está en la lista, necesitamos
        // recuperar la lista nuevamente
        False -> #(default_return.0, fetch_all_pokemon(ApiReturnedAllPokemon))
        // Si es así, simplemente actualizamos el Pokémon actual como antes.
        True -> default_return
      }
    }
    _ -> default_return
  }
}

fn handle_user_selected_pokemon(
  model: Model,
  pokemon_name: String,
) -> #(Model, effect.Effect(Msg)) {
  let default_return = #(
    Model(..model, current_pokemon: Loading),
    fetch_pokemon(pokemon_name, ApiReturnedPokemon),
  )

  case model.current_pokemon {
    Loaded(Some(current_pokemon)) -> {
      case current_pokemon.name == pokemon_name {
        True -> #(model, effect.none())
        False -> default_return
      }
    }
    _ -> default_return
  }
}

fn handle_user_clicked_search_button(model: Model) {
  let cleaned_pokemon_name =
    model.pokemon_search
    |> string.trim
    |> string.lowercase

  case cleaned_pokemon_name {
    "" -> {
      let model = Model(..model, pokemon_search: "")
      #(model, effect.none())
    }
    cleaned -> {
      let model = Model(..model, pokemon_search: "")
      handle_user_selected_pokemon(model, cleaned)
    }
  }
}

// =================
// Piezas de la UI
// =================

fn main_content(
  pokemon_search_term: String,
  current_pokemon: CanLoad(Option(Pokemon), String),
  all_pokemon: CanLoad(List(String), String),
) -> Element(Msg) {
  html.main([class("px-14")], [
    html.div([class("flex flex-col gap-8 w-full max-w-screen-xl mx-auto")], [
      pokemon_search(
        pokemon_search_term,
        UserUpdatedPokemonSearchTerm,
        UserClickedSearchButton,
      ),
      html.div([class("flex flex-col-reverse sm:flex-row gap-16 w-full")], [
        pokemon_details(current_pokemon, all_pokemon),
        html.div(
          [
            class(
              "flex flex-col gap-4 min-w-[25dvw] lg:min-w-[20dvw] max-h-[28dvh] sm:max-h-[70dvh] overflow-y-auto scroller",
            ),
          ],
          pokemon_list(all_pokemon),
        ),
      ]),
    ]),
  ])
}

fn pokemon_details(
  maybe_pokemon: CanLoad(Option(Pokemon), String),
  all_pokemon: CanLoad(List(String), String),
) -> Element(Msg) {
  let message = case all_pokemon {
    Loaded([]) -> "Search for a Pokémon to view details"
    Loaded(_) -> "Select a Pokémon to view details…"
    LoadError(err) -> "Error loading Pokémon: " <> err
    Loading -> "Loading Pokémon selection…"
  }

  let content = case maybe_pokemon {
    Loaded(None) -> html.p([class("pl-2")], [html.text(message)])
    // None -> html.span([], [html.text("Select a Pokémon to view details…")])
    Loaded(Some(pokemon)) ->
      html.div([class("pl-2 -mt-10 sm:mt-0")], [
        html.h3(
          [class("capitalize text-xl text-sky-500 underline font-semibold")],
          [html.text(pokemon.name)],
        ),
        html.ul([class("list-disc pl-6")], [
          html.li([], [
            html.span([], [
              html.text("HP: "),
              html.span([class("text-lime-400")], [
                html.text(int.to_string(pokemon.base_stats.hp)),
              ]),
            ]),
          ]),
          html.li([], [
            html.span([], [
              html.text("Attack: "),
              html.span([class("text-lime-400")], [
                html.text(int.to_string(pokemon.base_stats.atk)),
              ]),
            ]),
          ]),
          html.li([], [
            html.span([], [
              html.text("Defense: "),
              html.span([class("text-lime-400")], [
                html.text(int.to_string(pokemon.base_stats.def)),
              ]),
            ]),
          ]),
          html.li([], [
            html.span([], [
              html.text("Sp. Atk: "),
              html.span([class("text-lime-400")], [
                html.text(int.to_string(pokemon.base_stats.sp_atk)),
              ]),
            ]),
          ]),
          html.li([], [
            html.span([], [
              html.text("Sp. Def: "),
              html.span([class("text-lime-400")], [
                html.text(int.to_string(pokemon.base_stats.sp_def)),
              ]),
            ]),
          ]),
          html.li([], [
            html.span([], [
              html.text("Speed: "),
              html.span([class("text-lime-400")], [
                html.text(int.to_string(pokemon.base_stats.speed)),
              ]),
            ]),
          ]),
        ]),
      ])

    LoadError(err) -> html.p([], [html.text("Error loading Pokémon: " <> err)])
    Loading -> html.p([], [html.text("Loading Pokémon…")])
  }
  html.p([class("flex-grow")], [content])
}

fn pokemon_list(pokemon: CanLoad(List(String), String)) {
  case pokemon {
    Loaded(pokemon) ->
      list.map(pokemon, fn(p) {
        button(p, UserSelectedPokemon(string.lowercase(p)))
      })
    LoadError(err) -> [
      html.p([], [html.text("Error loading Pokémon: " <> err)]),
    ]
    Loading -> [html.p([], [html.text("Loading Pokémon…")])]
  }
}
// COMANDO DE GENERACIÓN DE LOS FICHEROS ESTÁTICOS EN EL CLIENTE:
// gleam run -m lustre/dev build --minify --outdir=../server/priv
