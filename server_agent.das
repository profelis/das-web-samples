options indenting = 2
options remove_unused_symbols = false
module server_agent shared

require strings
require debugapi

require daslib/json

require jsonrpc_rtti
require jsonrpc_handler
require server

var
  serverDebugLogs = false
  verbose = false

var
  server: WebServer?
  jsonRpc: JsonRpcHandler?


[private]
def start(): WebServer?
  var res = new WebServer()
  res.debugLogs = serverDebugLogs
  jsonRpc = new JsonRpcHandler()
  jsonRpc->listen(res)
  jsonRpc->listenUnhandled(res)
  let success = start_server(res)
  return success ? res : null


[private]
def stop()
  unsafe
    delete jsonRpc
    delete server


class WebDebugAgent : DapiDebugAgent
  [unused_argument(agent)] def override onInstall ( agent:DebugAgent? ) : void
    server = start()
    if verbose
      print("start server on agent {agent} ctx: {this_context()}\n")

  [unused_argument(agent)] def override onUninstall ( agent:DebugAgent? ) : void
    if server != null
      // server->restart()
      stop()
      if verbose
        print("stopServer on agent {agent} ctx: {this_context()}\n")

  def override onDestroyContext(ctx: Context)
    if verbose
      print("onDestroyContext `{ctx}`\n")
    if server == null
      return
    var toRemoveCalls: array<string>
    for name, call in keys(jsonRpc.calls), values(jsonRpc.calls)
      unsafe
        var scoped = reinterpret<ScopedRpcCall?>(call)
        let currentScope & = *(scoped.ctx)
        if addr(currentScope) == addr(ctx)
          toRemoveCalls |> push(name)

    for it in toRemoveCalls
      if verbose
        print("delete call `{it}`\n")
      jsonRpc.calls |> erase(it)

    var toRemoveNotifications: array<string>
    for name, call in keys(jsonRpc.notifications), values(jsonRpc.notifications)
      unsafe
        var scoped = reinterpret<ScopedRpcCall?>(call)
        let currentScope & = *(scoped.ctx)
        if addr(currentScope) == addr(ctx)
          toRemoveNotifications |> push(name)

    for it in toRemoveNotifications
      if verbose
        print("delete notification `{it}`\n")
      jsonRpc.notifications |> erase(it)

    unsafe
      let localCtx: Context const & = this_context()
      if addr(localCtx) == addr(ctx)
        stop()

  def override onTick() : void
    if server != null
      server->tick()

def verify_in_debug_server()
  unsafe
    var debugAgent = addr(get_debug_agent_context())
    verify(debugAgent != null)
    verify(debugAgent == addr(this_context()))
    verify(server != null)
    verify(jsonRpc != null)
  return true

[private]
def verify_not_in_debug()
  unsafe
    var debugAgent = addr(get_debug_agent_context())
    verify(debugAgent != null)
    verify(debugAgent != addr(this_context()))
  return true

[export]
def _add_call(name:string; var call: ScopedRpcCall?)
  if !verify_in_debug_server()
    return
  if verbose
    print("add call `{name}`\n")
  jsonRpc->addCall(clone_string(name), call)

[export]
def add_call(name:string; var call: ScopedRpcCall?)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_add_call", name, call)

[export]
def _add_call_fn(name:string; var fn: function; var ctx: Context)
  if !verify_in_debug_server()
    return
  if verbose
    print("add call `{name}`\n")
  jsonRpc->addCall(clone_string(name), new ContextFunctionRpcCall(fn, ctx))

[export]
def add_call(name:string; var fn: function<(var params: JsonValue?; id: double): void>; var ctx: Context)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_add_call_fn", name, fn, ctx)

[export]
def add_call(name:string; var fn: function<(var params: JsonValue?; id: double): void>)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_add_call_fn", name, fn, this_context())

[export]
def _add_error_handler(var call: ScopedRpcCall?)
  if !verify_in_debug_server()
    return
  if verbose
    print("add error handler\n")
  jsonRpc->addErrorHandler(call)

[export]
def add_error_handler(var call: ScopedRpcCall?)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_add_error_handler", call)

[export]
def _add_error_handler_fn(var fn: function; var ctx: Context)
  if !verify_in_debug_server()
    return
  if verbose
    print("add error handler\n")
  jsonRpc->addErrorHandler(new ContextFunctionRpcCall(fn, ctx))

[export]
def add_error_handler(var fn: function<(var params: JsonValue?; id: double): void>; var ctx: Context)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_add_error_handler_fn", fn, ctx)

[export]
def add_error_handler(var fn: function<(var params: JsonValue?; id: double): void>)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_add_error_handler_fn", fn, this_context())

[export]
def _add_notification(name:string; var call: ScopedRpcCall?)
  if !verify_in_debug_server()
    return
  if verbose
    print("add notification `{name}`\n")
  jsonRpc->addNotification(clone_string(name), call)

[export]
def add_notification(name:string; var call: ScopedRpcCall?)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("add_notification", name, call)

[export]
def _add_notification_fn(name:string; var fn: function; var ctx: Context)
  if !verify_in_debug_server()
    return
  if verbose
    print("add notification `{name}`\n")
  jsonRpc->addNotification(clone_string(name), new ContextFunctionRpcNotification(fn, ctx))

[export]
def add_notification(name:string; var fn: function<(var params: JsonValue?):void>; var ctx: Context)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_add_notification_fn", name, fn, ctx)

[export]
def add_notification(name:string; var fn: function<(var params: JsonValue?):void>)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_add_notification_fn", name, fn, this_context())

[export]
def _send_response(var data: JsonValue?; id: double)
  if !verify_in_debug_server()
    return
  jsonRpc->sendResponse(server, data, id)

[export]
def send_response(var data: JsonValue?; id: double)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_send_response", data, id)

[export]
def _send_request_raw(method: string; var params: JsonValue?; id: double)
  if !verify_in_debug_server()
    return
  jsonRpc->sendRequestRaw(server, method, params, id)

[export]
def send_request(method: string; var params: JsonValue?; id: double)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_send_request_raw", method, params, id)

[export]
def _send_request(method: string; var params: JsonValue?; var fn: function; var ctx: Context)
  if !verify_in_debug_server()
    return
  jsonRpc->sendRequest(server, method, params, new ContextFunctionRpcCall(fn, ctx))

[export]
def send_request(method: string; var params: JsonValue?; var fn: function<(var params: JsonValue?; id: double): void>; var ctx: Context)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_send_request", method, params, fn, ctx)

[export]
def send_request(method: string; var params: JsonValue?; var fn: function<(var params: JsonValue?; id: double): void>)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_send_request", method, params, fn, this_context())

[export]
def _send_notification(method: string; var params: JsonValue?)
  if !verify_in_debug_server()
    return
  jsonRpc->sendNotification(server, method, params)

[export]
def send_notification(method: string; var params: JsonValue?)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_send_notification", method, params)

[export]
def _send_error(error: string; code: double; id: double)
  if !verify_in_debug_server()
    return
  jsonRpc->sendError(server, error, code, id)

[export]
def send_error(error: string; code: double; id: double)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_send_error", error, code, id)


def has_debug_agent(): bool
  unsafe
    return addr(get_debug_agent_context()) != null


[export,private,unused_argument(ctx)]
def start_debug_agent(ctx: Context)
  install_new_debug_agent(new WebDebugAgent())


[export]
def start_agent(force:bool = false): bool
  if force || !has_debug_agent()
    fork_debug_agent_context(@@start_debug_agent)
  else
    if verbose
      print("debug agent already exist\n")
  return true


[export]
def tick_agent()
  tick_debug_agent()
