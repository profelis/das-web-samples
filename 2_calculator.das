options indenting = 2

require strings

require daslib/regex
require daslib/regex_boost

require dasweb/regex_match
require dasweb/web_server_debug


var counter = 0


[export]
def main ()
  let args <- get_command_line_arguments()
  let fn = args[1]
  var server = new WebServer()
  var plusMatch = new RegexMatch(%regex~\/inc/(.+)%%)
  server->on(plusMatch) <| @(msg: string)
    counter += to_int(plusMatch.args[0])
    return "{counter}\n"
  var minusMatch = new RegexMatch(%regex~\/dec/(.+)$%%)
  server->on(minusMatch) <| @(msg: string)
    counter -= to_int(minusMatch.args[0])
    return "{counter}\n"
  server->onStr("/get") <| @(msg: string)
    return "{counter}\n"
  server->unhandled() <| @(msg: string)
    return "{msg}: unhandled call. counter = {counter}\n"
  return run_debug_server(server, fn)
