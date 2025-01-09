//// El módulo de `cache` proporciona un almacén de clave-valor simple
//// que se puede utilizar para almacenar valores en la memoria
//// (similar a `Redis` DB).
//// La caché se implementa como un actor con el que se puede interactuar
//// mediante mensajes. La caché se puede utilizar
//// para almacenar cualquier tipo de valor.
////
//// La caché se ejecuta en un proceso independiente en lugar de pasarse como un
//// valor. Esto permite que la caché se comparta
//// entre varios procesos de manera sencilla
//// sin tener que preocuparse por la sincronización y la copia.

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/string

const timeout = 3000

/// Un simple alias de tipo para un almacén de valores.
type Store(value) =
  Dict(String, value)

/// Un alias de tipo para un Gleam subject utilizado para interactuar
/// con el cache actor.
pub type Cache(value) =
  Subject(Message(value))

/// Mensajes que se pueden enviar al cache actor.
pub type Message(value) {
  Set(key: String, value: value)
  Get(reply_with: Subject(Result(value, Nil)), key: String)
  GetKeys(reply_with: Subject(List(String)))
  Shutdown
}

/// Maneja los mensajes enviados al cache actor.
pub fn handle_message(
  message: Message(value),
  store: Store(value),
) -> actor.Next(Message(value), Store(value)) {
  case message {
    Shutdown -> actor.Stop(process.Normal)
    Set(key, value) -> {
      let store = dict.insert(store, key, value)
      actor.continue(store)
    }
    Get(client, key) -> {
      process.send(client, dict.get(store, key))
      actor.continue(store)
    }
    GetKeys(client) -> {
      process.send(client, dict.keys(store))
      actor.continue(store)
    }
  }
}

/// Create a new cache.
pub fn new() -> Result(Subject(Message(value)), actor.StartError) {
  actor.start(dict.new(), handle_message)
}

/// Establecer un valor en la caché.
pub fn set(cache: Cache(value), key: String, value: value) {
  process.send(cache, Set(key, value))
}

/// Obtener un valor de la caché.
pub fn get(cache: Cache(value), key: String) -> Result(value, Nil) {
  actor.call(cache, Get(_, key), timeout)
}

/// Obtener todas las claves de la caché.
pub fn get_keys(cache: Cache(value)) -> List(String) {
  actor.call(cache, GetKeys, timeout)
}

/// Apaga/cierra el proceso de la caché.
pub fn shutdown(cache: Cache(value)) -> Nil {
  process.send(cache, Shutdown)
}

/// Crea una clave compuesta a partir de una lista de claves.
pub fn create_composite_key(keys: List(String)) -> String {
  string.join(keys, ":")
}
