options indenting = 2
options remove_unused_symbols = false
module jsonrpc_utils shared

require daslib/json

def JV(val: int8): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def JV(val: uint8): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def JV(val: int16): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def JV(val: uint16): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def JV(val: int): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def JV(val: uint): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def JV(val: int64): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def JV(val: uint64): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]

def JV(val: float): JsonValue?
  return new [[JsonValue value <- [[JsValue _number = double(val)]]]]
