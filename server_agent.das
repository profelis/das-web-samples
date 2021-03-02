options indenting = 2
options remove_unused_symbols = false
module server_agent shared

require strings
require debugapi

require jsonrpc_rtti
require jsonrpc_handler
require server


let initialStrLimit = uint64(2 * 1024 * 1024)

var
  serverDebugLogs = false
  verbose = false
  strLimit = initialStrLimit

var
  server: WebServer?
  jsonRpc: JsonRpcHandler?


def bytes_hr(value : uint64)
  if value > uint64(1024 * 1024)
    return "{float(value) / (1024f * 1024f)}mb ({int(value)})"
  if value > uint64(1024)
    return "{float(value) / 1024f}kb ({int(value)})"
  return "{int(value)} b"


[private]
def start(): bool
  server = new WebServer()
  server.debugLogs = serverDebugLogs
  jsonRpc = new JsonRpcHandler()
  jsonRpc->listen(server)
  jsonRpc->listenUnhandled(server)
  let success = start_server(server)
  if !success
    unsafe
      delete jsonRpc
  return success


[private]
def stop()
  unsafe
    delete jsonRpc
    delete server


class WebDebugAgent : DapiDebugAgent
  [unused_argument(agent)] def override onInstall ( agent:DebugAgent? ) : void
    start()
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

    var alloc = string_heap_bytes_allocated()
    if alloc > strLimit
      // string_heap_report()
      var report = "STRING HEAP COLLECT: {bytes_hr(alloc)} -> "
      unsafe
        string_heap_collect()
      alloc = string_heap_bytes_allocated()
      if verbose
        print("{report}{bytes_hr(alloc)} limit : {bytes_hr(strLimit)}\n")
      if alloc > strLimit
        strLimit *= uint64(2)
        if verbose
          print("UP string heap limit: {bytes_hr(strLimit)}\n")
      elif strLimit > initialStrLimit && alloc < strLimit / uint64(2)
        strLimit = strLimit / uint64(2)
        if verbose
          print("DOWN string heap limit: {bytes_hr(strLimit)}\n")

def not_in_debug_context()
  unsafe
    let debugAgent = addr(get_debug_agent_context())
    if debugAgent != null && debugAgent != addr(this_context())
      return true
  return false

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
  verify(not_in_debug_context())
  return true


[export]
def _add_call_fn(name:string; var fn: function<(var params: JsonValue?; id: uint64): void>; var ctx: Context)
  if !verify_in_debug_server()
    return
  if verbose
    print("add call `{name}`\n")
  jsonRpc->addCall(clone_string(name), new ContextFunctionRpcCall(fn, ctx))

[export]
def add_call(name:string; var fn: function<(var params: JsonValue?; id: uint64): void>; var ctx: Context)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_add_call_fn", name, fn, ctx)

[export]
def add_call(name:string; var fn: function<(var params: JsonValue?; id: uint64): void>)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_add_call_fn", name, fn, this_context())

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
def _add_notification_fn(name:string; var fn: function<(var params: JsonValue?):void>; var ctx: Context)
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
def _add_error_handler_fn(var fn: function<(var params: JsonValue?; id: uint64): void>; var ctx: Context)
  if !verify_in_debug_server()
    return
  if verbose
    print("add error handler\n")
  jsonRpc->addErrorHandler(new ContextFunctionRpcCall(fn, ctx))

[export]
def add_error_handler(var fn: function<(var params: JsonValue?; id: uint64): void>; var ctx: Context)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_add_error_handler_fn", fn, ctx)

[export]
def add_error_handler(var fn: function<(var params: JsonValue?; id: uint64): void>)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_add_error_handler_fn", fn, this_context())

[export]
def _send_response(var data: JsonValue?; id: uint64)
  if !verify_in_debug_server()
    return
  jsonRpc->sendResponseStr(server, write_json(data), id)

[export]
def send_response(var data: JsonValue?; id: uint64)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_send_response", data, id)
    delete data

[export]
def _send_request(method: string; var params: JsonValue?; var fn: function<(var params: JsonValue?; id: uint64): void>; var ctx: Context)
  if !verify_in_debug_server()
    return
  jsonRpc->sendRequestStr(server, clone_string(method), write_json(params), new ContextFunctionRpcCall(fn, ctx))

[export]
def send_request_typed(method: string; var params: JsonValue?; var fn: function<(var params: JsonValue?; id: uint64): void>; var ctx: Context)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_send_request", method, params, fn, ctx)
    delete params

[export]
def send_request_typed(method: string; var params: JsonValue?; var fn: function<(var params: JsonValue?; id: uint64): void>)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_send_request", method, params, fn, this_context())
    delete params

[export]
def _send_notification(method: string; var params: JsonValue?)
  if !verify_in_debug_server()
    return
  jsonRpc->sendNotificationStr(server, clone_string(method), write_json(params))

[export]
def send_notification(method: string; var params: JsonValue?)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_send_notification", method, params)
    delete params

[export]
def _send_error(error: string; code: double; data: string; id: uint64)
  if !verify_in_debug_server()
    return
  jsonRpc->sendError(server, clone_string(error), code, empty(data) ? null : JV(data), id)

[export]
def send_error(error: string; code: double; data: string = ""; id: uint64 = 0ul)
  if !verify_not_in_debug()
    return
  unsafe
    get_debug_agent_context() |> invoke_in_context("_send_error", error, code, data, id)


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
  elif verbose
    print("debug agent already exists\n")
  return true


[export]
def tick_agent()
  tick_debug_agent()
