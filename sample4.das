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

        var sumHandler <- @ <| (var params: RpcParams; id: double)
            let w = 128
            let h = 124
            var arr: array<float3>
            arr |> resize(w * h)
            var idx = 0
            for y in range(h)
                for x in range(w)
                    arr[idx++] = float3(float(x) / float(w), float(y) / float(h), 0f)
            save_BMP("foo.bmp", w, h, arr)
            fopen("foo.bmp", "rb+") <| $(file)
                let size = int(fstat(file).size)
                fload(file, size) <| $(data:array<uint8>)
                    unsafe
                        let base <- base64(each(data))
                        server |> sendResponse(to_string(base), id)

        jsonRpc->addCall("reqImage", new LambdaRpcCall(sumHandler))

        jsonRpc->listen(server)
        jsonRpc->listenUnhandled(server)
        return server
    return true
