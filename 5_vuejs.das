options indenting = 2

require strings

require debug_server
require jsonrpc_handler
require jsonrpc_args


[export]
def main (fn:string)
  var server = new WebServer()

  var jsonRpc = new JsonRpcHandler()

  var reverseHandler <- @ <| (var params: JsonValue?; id: double)
    let str = params |> get_arg(0) |> as_string()
    jsonRpc->sendResponse(server, JV(reverse(str)), id)

  jsonRpc->addCall("reverse", new LambdaRpcCall(reverseHandler))

  jsonRpc->listen(server)
  jsonRpc->listenUnhandled(server)
  return run_debug_server(server, fn)
