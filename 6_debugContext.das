options indenting = 2

require fio
require strings
require debugapi

require daslib/json

require jsonrpc_handler
require jsonrpc_rtti
require server_agent


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
def binit_handlers()
  if is_in_debug_agent_creation() || has_debug_agent()
    return
  start_agent()
  // register_handlers()


[init,export]
def init_handlers()
  unsafe
    if has_debug_agent() && addr(get_debug_agent_context()) != addr(this_context())
      register_handlers()


def register_handlers()
  unsafe
    verify(addr(get_debug_agent_context()) != addr(this_context()))

  add_call("reverse", @@reverse_handler)
  add_notification("whatsup", @@whatsup_handler)


[export]
def reverse_handler(var params: RpcParams; id: double)
  unsafe
    verify(addr(get_debug_agent_context()) != addr(this_context()))

  let str = params->getArgN(0) |> as_string()
  send_response(reverse(str), id)

[export]
def whatsup_handler(var params: RpcParams)
  unsafe
    verify(addr(get_debug_agent_context()) != addr(this_context()))

  let str = params->getArgN(0) |> as_string()
  print("whatsup!!!\n")
  send_notification("status", JV(42lf))
  send_notification("serverTime", JV(double(ref_time_ticks())))
  send_request("giveHelp", JV(null), @@help_handler)

[export]
def help_handler(var params: RpcParams; id: double)
  unsafe
    verify(addr(get_debug_agent_context()) != addr(this_context()))

  print("giveHelp response {id} - {write_json(params.params)}. Thanks\n")
