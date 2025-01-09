import lustre/attribute.{alt, class, href, placeholder, src, type_, value}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn header() -> Element(a) {
  html.header([class("p-4 bg-primary")], [
    html.div([class("flex gap-6 items-center")], [
      html.div([], [
        html.a([href("/")], [
          // "/priv/static/img/pikachu.png"
          html.img([
            src("/static/img/pikachu.png"),
            class("w-12"),
            alt("Pikachu Logo"),
          ]),
        ]),
      ]),
      html.h1([class("text-cyan-50 text-2xl font-bold")], [html.text("Pokédex")]),
    ]),
  ])
}

pub fn pokemon_search(
  input_value: String,
  on_input_msg: fn(String) -> a,
  on_click_msg: a,
) -> Element(a) {
  html.div(
    [class("flex items-center px-2 flex-col sm:flex-row gap-2 sm:gap-0")],
    [
      html.input([
        event.on_input(on_input_msg),
        class(
          "input input-primary input-bordered focus:outline focus:outline-offset-[-6px] focus:outline-2 focus:outline-primary bg-slate-800 flex-grow w-full rounded-xl sm:rounded-r-none sm:border-r-0",
        ),
        value(input_value),
        placeholder("Search Pokémon"),
        type_("search"),
      ]),
      html.button(
        [
          class(
            "btn btn-outline btn-primary focus:outline focus:outline-offset-[-6px] focus:outline-2 focus:outline-primary rounded-xl sm:rounded-l-none sm:border-l-0",
          ),
          event.on_click(on_click_msg),
        ],
        [html.text("Search")],
      ),
    ],
  )
}

pub fn button(text: String, on_click_msg: a) -> Element(a) {
  html.button(
    [
      event.on_click(on_click_msg),
      class("btn btn-outline btn-secondary capitalize"),
    ],
    [html.text(text)],
  )
}
