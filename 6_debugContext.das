options indenting = 4

require server_agent
require strings
require jsonrpc_handler
require jsonrpc_rtti
require debugapi
require fio


[export]
def main (fn: string)
    let main_time = stat(fn).mtime
    print("start file {fn} at {main_time} agent:{has_debug_agent()}\n")
    start_agent()

    register_handlers()

    while true
        let new_time = stat(fn).mtime
        if new_time != main_time
            break
        sleep(1u)
        tick_debug_agent()


def register_handlers()
    add_call("reverse", new ScopedFunctionRpcCall(@@reverse_handler))


[export]
def reverse_handler(var params: RpcParams; id: double)
    let str = params->getArgN(0) |> as_string()
    send_response(reverse(str), id)
