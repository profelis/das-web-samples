options indenting = 2
options remove_unused_symbols = false
module jsonrpc_rtti shared

require debugapi

require jsonrpc

class ScopedRpcCall : RpcCall
  ctx: rtti::Context?
  def ScopedRpcCall()
    unsafe
      ctx = addr(this_context())

class ScopedFunctionRpcCall : ScopedRpcCall
  fn: function<(var params: RpcParams; id: double):void>
  def ScopedFunctionRpcCall(var f: function<(var params: RpcParams; id: double): void>)
    ScopedRpcCall`ScopedRpcCall(self)
    fn <- f

  def override call(var params: RpcParams; id:double): void
    unsafe
      ctx |> invoke_in_context(fn, params, id)


class ScopedFunctionRpcNotification : ScopedRpcCall
  fn: function<(var params: RpcParams):void>
  def ScopedFunctionRpcNotification(var f: function<(var params: RpcParams): void>)
    ScopedRpcCall`ScopedRpcCall(self)
    fn <- f

  [unused_argument(id)] def override call(var params: RpcParams; id:double): void
    unsafe
      ctx |> invoke_in_context(fn, params)


class ContextFunctionRpcCall : ScopedRpcCall
  fn: function
  def ContextFunctionRpcCall(var f: function; var context: Context)
    unsafe
      ctx = addr(context)
    fn <- f

  def override call(var params: RpcParams; id:double): void
    unsafe
      ctx |> invoke_in_context(fn, params, id)


class ContextFunctionRpcNotification : ScopedRpcCall
  fn: function
  def ContextFunctionRpcNotification(var f: function; var context: Context)
    unsafe
      ctx = addr(context)
    fn <- f

  [unused_argument(id)] def override call(var params: RpcParams; id:double): void
    unsafe
      ctx |> invoke_in_context(fn, params)
