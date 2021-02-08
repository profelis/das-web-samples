options indenting = 2
options remove_unused_symbols = false
module jsonrpc_rtti shared

require debugapi
require rtti
require daslib/json

require jsonrpc

class ScopedRpcCall : RpcCall
  ctx: rtti::Context?


class ContextFunctionRpcCall : ScopedRpcCall
  fn: function<(var params: JsonValue?; id: double): void>
  def ContextFunctionRpcCall(var f: function<(var params: JsonValue?; id: double): void>; var context: Context)
    unsafe
      ctx = addr(context)
    fn <- f

  def override call(var params: JsonValue?; id:double): void
    unsafe
      ctx |> invoke_in_context(fn, params, id)


class ContextFunctionRpcNotification : ScopedRpcCall
  fn: function<(var params: JsonValue?):void>
  def ContextFunctionRpcNotification(var f: function<(var params: JsonValue?):void>; var context: Context)
    unsafe
      ctx = addr(context)
    fn <- f

  [unused_argument(id)] def override call(var params: JsonValue?; id:double): void
    unsafe
      ctx |> invoke_in_context(fn, params)
