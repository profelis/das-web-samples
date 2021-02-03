require strings
require server
require jsonrpc_handler
require debugapi
require fio


var 
    server: WebServer?


def start (): WebServer?
    var res: WebServer?
    let success = start_server() <| $()
        res = new WebServer()

        var jsonRpc = new JsonRpcHandler()

        var reverseHandler <- @ <| (var params: RpcParams; id: double)
            let str = params->getArgN(0) |> as_string()
            res |> send_response(reverse(str), id)

        jsonRpc->addCall("reverse", new LambdaRpcCall(reverseHandler))

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
    def override onTick : void
        if server != null
            server->tick()


[export]
def debug_agent ( ctx : Context )
    install_new_debug_agent(new WebDebugAgent())


[export]
def main (fn:string)
    let main_time = stat(fn).mtime
    print("start file {fn} at {main_time}\n")
    fork_debug_agent_context(@@debug_agent)
    while true
        let new_time = stat(fn).mtime
        if new_time != main_time
            break
        sleep(1u)
        tick_debug_agent()
        // print("{server}")
    return true
