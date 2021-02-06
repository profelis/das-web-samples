options indenting = 2
options remove_unused_symbols = false
module jsonrpc_handler

require strings

require daslib/json
require daslib/json_boost

require jsonrpc public
require server

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

variant JsonRpcReqType
  none: void?
  method: string
  result: void?
  error: void?

class JsonRpcMatch : Matcher
  js: JsonValue? = null
  id: double = 0lf
  reqType: JsonRpcReqType
  params: JsonValue?

  def override match(str: string): MatchResult
    id = 0lf
    params = null
    reqType = [[JsonRpcReqType none=null]]
    unsafe
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
      var failed = false
      (js as _object) |> find_if_exists("method") <| $(ptr)
        if *ptr.value is _string
          reqType = [[JsonRpcReqType method=*ptr.value as _string]]
          (js as _object) |> find_if_exists("params") <| $(par)
            params = *par
        else
          failed = true

      if failed // method is not string
        return <- [[MatchResult invalid = null]]

      if reqType is none
        (js as _object) |> find_if_exists("result") <| $(ptr)
          reqType = [[JsonRpcReqType result=null]]
          params = *ptr

      if reqType is method || reqType is result
        (js as _object) |> find_if_exists("id") <| $(ptr)
          if *ptr.value is _number
            id = *ptr.value as _number
          elif *ptr.value is _string
            id = double(to_int(*ptr.value as _string))
          else
            failed = true
        if failed // invalid id
          return <- [[MatchResult invalid = null]]

      if reqType is none
        (js as _object) |> find_if_exists("error") <| $(ptr)
          reqType = [[JsonRpcReqType error=null]]
          params = *ptr

      if !(reqType is none)
        return <- [[MatchResult args <- [{ string[] "" }] ]]
    return <- [[MatchResult invalid = null]]


class JsonRpcHandler
  currentId: double = 0lf

  match: JsonRpcMatch <- JsonRpcMatch()
  rpcParams: RpcParams = RpcParams()
  calls: table<string; RpcCall?>
  notifications: table<string; RpcCall?>
  handlers: table<double; RpcCall?>

  [private] def matchPtr()
    unsafe
      return addr(match)

  def listen(var server: WebServer?): void
    server->on(self->matchPtr()) <| @(msg: string; args: array<string>)
      return self->rpcHandler(msg)

  def listenUnhandled(var server: WebServer?): void
    server->unhandled() <| @(msg: string; args: array<string>)
      var res = self->get_error("{PARSE_ERROR}: `{msg}`", PARSE_ERROR_CODE, 0lf)
      print("[E] {PARSE_ERROR}: `{msg}`\n")
      let str = write_json(res)
      unsafe
        delete res
      return str

  [unused_argument(msg)] def rpcHandler(msg: string): string
    var found = false
    if match.reqType is method
      if match.id == 0lf
        notifications |> find_for_edit_if_exists(match.reqType as method) <| $(ptr)
          found = true
          rpcParams->set(match.params)
          (**ptr)->call(rpcParams, 0lf)
      else
        calls |> find_for_edit_if_exists(match.reqType as method) <| $(ptr)
          found = true
          rpcParams->set(match.params)
          (**ptr)->call(rpcParams, match.id)
      if !found
        var err = self->get_error("{METHOD_NOT_FOUND}: `{match.reqType as method}` id: {match.id}", METHOD_NOT_FOUND_CODE, match.id)
        let res = write_json(err)
        unsafe
          delete err
        print("[E] {METHOD_NOT_FOUND}: `{match.reqType as method}` id: {match.id}\n")
        return res
      return ""

    if match.reqType is result
      handlers |> find_for_edit_if_exists(match.id) <| $(handler)
        found = true
        rpcParams->set(match.params)
        (**handler)->call(rpcParams, 0lf)
      if !found
        print("[E] unhandled result id: {match.id} - {msg}\n")
      return ""

    if match.reqType is error
      print("[E] id: {match.id} - {msg}\n")

    return ""

  def addCall(name: string; var call: RpcCall? implicit)
    calls[name] <- call

  def addNotification(name: string; var notification: RpcCall? implicit)
    notifications[name] <- notification

  def addResponseHander(id: double; var handler: RpcCall? implicit)
    handlers[id] <- handler

  def send_response(var server: WebServer?; msg: string; id: double)
    var res = JV({{ "jsonrpc" => JV("2.0"); "id" => JV(id); "result" => JV(msg) }})
    server->sendStrLf(write_json(res))
    unsafe
      delete res

  def send_request_raw(var server: WebServer?; method: string; params: JsonValue?; id: double): void
    var res = JV({{ "jsonrpc" => JV("2.0"); "id" => JV(id); "method" => JV(method); "params" => params }})
    server->sendStrLf(write_json(res))
    (res as _object) |> erase("params")
    unsafe
      delete res

  def send_request(var server: WebServer?; method: string; params: JsonValue?; var handler: RpcCall? implicit): double
    currentId += 1lf
    self->send_request_raw(server, method, params, currentId)
    self->addResponseHander(currentId, handler)
    return currentId

  def send_notification(var server: WebServer?; method: string; params: JsonValue?)
    var res = JV({{ "jsonrpc" => JV("2.0"); "method" => JV(method); "params" => params }})
    server->sendStrLf(write_json(res))
    (res as _object) |> erase("params")
    unsafe
      delete res

  def get_error(error: string; code: double; id: double): JsonValue?
    var res = JV({{ "jsonrpc" => JV("2.0"); "error" => JV({{ "code" => JV(code); "message" => JV(error) }}) }})
    if id != 0lf
      (res.value as _object)["id"] = JV(id)
    return res

  def send_error(var server: WebServer?; error: string; code: double; id: double)
    var res = self->get_error(error, code, id)
    server->sendStrLf(write_json(res))
    unsafe
      delete res
