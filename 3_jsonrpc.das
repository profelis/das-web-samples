require server
require jsonrpc_handler
require daslib/json

[export]
def main (fn:string)
    runServer(fn) <| $()
        var server = new WebServer()

        var jsonRpc = new JsonRpcHandler()
        var reqUpdateTitle <- @ <| (var params: RpcParams)
            server |> sendNotification("setTitle", JV([{ auto[] JV("hello from das") }]))
        jsonRpc->addNotification("reqUpdateTitle", new LambdaRpcNotification(reqUpdateTitle))

        var sumHandler <- @ <| (var params: RpcParams; id: double)
            let arg1 = params->getArgN(0)
            let arg2 = params->getArgN(1)
            let sum = arg1 |> asDouble() + arg2 |> asDouble()
            server |> sendResponse("{arg1} + {arg2} = {sum}", id)
        jsonRpc->addCall("sum", new LambdaRpcCall(sumHandler))

        jsonRpc->listen(server)
        jsonRpc->listenUnhandled(server)
        return server
    return true
