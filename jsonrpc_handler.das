options indenting = 2
options remove_unused_symbols = false
module jsonrpc_handler shared

require strings

require daslib/json public
require daslib/json_boost public

require jsonrpc_call public
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

struct JsonRpcReq
  js: JsonValue?
  id: double = 0lf
  reqType: JsonRpcReqType
  params: JsonValue?

class JsonRpcMatch : Matcher
  requests: array<JsonRpcReq>

  def clean(): void
    for it in requests
      it.params = null // it.js point to same json data
      delete it
    requests |> clear()

  def override match(str: string): MatchResult
    self->clean()

    if find(str, "\"jsonrpc\"") < 0
      return <- [[MatchResult invalid = null]]

    let strLen = length(str)
    var start = 0
    var end = 0
    for idx, ch in range(strLen), str
      if ch == '}' || ch == ']'
        if self->parseReq(str |> slice(start, idx + 1))
          start = idx + 1
          end = idx + 1

    if start < strLen - 1
      if self->parseReq(str |> slice(start, strLen))
        end = strLen

    if length(requests) == 0
      return <- [[MatchResult invalid = null]]
    return <- [[MatchResult success = end ]]

  def parseReq(str: string): bool
    var res = false
    try
      var error: string
      var js = read_json(str, error)
      res = self->parseReqJson(js, true)
    recover
      print("[E] unhandled error in JsonRpcMatch::parseReq:\n{str}\n")
    return res

  def parseReqJson(var js: JsonValue?; ownJson: bool): bool
    if js == null
      return false

    if js is _array
      var reqLen = requests |> length()
      for it in js as _array
        self->parseReqJson(it, false)
      if ownJson && length(requests) > reqLen
        requests[length(requests) - 1].js = js
        return true
      if ownJson
        unsafe
          delete js
      return false

    var req: JsonRpcReq
    if ownJson
      req.js = js

    if js is _object
      var failed = false
      (js as _object) |> find_if_exists("method") <| $(ptr)
        if *ptr.value is _string
          req.reqType = [[JsonRpcReqType method=*ptr.value as _string]]
          (js as _object) |> find_if_exists("params") <| $(par)
            req.params = *par
        else
          failed = true

      if failed // method is not string
        delete req
        return false

      if req.reqType is none
        (js as _object) |> find_if_exists("result") <| $(ptr)
          req.reqType = [[JsonRpcReqType result=null]]
          req.params = *ptr

      if req.reqType is method || req.reqType is result
        (js as _object) |> find_if_exists("id") <| $(ptr)
          if *ptr.value is _number
            req.id = *ptr.value as _number
          elif *ptr.value is _string
            req.id = double(to_int(*ptr.value as _string))
          else
            failed = true
        if failed // invalid id
          delete req
          return false

      if req.reqType is none
        (js as _object) |> find_if_exists("error") <| $(ptr)
          req.reqType = [[JsonRpcReqType error=null]]
          req.params = *ptr

      if !(req.reqType is none)
        self.requests |> emplace(req)
        return true

    unsafe
      delete req
    return false


class JsonRpcHandler
  currentId: double = 0lf

  match: JsonRpcMatch <- JsonRpcMatch()
  calls: table<string; RpcCall?>
  notifications: table<string; RpcCall?>
  handlers: table<double; RpcCall?>
  errorHandlers: array<RpcCall?>

  [private] def matchPtr()
    unsafe
      return addr(match)

  def listen(var server: WebServer?): void
    server->on(self->matchPtr()) <| @(msg: string)
      return self->rpcHandler(msg)

  def listenUnhandled(var server: WebServer?): void
    server->unhandled() <| @(msg: string)
      print("[E] {PARSE_ERROR}: `{msg}`\n")
      var res = self->getError("{PARSE_ERROR}: `{msg}`", PARSE_ERROR_CODE, 0lf)
      let str = write_json(res)
      unsafe
        delete res
      return str

  def rpcHandler(msg: string): string
    var errors = ""
    for req in match.requests
      var found = false
      if req.reqType is method
        if req.id == 0lf
          notifications |> find_for_edit_if_exists(req.reqType as method) <| $(ptr)
            found = true
            (**ptr)->call(req.params, 0lf)
        else
          calls |> find_for_edit_if_exists(req.reqType as method) <| $(ptr)
            found = true
            (**ptr)->call(req.params, req.id)
        if !found
          var err = self->getError("{METHOD_NOT_FOUND}: `{req.reqType as method}` id: {req.id}", METHOD_NOT_FOUND_CODE, req.id)
          errors = length(errors) > 0 ? "{errors}\n{write_json(err)}" : write_json(err)
          unsafe
            delete err
          print("[E] {METHOD_NOT_FOUND}: `{req.reqType as method}` id: {req.id}\n")
        continue

      if req.reqType is result
        handlers |> find_for_edit_if_exists(req.id) <| $(handler)
          found = true
          (**handler)->call(req.params, 0lf)
        if !found
          print("[E] unhandled result id: {req.id} - {msg}\n")
        continue

      if req.reqType is error
        for handler in errorHandlers
          (*handler)->call(req.params, 0lf)

        print("[E] response error id: {req.id} - {msg}\n{write_json(req.params)}\n")
        continue

    match->clean()
    return errors

  def addCall(name: string; var call: RpcCall? implicit)
    calls[name] <- call

  def addNotification(name: string; var notification: RpcCall? implicit)
    notifications[name] <- notification

  def addResponseHander(id: double; var handler: RpcCall? implicit)
    handlers[id] <- handler

  def addErrorHandler(var handler: RpcCall? implicit)
    errorHandlers |> emplace(handler)

  def sendResponseStr(var server: WebServer?; msg: string; id: double)
    var res = "\{\"jsonrpc\": \"2.0\", \"result\": {msg}, \"id\": {int(id)}\}"
    server->sendStr(res)

  def sendResponse(var server: WebServer?; msg: JsonValue?; id: double)
    var res = JV({{ "jsonrpc" => JV("2.0"); "id" => JV(id); "result" => msg }})
    server->sendStr(write_json(res))
    unsafe
      delete res

  def sendRequestRaw(var server: WebServer?; method: string; params: JsonValue?; id: double): void
    var res = JV({{ "jsonrpc" => JV("2.0"); "id" => JV(id); "method" => JV(method); "params" => params }})
    server->sendStr(write_json(res))
    unsafe
      delete res

  def sendRequestRawStr(var server: WebServer?; method: string; params: string; id: double): void
    var res = "\{\"jsonrpc\": \"2.0\", \"method\": \"{method}\", \"params\": {params}, \"id\": {int(id)}\}"
    server->sendStr(res)

  def sendRequestStr(var server: WebServer?; method: string; params: string; var handler: RpcCall? implicit): double
    currentId += 1lf
    self->addResponseHander(currentId, handler)
    self->sendRequestRawStr(server, method, params, currentId)
    return currentId

  def sendRequest(var server: WebServer?; method: string; params: JsonValue?; var handler: RpcCall? implicit): double
    currentId += 1lf
    self->addResponseHander(currentId, handler)
    self->sendRequestRaw(server, method, params, currentId)
    return currentId

  def sendNotificationStr(var server: WebServer?; method: string; params: string)
    var res = "\{\"jsonrpc\": \"2.0\", \"method\": \"{method}\", \"params\": {params}\}"
    server->sendStr(res)

  def sendNotification(var server: WebServer?; method: string; params: JsonValue?)
    var res = JV({{ "jsonrpc" => JV("2.0"); "method" => JV(method); "params" => params }})
    server->sendStr(write_json(res))
    unsafe
      delete res

  def getError(error: string; code: double; id: double): JsonValue?
    var res = JV({{ "jsonrpc" => JV("2.0"); "error" => JV({{ "code" => JV(code); "message" => JV(error) }}) }})
    if id != 0lf
      (res.value as _object)["id"] = JV(id)
    return res

  def sendError(var server: WebServer?; error: string; code: double; id: double)
    var res = self->getError(error, code, id)
    server->sendStr(write_json(res))
    unsafe
      delete res
