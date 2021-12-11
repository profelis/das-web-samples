options indenting = 2
module web_server shared

require network
require strings
require matcher public
require dashv/dashv_boost

// options debugger

class WebServer : HvWebSocketServer
  activeChannnel: WebSocketChannel?
  channels:table<WebSocketChannel?; string> // channel -> url
  channelsData:table<WebSocketChannel?; string> // channel -> messages

  port:int = 9000
  debugLogs : bool = false

  done : bool = false
  matchers: array<Matcher?>
  handlers: array<Handler>
  unhandledHandler: Handler

  def override init(port: int)
    if debugLogs
      print("onInit {port}\n")
    HvWebSocketServer`init(cast<HvWebSocketServer> self, port)
    self.port = port

  def onStr(str: string; var handler: Handler)
    self->on(new StringMatch(str), handler)

  def on(var match: Matcher?; var handler: Handler)
    matchers |> push(match)
    handlers |> emplace(handler)

  def unhandled(var handler: Handler)
    unhandledHandler <- handler

  def override onOpen(channel: WebSocketChannel?; url: string#): void
    if debugLogs
      print("onOpen: {intptr(channel)}, {url}\n")
    channels[channel] := url
    channelsData[channel] := ""

  def override onClose(channel: WebSocketChannel?): void
    if debugLogs
      print("onClose: {intptr(channel)}\n")
    erase(channels, channel)
    erase(channelsData, channel)

  def override onMessage(channel: WebSocketChannel?; msg: string#): void
    // print("onMessage: {intptr(channel)}, {msg} - was: `{channelsData[channel]}`\n")
    channelsData[channel] += msg

  def finalize()
    if debugLogs
      print(":{port} destroy server\n")
    delete cast<HvWebSocketServer> self

  def sendStr(str: string)
    if debugLogs
      print(":{port} > `{str}`\n")
    send(activeChannnel, str, ws_opcode WS_OPCODE_TEXT, true)

  def override onTick(): void
    for i, msg in keys(channelsData), values(channelsData)
      if length(msg) > 0
        let res = self->processCurrentString(i, msg)
        msg = res
        if length(res) > 1000 && unhandledHandler != null
          let unhandledRes = invoke(unhandledHandler, msg)
          if length(unhandledRes) > 0
            self->sendStr(unhandledRes)

  def processCurrentString(channel: WebSocketChannel?; data: string implicit): string
    var str = data
    activeChannnel = channel
    var found = false
    if length(str) > 0
      if debugLogs
        print(":{port} < `{str}`\n")
      for matcher, idx in matchers, iter_range(matchers)
        let match <- matcher->match(str)
        if match is invalid
          continue
        found = true
        let res = invoke(handlers[idx], str)
        if length(res) > 0
          self->sendStr(res)
        let len = match as success
        if len >= length(str)
          str = ""
        else
          str = slice(str, len, length(str))
        break
    return str


def start_server(var server: WebServer?): bool
  server->init(server.port)
  let startRes = server->start()
  if startRes != 0
    unsafe
      delete server
    print("start error :{server.port} - start res {startRes}\n")
    return false
  if server.debugLogs
    print("start :{server.port} - start res {startRes}\n")
  return true
