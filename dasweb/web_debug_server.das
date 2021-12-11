options indenting = 2
module debug_server shared

require fio

require web_server public


def run_debug_server(var server: WebServer?; fileName:string): bool
  if !start_server(server)
    return false
  let main_time = stat(fileName).mtime

  server->run()
  unsafe
    delete server
  return true
