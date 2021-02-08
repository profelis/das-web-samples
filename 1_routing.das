options indenting = 2

require daslib/regex
require daslib/regex_boost

require debug_server
require regex_match

[export]
def main (fn:string)
  var server = new WebServer()
  server->on(new RegexMatch(%regex~\/items\/(.+)\/(.+)%%)) <| @(msg: string; args: array<string>)
    return "{msg}: handled items. args: {args}\n"
  server->onStr("/") <| @(msg: string; args: array<string>)
    return "{msg}: handled root. args: {args}\n"
  server->unhandled() <| @(msg: string; args: array<string>)
    return "{msg}: unhandled call. args: {args}\n"
  return run_debug_server(server, fn)
