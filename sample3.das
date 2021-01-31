require server
require jsonrpc_handler

[export]
def main (fn:string)
    startServer(fn) <| $()
        var server = new WebServer()

        var jsonRpc = new JsonRpcHandler()
        var foobarHandler <- @ <| (var params: RpcParams; id: double)
            jsonRpc->sendResponce(server, "foobar responce ;)", id)
        jsonRpc->addCall("foobar", new LambdaRpcCall(foobarHandler))

        var sumHandler <- @ <| (var params: RpcParams; id: double)
            let arg1 = params->getArgN(0)
            let arg2 = params->getArgN(1)
            let sum = arg1 |> asDouble() + arg2 |> asDouble()
            jsonRpc->sendResponce(server, "{arg1} + {arg2} = {sum}", id)
        jsonRpc->addCall("sum", new LambdaRpcCall(sumHandler))


        jsonRpc->listen(server)
        server->unhandled() <| @(msg: string; args: array<string>)
            return "{msg}: unhandled call. args: {args}\n"
        return server
    return true
