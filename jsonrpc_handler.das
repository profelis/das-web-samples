options indenting = 4
options remove_unused_symbols = false
module jsonrpc_handler

require strings
require server
require daslib/json
require daslib/json_boost
require jsonrpc public

let
    PARSE_ERROR_CODE = -32700lf
    INVALID_REQUEST_CODE = -32600lf
    METHOD_NOT_FOUND_CODE = -32601lf
    INVALID_PARAMS_CODE = -32602lf
    INTERNAL_ERROR_CODE = -32603lf

    PARSE_ERROR = "Parse error"
    INVALID_REQUEST = "Invalid Request"
    METHOD_NOT_FOUND = "Method not found"
    INVALID_PARAMS = "Invalid params"
    INTERNAL_ERROR = "Internal error"

class JsonRpcMatch : Matcher
    js : JsonValue? = null
    id : double = 0lf
    method: string = ""
    params: JsonValue?

    def override match(str: string): MatchResult
        params = null
        delete js

        if find(str, "\"jsonrpc\"") < 0
            return <- [[MatchResult invalid = null]]

        var s = strip(str)
        if !ends_with(s, "}")
            return <- [[MatchResult invalid = null]]

        var error: string
        js = read_json(str, error)
        if js == null
            return <- [[MatchResult invalid = null]]

        if js is _array
            // TODO: batch request, return [[MatchResult more = null]]
            print("unsuppported batch request")
            return <- [[MatchResult invalid = null]]
        
        if js is _object
            var success = true
            id = 0lf
            (js as _object) |> find_if_exists("id") <| $(ptr)
                if *ptr.value is _number
                    id = *ptr.value as _number
                elif *ptr.value is _string
                    id = double(to_int(*ptr.value as _string))
                else
                    success = false

            method = ""
            (js as _object) |> find_if_exists("method") <| $(ptr)
                if *ptr.value is _string
                    method = *ptr.value as _string
                else
                    success = false

            (js as _object) |> find_if_exists("params") <| $(ptr)
                if (*ptr.value is _array) || (*ptr.value is _object)
                    params = *ptr
                else
                    success = false

            if success
                return <- [[MatchResult args <- [{ string[] "" }] ]] 
        return <- [[MatchResult invalid = null]]


class JsonRpcHandler
    match: JsonRpcMatch <- JsonRpcMatch()
    rpcParams: RpcParams = RpcParams()
    calls: table<string; RpcCall?>
    notifications: table<string; RpcCall?>

    [private] def matchPtr()
        unsafe
            return addr(match)

    def listen(var server: WebServer?): void
        server->on(self->matchPtr()) <| @(msg: string; args: array<string>)
            return self->rpcHandler(msg)

    def listenUnhandled(var server: WebServer?): void
        server->unhandled() <| @(msg: string; args: array<string>)
            var res = get_error("{PARSE_ERROR}: {msg}", PARSE_ERROR_CODE, 0lf)
            let str = write_json(res)
            delete res
            return str

    [unused_argument(msg)] def rpcHandler(msg: string): string
        var found = false
        if match.id == 0lf
            notifications |> find_for_edit_if_exists(match.method) <| $(ptr)
                found = true
                rpcParams->set(match.params)
                (**ptr)->call(rpcParams, 0lf)
        else
            calls |> find_for_edit_if_exists(match.method) <| $(ptr)
                found = true
                rpcParams->set(match.params)
                (**ptr)->call(rpcParams, match.id)
        if found
            return ""

        var err = get_error("{METHOD_NOT_FOUND}: {match.method}: id: {match.id}", METHOD_NOT_FOUND_CODE, match.id)
        let res = write_json(err)
        delete err
        return res

    def addCall(name:string; var call: RpcCall? implicit)
        calls[name] <- call

    def addNotification(name:string; var notification: RpcCall? implicit)
        notifications[name] <- notification

def send_response(var server: WebServer?; msg: string; id: double)
    var res = JV({{ "jsonrpc" => JV("2.0"); "id" => JV(id); "result" => JV(msg) }})
    server->sendStr(write_json(res))
    delete res

def send_request(var server: WebServer?; method: string; params: JsonValue?; id: double)
    var res = JV({{ "jsonrpc" => JV("2.0"); "id" => JV(id); "method" => JV(method); "params" => params }})
    server->sendStr(write_json(res))
    (res as _object) |> erase("params")
    delete res

def send_notification(var server: WebServer?; method: string; params: JsonValue?)
    var res = JV({{ "jsonrpc" => JV("2.0"); "method" => JV(method); "params" => params }})
    server->sendStr(write_json(res))
    (res as _object) |> erase("params")
    delete res

def get_error(error: string; code: double; id: double): JsonValue?
    var res = JV({{ "jsonrpc" => JV("2.0"); "error" => JV({{ "code" => JV(code); "message" => JV(error) }}) }})
    if id != 0lf
        (res.value as _object)["id"] = JV(id)
    return res

def send_error(var server: WebServer?; error: string; code: double; id: double)
    var res = get_error(error, code, id)
    server->sendStr(write_json(res))
    delete res
