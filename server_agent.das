options indenting = 4

require strings
require server
require jsonrpc_handler
require jsonrpc_rtti
require daslib/json
require debugapi


var
    server: WebServer?
    jsonRpc: JsonRpcHandler?


[private]
def start(): WebServer?
    var res = new WebServer()
    jsonRpc = new JsonRpcHandler()
    jsonRpc->listen(res)
    jsonRpc->listenUnhandled(res)
    let success = start_server(res)
    return success ? res : null


class WebDebugAgent : DapiDebugAgent
    def override onInstall ( agent:DebugAgent? ) : void
        server = start()
    def override onUninstall ( agent:DebugAgent? ) : void
        if server != null
            server->restart()
            delete server
    def override onDestroyContext(ctx: Context)
        if server == null
            return
        unsafe
            let localCtx: Context const & = this_context()
            if addr(localCtx) == addr(ctx)
                delete server
                return
        var toRemoveCalls: array<string>
        for name, call in keys(jsonRpc.calls), values(jsonRpc.calls)
            unsafe
                var scoped = reinterpret<ScopedRpcCall?>(call)
                let currentScope & = *(scoped.ctx)
                if addr(currentScope) == addr(ctx)
                    toRemoveCalls |> push(name)

        for it in toRemoveCalls
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
            print("delete notification `{it}`\n")
            jsonRpc.notifications |> erase(it)
    def override onTick() : void
        if server != null
            server->tick()


[export]
def _add_call(name:string; var call: ScopedRpcCall?)
    if jsonRpc == null
        print("[E] add_call: server in not initialized\n")
        return
    print("add call `{name}`\n")
    jsonRpc->addCall(name, call)

[export]
def add_call(name:string; var call: ScopedRpcCall?)
    if !has_debug_agent()
        print("[E] add_call: debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("_add_call", name, call)

[export]
def _add_call_fn(name:string; var fn: function; var ctx: Context)
    if jsonRpc == null
        print("[E] add_call: server in not initialized\n")
        return
    print("add call `{name}`\n")
    jsonRpc->addCall(name, new ContextFunctionRpcCall(fn, ctx))

[export]
def add_call(name:string; var fn: function; var ctx: Context)
    if !has_debug_agent()
        print("[E] add_call: debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("_add_call_fn", name, fn, ctx)

[export]
def _add_notification(name:string; var call: ScopedRpcCall?)
    if jsonRpc == null
        print("[E] add_notification: server in not initialized\n")
        return
    print("add notification `{name}`\n")
    jsonRpc->addNotification(name, call)

[export]
def add_notification(name:string; var call: ScopedRpcCall?)
    if !has_debug_agent()
        print("[E] add_notification: debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("add_notification", name, call)

[export]
def _add_notification_fn(name:string; var fn: function; var ctx: Context)
    if jsonRpc == null
        print("[E] add_notification: server in not initialized\n")
        return
    print("add notification `{name}`\n")
    jsonRpc->addNotification(name, new ContextFunctionRpcNotification(fn, ctx))

[export]
def add_notification(name:string; var fn: function; var ctx: Context)
    if !has_debug_agent()
        print("[E] add_notification: debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("_add_notification_fn", name, fn, ctx)

[export]
def _send_response(msg: string; id: double)
    if server == null
        print("[E] send_response: server in not initialized\n")
        return
    server |> send_response(msg, id)

[export]
def send_response(msg: string; id: double)
    if !has_debug_agent()
        print("[E] send_response: debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("_send_response", msg, id)

[export]
def _send_request(method: string; var params: JsonValue?; id: double)
    if server == null
        print("[E] send_request: server in not initialized\n")
        return
    server |> send_request(method, params, id)

[export]
def send_request(method: string; var params: JsonValue?; id: double)
    if !has_debug_agent()
        print("[E] send_request: debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("_send_request", method, params, id)

[export]
def _send_notification(method: string; var params: JsonValue?)
    if server == null
        print("[E] send_notification: server in not initialized\n")
        return
    server |> send_notification(method, params)

[export]
def send_notification(method: string; var params: JsonValue?)
    if !has_debug_agent()
        print("[E] send_notification: debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("_send_notification", method, params)

[export]
def _send_error(error: string; code: double; id: double)
    if server == null
        print("[E] send_error: server in not initialized\n")
        return
    server |> send_error(error, code, id)

[export]
def send_error(error: string; code: double; id: double)
    if !has_debug_agent()
        print("[E] send_error: debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("_send_error", error, code, id)

def has_debug_agent(): bool
    unsafe
        return addr(get_debug_agent_context()) != null


[export,private]
def start_debug_agent(ctx: Context)
    print("before install {this_context()}\n")
    install_new_debug_agent(new WebDebugAgent())


[export]
def start_agent(force:bool = false): bool
    if force || !has_debug_agent()
        print("fork debug agent\n")
        fork_debug_agent_context(@@start_debug_agent)
        print("fork debug agent after\n")
    else
        print("debug agent already exist\n")
    return true


[export]
def tick_agent()
    tick_debug_agent()
