options indenting = 2
options remove_unused_symbols = false
module js shared


require daslib/apply
require daslib/json public
require daslib/json_boost public


def j(val: bool): JsonValue?
  return new [[JsonValue value <- [[JsValue _bool = val]]]]

def j(val: double): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = val]]]]

def j(val: string): JsonValue?
  return new [[JsonValue value <- [[JsValue _string = val]]]]

def j(var val: table<string; JsonValue?>): JsonValue?
  return new [[JsonValue value <- [[JsValue _object <- val]]]]

def j(var val: array<JsonValue?>): JsonValue?
  return new [[JsonValue value <- [[JsValue _array <- val]]]]

def j(): JsonValue?
  return new [[JsonValue value <- [[JsValue _null = null]]]]

def j(val: int8): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def j(val: uint8): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def j(val: int16): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def j(val: uint16): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def j(val: int): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def j(val: uint): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def j(val: int64): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def j(val: uint64): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def j(val: float): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]


def js(value: array<auto>): JsonValue?
  var arr: array<JsonValue?>
  for x in value
    arr |> push <| js(x)
  return j(arr)


def js(value: auto[]): JsonValue?
  var arr: array<JsonValue?>
  for x in value
    arr |> push <| js(x)
  return j(arr)


def js(value): JsonValue?
  static_if typeinfo(is_struct value)
    var map: table<string; JsonValue?>
    apply(value) <| $(name:string; field)
      static_if typeinfo(is_pointer field)
        if field != null
          map[name] = js(field)
      else
        map[name] = js(field)
    return j(map)
  elif typeinfo(is_table value)
    var map: table<string; JsonValue?>
    for k, v in keys(value), values(value)
      map[k] = js(v)
    return j(map)
  elif typeinfo(is_pointer value)
    if value == null
      return null
    else
      return js(deref(value))
  else
    return j(value)
