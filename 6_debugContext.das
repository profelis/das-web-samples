options indenting = 2

require fio
require strings
require dasweb/agent_jsonrpc_boost


[export]
def main ()
  let args <- get_command_line_arguments()
  let fn = args[1]
  let main_time = stat(fn).mtime
  print("start file {fn} at {main_time} agent:{has_web_agent()}\n")

  while true
    let new_time = stat(fn).mtime
    if new_time != main_time
      break
    sleep(0u)
    tick_agent()

    // send_request("giveHelp", JV("veryyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyylllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllooooooooooooooooooooonnnnnnnnnnnnnnnnnnnnnnnnnnnnggggggggggggggggssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss"), @@help_handler)


[init,export]
def first_start()
  if !is_in_debug_agent_creation() && !has_web_agent()
    start_agent()


[auto_rpc_call(name="reverse")]
def reverse_handler(str: string; id: uint64)
  print("{str}\n")
  send_response(JV(reverse(str)), id)


[auto_rpc_notification(name="whatsup")]
def whatsup_handler(param: string)
  print("whatsup!!! arg0: {param}\n")
  send_notification("status", JV(42))
  send_notification("serverTime", JV("{get_clock()}"))
  send_request("giveHelp", JV("test string"), @@help_handler)


[auto_rpc_handler]
def help_handler(str: string; id: uint64)
  print("giveHelp response {id} - {str}. Thanks\n")
  // send_notification("serverTime23", JV(ref_time_ticks()))
