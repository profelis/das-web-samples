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


[init,export]
def first_start()
  if is_in_debug_agent_creation() || has_debug_agent()
    return
  start_agent()


[rpc_call(name="reverse")]
def reverse_handler(var params: JsonValue?; id: double)
  unsafe
    verify(addr(get_debug_agent_context()) != addr(this_context()))

  let str = params |> get_arg(0) |> as_string()
  send_response(JV(reverse(str)), id)


[rpc_notification(name="whatsup")]
def whatsup_handler(var params: JsonValue?)
  unsafe
    verify(addr(get_debug_agent_context()) != addr(this_context()))

  let arg0 = params |> get_arg(0)
  print("whatsup!!! arg0: {arg0}\n")
  send_notification("status", JV(42lf))
  send_notification("serverTime", JV(double(ref_time_ticks())))
  send_request("giveHelp", JV(null), @@help_handler)


def help_handler(var params: JsonValue?; id: double)
  unsafe
    verify(addr(get_debug_agent_context()) != addr(this_context()))

  print("giveHelp response {id} - {write_json(params)}. Thanks\n")
