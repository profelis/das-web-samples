options indenting = 2

require daslib/regex
require daslib/regex_boost

require dasweb/web_server_debug
require dasweb/regex_match

[export]
def main ()
  let args <- get_command_line_arguments()
  let fn = args[1]
  var server = new WebServer()

  var itemsMatch = new RegexMatch(%regex~\/items\/(.+)\/(.+)%%)
  server->on(itemsMatch) <| @(msg: string)
    return "{msg}: handled items. args: {itemsMatch.args}\n"

  server->onStr("/") <| @(msg: string)
    return "{msg}: handled root.\n"
  server->unhandled() <| @(msg: string)
    return "{msg}: unhandled call.\n"
  return run_debug_server(server, fn)
