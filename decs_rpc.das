module decs_rpc
require jsonrpc_boost
require fio

require daslib/decs

[init,export]
def first_start()
    if !is_in_debug_agent_creation() && !has_web_agent()
        start_agent()



[rpc_call(name="getArhetypes")]
def reverse_handler(str: string; id: uint64)
    var res: array<JsonValue?>
    print("getArhetypes")
    for arch in decsState.allArchetypes
        var comps: table<string; JsonValue?>
        for comp in arch.components
            comps[comp.name] = JV({{ "info" => JV(comp.info) }})
        res |> emplace <| JV({{
            "hash" => JV(arch.hash);
            "size" => JV(arch.size);
            "components" => JV(comps)
        }})
    send_response(JV(res), id)
    delete res


def tick_rpc()
    sleep(10u)
    tick_agent()