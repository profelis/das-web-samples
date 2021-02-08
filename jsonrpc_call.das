options indenting = 2
options remove_unused_symbols = false
module jsonrpc_call shared

require strings
require daslib/json public
require daslib/json_boost public


class RpcCall
  def abstract call(var params: JsonValue?; id: double): void

class LambdaRpcCall : RpcCall
  fn: lambda<(var params: JsonValue?; id: double):void>
  def LambdaRpcCall(var f: lambda<(var params: JsonValue?; id: double):void>)
    fn <- f

  def override call(var params: JsonValue?; id:double): void
    invoke(fn, params, id)


class LambdaRpcNotification : RpcCall
  fn: lambda<(var params: JsonValue?):void>
  def LambdaRpcNotification(var f: lambda<(var params: JsonValue?):void>)
    fn <- f

  [unused_argument(id)] def override call(var params: JsonValue?; id:double): void
    invoke(fn, params)


class FunctionRpcCall : RpcCall
  fn: function<(var params: JsonValue?; id: double):void>
  def FunctionRpcCall(var f: function<(var params: JsonValue?; id: double):void>)
    fn <- f

  def override call(var params: JsonValue?; id:double): void
    invoke(fn, params, id)


class FunctionRpcNotification : RpcCall
  fn: function<(var params: JsonValue?):void>
  def FunctionRpcNotification(var f: function<(var params: JsonValue?):void>)
    fn <- f

  [unused_argument(id)] def override call(var params: JsonValue?; id:double): void
    invoke(fn, params)

def get_arg(params: JsonValue?; idx: int): JsonValue?
  if params == null
    return null
  if params is _array
    let arr & = params.value as _array
    return idx <= length(arr) ? arr[idx] : null
  return idx == 0 && !(params is _object) ? params : null

def get_arg_name(params: JsonValue?; name: string): JsonValue?
  if params == null
    return null
  if params is _object
    let obj & = params as _object
    var res : JsonValue? = null
    obj |> find(name) <| $(sub)
      res = *sub
    return res
  return null


def is_null(js: JsonValue?): bool
  return js == null || js is _null

def is_array(js: JsonValue?): bool
  return js != null && js is _array

def is_object(js: JsonValue?): bool
  return js != null && js is _object

def is_bool(js: JsonValue?): bool
  return js != null && js is _bool

def as_bool(js: JsonValue?): bool
  if js == null
    return false
  if js is _bool
    return js as _bool
  if js is _number
    return (js as _number) != 0lf
  if js is _string
    return to_float(js as _string) != 0f
  return js is _object || js is _array

def is_string(js: JsonValue?): bool
  return js != null && js is _string

def as_string(js: JsonValue?): string
  if js == null
    return ""
  if js is _string
    return js as _string
  if js is _bool
    return js as _bool ? "true" : "false"
  if js is _number
    return string(float(js as _number))
  return js is _object ? "[Object object]" : js is _array ? "[Array array]" : ""

def is_number(js: JsonValue?): bool
  return js != null && js is _number

def as_number(js: JsonValue?): double
  return as_double(js)

def as_double(js: JsonValue?): double
  if js == null
    return 0lf
  if js is _number
    return js as _number
  if js is _bool
    return js as _bool ? 1lf : 0lf
  if js is _string
    return double(js as _string)

  return 0lf

def as_float(js: JsonValue?): float
  if js == null
    return 0f
  if js is _number
    return float(js as _number)
  if js is _bool
    return js as _bool ? 1f : 0f
  if js is _string
    return to_float(js as _string)

  return 0f

def as_int(js: JsonValue?): int
  if js == null
    return 0
  if js is _number
    return int(js as _number)
  if js is _bool
    return js as _bool ? 1 : 0
  if js is _string
    return to_int(js as _string)

  return 0
