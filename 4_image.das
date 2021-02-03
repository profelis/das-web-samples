require strings
require server
require jsonrpc_handler
require daslib/json
require bmp
require base64

[export]
def main (fn:string)
    run_server(fn) <| $()
        var server = new WebServer()

        var jsonRpc = new JsonRpcHandler()

        var sumHandler <- @ <| (var params: RpcParams; id: double)
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
                server |> send_response(to_string(base), id)
            delete arr
            delete res

        jsonRpc->addCall("reqImage", new LambdaRpcCall(sumHandler))

        jsonRpc->listen(server)
        jsonRpc->listenUnhandled(server)
        return server
    return true
