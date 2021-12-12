options indenting = 2

require strings

require dasweb/server_debug
require dasweb/jsonrpc_handler
require bmp
require base64


[export]
def main ()
  let args <- get_command_line_arguments()
  let fn = args[1]
  var server = new WebServer()

  var jsonRpc = new JsonRpcHandler()

  var sumHandler <- @ <| (var params: JsonValue?; id: uint64)
    let w = 128
    let h = 124
    var arr: array<float3>
    arr |> resize(w * h)
    var idx = 0
    for y in range(h)
      for x in range(w)
        arr[idx++] = float3(float(x) / float(w), float(y) / float(h), 0f)
    var res: array<uint8>
    bmp::write_array(res, w, h, arr)
    unsafe
      let base <- base64(each(res))
      jsonRpc->sendResponse(server, JV(to_string(base)), id)
    delete arr
    delete res

  jsonRpc->addCall("reqImage", new LambdaRpcCall(sumHandler))

  jsonRpc->listen(server)
  jsonRpc->listenUnhandled(server)
  return run_debug_server(server, fn)
