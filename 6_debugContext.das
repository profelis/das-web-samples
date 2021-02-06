options indenting = 4

require server_agent
require strings
require jsonrpc_handler
require jsonrpc_rtti
require fio
require debugapi


[export]
def main (fn: string)
    let main_time = stat(fn).mtime
    print("start file {fn} at {main_time} agent:{has_debug_agent()}\n")

    while true
        let new_time = stat(fn).mtime
        if new_time != main_time
            break
        sleep(0u)
        tick_agent()


[init,export]
def binit_handlers()
    if is_in_debug_agent_creation() || has_debug_agent()
        return
    start_agent()
    register_handlers()


def register_handlers()
    add_call("reverse", @@reverse_handler, this_context())


[export]
def reverse_handler(var params: RpcParams; id: double)
    let str = params->getArgN(0) |> as_string()
    send_response(reverse(str), id)
