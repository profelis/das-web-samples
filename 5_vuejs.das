options indenting = 2

require strings

require dasweb/web_server_debug
require dasweb/jsonrpc_handler
require dasweb/jsonrpc_args


[export]
def main ()
  let args <- get_command_line_arguments()
  let fn = args[1]
  var server = new WebServer()

  var jsonRpc = new JsonRpcHandler()

  var reverseHandler <- @ <| (var params: JsonValue?; id: uint64)
    let str = params |> get_arg(0) |> as_string()
    jsonRpc->sendResponse(server, JV(reverse(str)), id)

  jsonRpc->addCall("reverse", new LambdaRpcCall(reverseHandler))

  jsonRpc->listen(server)
  jsonRpc->listenUnhandled(server)
  return run_debug_server(server, fn)
