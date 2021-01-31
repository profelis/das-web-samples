require server
require jsonrpc

[export]
def main (fn:string)
    startServer(fn) <| $()
        var server = new WebServer()

        var jsonRpc = new JsonRpcHandler()
        var foobarHandler <- @ <| (id: double)
            jsonRpc->sendResponce(server, "foobar responce ;)", id)
        jsonRpc->addCall("foobar", new NoArgsRpcCall(foobarHandler))

        jsonRpc->listen(server)
        server->unhandled() <| @(msg: string; args: array<string>)
            return "{msg}: unhandled call. args: {args}\n"
        return server
    return true
