options indenting = 2

require strings

require debug_server
require jsonrpc_handler


[export]
def main (fn:string)
  var server = new WebServer()

  var jsonRpc = new JsonRpcHandler()

  var reverseHandler <- @ <| (var params: RpcParams; id: double)
    let str = params->getArgN(0) |> as_string()
    jsonRpc->send_response(server, JV(reverse(str)), id)

  jsonRpc->addCall("reverse", new LambdaRpcCall(reverseHandler))

  jsonRpc->listen(server)
  jsonRpc->listenUnhandled(server)
  return run_debug_server(server, fn)
