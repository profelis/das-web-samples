require strings
require server
require jsonrpc_handler
require daslib/json
require bmp
require fio
require base64

[export]
def main (fn:string)
    startServer(fn) <| $()
        var server = new WebServer()

        var jsonRpc = new JsonRpcHandler()

        var reverseHandler <- @ <| (var params: RpcParams; id: double)
            let str = params->getArgN(0) |> asString()
            server |> sendResponse(reverse(str), id)

        jsonRpc->addCall("reverse", new LambdaRpcCall(reverseHandler))

        jsonRpc->listen(server)
        jsonRpc->listenUnhandled(server)
        return server
    return true
