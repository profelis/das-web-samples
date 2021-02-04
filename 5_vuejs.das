options indenting = 4

require strings
require server
require jsonrpc_handler


[export]
def main (fn:string)
    run_server(fn) <| $()
        var server = new WebServer()

        var jsonRpc = new JsonRpcHandler()

        var reverseHandler <- @ <| (var params: RpcParams; id: double)
            let str = params->getArgN(0) |> as_string()
            server |> send_response(reverse(str), id)

        jsonRpc->addCall("reverse", new LambdaRpcCall(reverseHandler))

        jsonRpc->listen(server)
        jsonRpc->listenUnhandled(server)
        return server
    return true
