module decs_rpc
require dasweb/jsonrpc_boost
require fio
require math

require daslib/decs

[init,export]
def first_start()
    if is_in_debug_agent_creation() || has_web_agent() || is_compiling_macros()
        return
    if this_context().category != context_category_flags debugger_attached && uint(this_context().category) != 0u
        return
    start_agent()


[rpc_call(name="getArchetypes")]
def get_archetypes_rpc(str: string; id: uint64)
    var res: array<JsonValue?>
    for arch in decsState.allArchetypes
        var comps: array<JsonValue?>
        for comp in arch.components
            comps |> emplace <| JV({{ "name" => JV(comp.name); "info" => JV(comp.info) }})
        res |> emplace <| JV({{
            "hash" => JV(arch.hash);
            "size" => JV(arch.size);
            "components" => JV(comps)
        }})
    send_response(JV(res), id)
    delete res


[rpc_call(name="getEntities")]
def get_entities_rpc(str: string; id: uint64)
    var res: array<JsonValue?>
    for arch in decsState.allArchetypes
        for idx in range(arch.size)
            var comps: array<JsonValue?>
            var ent <- {{ "idx" => JV(idx); "archetype" => JV(arch.hash) }}
            for comp in arch.components
                if comp.name == "eid"
                    unsafe
                        let eid = *(reinterpret<EntityId?> addr(comp.data[idx*comp.stride]))
                        ent["eid"] = JV(eid.id)
                        ent["eid_gen"] = JV(eid.generation)

                elif comp.info.dumper != null
                    let dump = invoke(comp.info.dumper, unsafe(addr(comp.data[idx*comp.stride])))
                    comps |> emplace <| JV({{ "name" => JV(comp.name); "value" => JV(dump) }})

                else
                    comps |> emplace <| JV({{ "name" => JV(comp.name); "value" => JV("{comp.info.basicType} {comp.data[idx*comp.stride]}") }})

            ent["data"] = JV(comps)
            res |> emplace <| JV(ent)
    send_response(JV(res), id)
    delete res


[rpc_call(name="getQueries")]
def get_queries_rpc(str: string; id: uint64)
    var res: array<JsonValue?>
    for q in decsState.ecsQueries
        var req: array<JsonValue?>
        var reqn: array<JsonValue?>
        var archs: array<JsonValue?>
        for r in q.req
            req |> emplace(JV(r))
        for r in q.reqn
            reqn |> emplace(JV(r))
        for arch in q.archetypes
            archs |> emplace(JV(decsState.allArchetypes[arch].hash))
        res |> emplace <| JV({{
            "hash" => JV(q.hash);
            "req" => JV(req);
            "reqn" => JV(reqn);
            "archetypes" => JV(archs);
            "file" => JV(q.at.file);
            "line" => JV(q.at.line)
        }})
    send_response(JV(res), id)
    delete res


def tick_rpc()
    tick_agent()