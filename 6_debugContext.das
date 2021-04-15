options indenting = 2

require fio
require strings

require jsonrpc_boost
require js


[export]
def main (fn: string)
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


[rpc_call(name="reverse")]
def reverse_handler(str: string; id: uint64)
  print("{str}\n")
  send_response(js(reverse(str)), id)


[rpc_notification(name="whatsup")]
def whatsup_handler(param: string)
  print("whatsup!!! arg0: {param}\n")
  send_notification("status", js(42))
  send_notification("serverTime", js("{get_clock()}"))
  send_request("giveHelp", js("test string"), @@help_handler)


[rpc_handler]
def help_handler(str: string; id: uint64)
  print("giveHelp response {id} - {str}. Thanks\n")
  // send_notification("serverTime23", JV(ref_time_ticks()))
