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


def js(value): JsonValue?
  static_if typeinfo(typename value) == "json::JsonValue?" || typeinfo(typename value) == "json::JsonValue? const"
    return value
  elif typeinfo(is_pointer value)
    return value == null ? null : js(*value)
  elif typeinfo(is_string value)
    return j(value)
  elif typeinfo(is_struct value)
    verify(!typeinfo(is_class value))
    var map: table<string; JsonValue?>
    apply(value) <| $(name: string; field)
      // static_if typeinfo(is_function field)
      //   pass // skip functions
      // elif typeinfo(is_pointer field)
      if typeinfo(is_pointer field)
        if field != null
          map[name] = js(*field)
      else
        map[name] = js(field)
    return j(map)
  elif typeinfo(is_table value)
    var map: table<string; JsonValue?>
    for k, v in keys(value), values(value)
      map[k] = js(v)
    return j(map)
  elif typeinfo(is_iterable value)
    var arr: array<JsonValue?>
    for x in value
      arr |> push <| js(x)
    return j(arr)
  else
    return j(value)


def js(val1; val2): JsonValue?
  return j([{auto[] js(val1); js(val2)}])

def js(val1; val2; val3): JsonValue?
  return j([{auto[] js(val1); js(val2); js(val3)}])

def js(val1; val2; val3; val4): JsonValue?
  return j([{auto[] js(val1); js(val2); js(val3); js(val4)}])

def js(val1; val2; val3; val4; val5): JsonValue?
  return j([{auto[] js(val1); js(val2); js(val3); js(val4); js(val5)}])

def js(val1; val2; val3; val4; val5; val6): JsonValue?
  return j([{auto[] js(val1); js(val2); js(val3); js(val4); js(val5); js(val6)}])

def js(val1; val2; val3; val4; val5; val6; val7): JsonValue?
  return j([{auto[] js(val1); js(val2); js(val3); js(val4); js(val5); js(val6); js(val7)}])

def js(val1; val2; val3; val4; val5; val6; val7; val8): JsonValue?
  return j([{auto[] js(val1); js(val2); js(val3); js(val4); js(val5); js(val6); js(val7); js(val8)}])

def js(val1; val2; val3; val4; val5; val6; val7; val8; val9): JsonValue?
  return j([{auto[] js(val1); js(val2); js(val3); js(val4); js(val5); js(val6); js(val7); js(val8); js(val9)}])

def js(val1; val2; val3; val4; val5; val6; val7; val8; val9; val10): JsonValue?
  return j([{auto[] js(val1); js(val2); js(val3); js(val4); js(val5); js(val6); js(val7); js(val8); js(val9); js(val10)}])
