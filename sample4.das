require strings
require server
require jsonrpc_handler
require daslib/json
require bmp
require fio
require base64

def fload(file:file; size: int; blk: block<(data: array<uint8>): void>)
    _builtin_load(file, size, blk)

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
                print("file size: {size}\n")
                fload(file, size) <| $(data:array<uint8>)
                    print("content len {length(data)}\n")
                    unsafe
                        let base <- base64(each(data))
                        var str = build_string() <| $(s)
                            for b in base
                                s |> write(to_char(b))
                        // print(str)
                        // print("\n")
                        print("send image {size}\n")
                        jsonRpc->sendResponse(server, str, id)
                    // var str = build_string() <| $(s)
                    //     for i in range(size)
                    //         s |> write(data[i])
                    

                    // print("data: {str}")
                // let data = fread(file)
                // print("data len {length(data)}\n")
                // var base <- base64(data)
                // resize(bytes, int(fstat(file).size))
                // file |> fload(bytes)
                // var str = build_string() <| $(s)
                //     for i in base
                //         s |> write(string(i))
                // print(str)
                // jsonRpc->sendResponse(server, "image data {str}", id)
        jsonRpc->addCall("reqImage", new LambdaRpcCall(sumHandler))

        jsonRpc->listen(server)
        jsonRpc->listenUnhandled(server)
        return server
    return true

