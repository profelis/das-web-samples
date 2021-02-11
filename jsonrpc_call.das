options indenting = 2
options remove_unused_symbols = false
module jsonrpc_call shared

require strings
require daslib/json public


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
