options indenting = 2

require fio
require strings

require jsonrpc_boost


[export]
def main (fn: string)
  let main_time = stat(fn).mtime
  print("start file {fn} at {main_time} agent:{has_debug_agent()}\n")

  while true
    let new_time = stat(fn).mtime
    if new_time != main_time
      break
    sleep(0u)
    tick_agent()

    // send_request("giveHelp", JV("veryyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyylllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllooooooooooooooooooooonnnnnnnnnnnnnnnnnnnnnnnnnnnnggggggggggggggggssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss"), @@help_handler)


[init,export]
def first_start()
  if !is_in_debug_agent_creation() && !has_debug_agent()
    start_agent()


[rpc_call(name="reverse")]
def reverse_handler(str: string; id: double)
  send_response(JV(reverse(str)), id)


[rpc_notification(name="whatsup")]
def whatsup_handler(var param: JsonValue?)
  print("whatsup!!! arg0: {param}\n")
  send_notification("status", JV(42))
  send_notification("serverTime", JV("{get_clock()}"))
  send_request("giveHelp", JV(null), @@help_handler)


def help_handler(var params: JsonValue?; id: double)
  print("giveHelp response {id} - {write_json(params)}. Thanks\n")
