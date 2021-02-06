options indenting = 2

require daslib/json

require debug_server
require jsonrpc_handler


[export]
def main (fn:string)
  var server = new WebServer()

  var jsonRpc = new JsonRpcHandler()
  var reqUpdateTitle <- @ <| (var params: RpcParams)
    jsonRpc->send_notification(server, "setTitle", JV([{ auto[] JV("hello from das") }]))
  jsonRpc->addNotification("reqUpdateTitle", new LambdaRpcNotification(reqUpdateTitle))

  var sumHandler <- @ <| (var params: RpcParams; id: double)
    let arg1 = params->getArgN(0)
    let arg2 = params->getArgN(1)
    let sum = arg1 |> as_double() + arg2 |> as_double()
    jsonRpc->send_response(server, "{arg1} + {arg2} = {sum}", id)
  jsonRpc->addCall("sum", new LambdaRpcCall(sumHandler))

  jsonRpc->listen(server)
  jsonRpc->listenUnhandled(server)
  return run_debug_server(server, fn)
