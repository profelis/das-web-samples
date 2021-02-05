options indenting = 4

require strings
require server
require jsonrpc_handler
require jsonrpc_rtti
require daslib/json
require debugapi
require fio


var 
    server: WebServer?
    jsonRpc: JsonRpcHandler?


[private]
def start (): WebServer?
    var res: WebServer?
    let success = start_server() <| $()
        res = new WebServer()
        jsonRpc = new JsonRpcHandler()
        jsonRpc->listen(res)
        jsonRpc->listenUnhandled(res)
        return res
    return success ? res : null
        

class WebDebugAgent : DapiDebugAgent
    def override onInstall ( agent:DebugAgent? ) : void
        print("start new server\n")
        server = start()
    def override onUninstall ( agent:DebugAgent? ) : void
        if server != null
            print("destroy previous server\n")
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
        print("[error] server in not initialized\n")
        return
    print("add call `{name}`\n")
    jsonRpc->addCall(name, call)

[export]
def add_call(name:string; var call: ScopedRpcCall?)
    if !has_debug_agent()
        print("[error] debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("_add_call", name, call)


[export]
def _add_notification(name:string; var call: ScopedRpcCall?)
    if jsonRpc == null
        print("[error] server in not initialized\n")
        return
    print("add notification `{name}`\n")
    jsonRpc->addNotification(name, call)

[export]
def add_notification(name:string; var call: ScopedRpcCall?)
    if !has_debug_agent()
        print("[error] debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("add_notification", name, call)

[export]
def _send_response(msg: string; id: double)
    if server == null
        print("[error] server in not initialized\n")
        return
    server |> send_response(msg, id)

[export]
def send_response(msg: string; id: double)
    if !has_debug_agent()
        print("[error] debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("_send_response", msg, id)

[export]
def _send_request(method: string; var params: JsonValue?; id: double)
    if server == null
        print("[error] server in not initialized\n")
        return
    server |> send_request(method, params, id)

[export]
def send_request(method: string; var params: JsonValue?; id: double)
    if !has_debug_agent()
        print("[error] debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("_send_request", method, params, id)

[export]
def _send_notification(method: string; var params: JsonValue?)
    if server == null
        print("[error] server in not initialized\n")
        return
    server |> send_notification(method, params)

[export]
def send_notification(method: string; var params: JsonValue?)
    if !has_debug_agent()
        print("[error] debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("_send_notification", method, params)

[export]
def _send_error(error: string; code: double; id: double)
    if server == null
        print("[error] server in not initialized\n")
        return
    server |> send_error(error, code, id)

[export]
def send_error(error: string; code: double; id: double)
    if !has_debug_agent()
        print("[error] debug agent in not initialized\n")
        return
    unsafe
        get_debug_agent_context() |> invoke_in_context("_send_error", error, code, id)

def has_debug_agent(): bool
    unsafe
        return addr(get_debug_agent_context()) != null


[export,private]
def start_debug_agent(ctx: Context)
    install_new_debug_agent(new WebDebugAgent())

[export]
def start_agent()
    if !has_debug_agent()
        print("fork debug agent\n")
        fork_debug_agent_context(@@start_debug_agent)
    else
        print("debug agent already exist\n")
    // fork_debug_agent_context(@@start_debug_agent)

[export]
def tick_agent()
    tick_debug_agent()