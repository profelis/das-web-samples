require strings
require server
require daslib/json
require daslib/json_boost
require jsonrpc public

let
    PARSE_ERROR_CODE = double(-32700)
    INVALID_REQUEST_CODE = double(-32600)
    METHOD_NOT_FOUND_CODE = double(-32601)
    INVALID_PARAMS_CODE = double(-32602)
    INTERNAL_ERROR_CODE = double(-32603)

    PARSE_ERROR = "Parse error"
    INVALID_REQUEST = "Invalid Request"
    METHOD_NOT_FOUND = "Method not found"
    INVALID_PARAMS = "Invalid params"
    INTERNAL_ERROR = "Internal error"

class JsonRpcMatch : Matcher
    js : JsonValue? = null
    id : double = double(0f)
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
            id = double(0.)
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
                return <- [[MatchResult args <- [{ auto[] str }] ]] 
        return <- [[MatchResult invalid = null]]


class JsonRpcHandler
    match: JsonRpcMatch <- JsonRpcMatch()
    rpcParams: RpcParams = RpcParams()
    calls: table<string; RpcCall?>
    notifications: table<string; RpcNotification? -const>

    [private] def matchPtr()
        unsafe
            return addr(match)

    def listen(var server: WebServer?): void
        server->on(self->matchPtr()) <| @(msg: string; args: array<string>)
            return self->rpcHandler(msg)

    def lsitedUnhandled(var server: WebServer?): void
        server->unhandled() <| @(msg: string; args: array<string>)
            var res = self->getError("{PARSE_ERROR}: {msg}", PARSE_ERROR_CODE, double(0))
            let str = write_json(res)
            delete res
            return str

    [unused_argument(msg)] def rpcHandler(msg: string): string
        var found = false
        if match.id == double(0f)
            notifications |> find_for_edit_if_exists(match.method) <| $(ptr)
                found = true
                rpcParams->set(match.params)
                (**ptr)->call(rpcParams)
        else
            calls |> find_for_edit_if_exists(match.method) <| $(ptr)
                found = true
                rpcParams->set(match.params)
                (**ptr)->call(rpcParams, match.id)
        if !found
            var res = self->getError("{METHOD_NOT_FOUND}: {match.method}: id: {match.id}", METHOD_NOT_FOUND_CODE, match.id)
            let str = write_json(res)
            delete res
            return str
        return ""

    def addCall(name:string; var call: RpcCall? implicit)
        calls[name] <- call

    def addNotification(name:string; var notification: RpcNotification? implicit)
        notifications[name] <- notification

    def sendResponse(var server: WebServer?; msg: string; id: double)
        var res = JV({{ "jsonrpc" => JV("2.0"); "id" => JV(id); "result" => JV(msg) }})
        server->sendStr(write_json(res))
        delete res

    def sendRequest(var server: WebServer?; method: string; params: JsonValue?; id: double)
        var res = JV({{ "jsonrpc" => JV("2.0"); "id" => JV(id); "method" => JV(method); "params" => params }})
        server->sendStr(write_json(res))
        (res as _object) |> erase("params")
        delete res

    def sendNotification(var server: WebServer?; method: string; params: JsonValue?)
        var res = JV({{ "jsonrpc" => JV("2.0"); "method" => JV(method); "params" => params }})
        server->sendStr(write_json(res))
        (res as _object) |> erase("params")
        delete res

    def getError(error: string; code: double; id: double): JsonValue?
        var res = JV({{ "jsonrpc" => JV("2.0"); "error" => JV({{ "code" => JV(code); "message" => JV(error) }}) }})
        if id != double(0f)
            (res.value as _object)["id"] = JV(id)
        return res

    def sendError(var server: WebServer?; error: string; code: double; id: double)
        var res = self->getError(error, code, id)
        server->sendStr(write_json(res))
        delete res
