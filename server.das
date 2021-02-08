options indenting = 2
options remove_unused_symbols = false
module server shared

require network
require strings

require daslib/strings_boost
require daslib/regex


typedef
  Handler = lambda<(message: string; args: array<string>): string>
  MatchResult = variant<args: array<string>; invalid: void?; more: void?>

class Matcher
  def abstract match(str: string): MatchResult


class StringMatch : Matcher
  matchStr : string
  def StringMatch(str: string)
    matchStr = str
  def override match(str: string): MatchResult
    if str == matchStr
      return <- [[MatchResult args <- [{ auto[] str }] ]]
    return <- [[MatchResult invalid = null]]


class RegexMatch : Matcher
  matchRe : Regex
  def RegexMatch(var re: Regex)
    matchRe <- re
  def override match(str: string): MatchResult
    let res = matchRe |> regex_match(str)
    if res < 0
      return <- [[MatchResult invalid = null]]
    var args: array<string>
    for gr,x in matchRe.groups, range(length(matchRe.groups)-1)
      let grp = regex_group(matchRe, x+1, str)
      args |> push(grp)
    return <- [[MatchResult args <- args ]]


class WebServer : Server
  port:int = 9000
  restore_session: string = "server-session"
  debugLogs : bool = true

  current_string : array<uint8>
  done : bool = false
  matchers: array<Matcher?>
  handlers: array<Handler>
  unhandledHandler: Handler

  def WebServer
    Server`Server(cast<Server> self)

  def onStr(str: string; var handler: Handler)
    self->on(new StringMatch(str), handler)

  def onRegex(var re: Regex; var handler: Handler)
    self->on(new RegexMatch(re), handler)

  def on(var match: Matcher? implicit; var handler: Handler)
    matchers |> push(match)
    handlers |> emplace(handler)

  def unhandled(var handler: Handler)
    unhandledHandler <- handler

  def override onError(msg:string; code:int)
    print("[E] :{port} error code: {code} msg: {msg}\n")

  def override onConnect()
    if debugLogs
      print(":{port} client connected\n")

  def override onDisconnect()
    if debugLogs
      print(":{port} client disconnected\n")
    if length(current_string) > 0
      print("[W] :{port} unhandled req `{string(current_string)}`")
      current_string |> clear()

  def finalize()
    if debugLogs
      print(":{port} destroy server\n")
    unsafe
      delete _server

  def restart
    if _server != null
      var session : smart_ptr<NetworkServer>
      self->save(session)
      gc0_save_smart_ptr(restore_session, session)

  def sendStrLf(str: string)
    self->sendStr("{str}\n") // use '\n' to split multiple messages on client

  def sendStr(str: string)
    if debugLogs
      print(":{port} > `{str}`\n")
    unsafe
      self->send(reinterpret<uint8?> str, length(str))

  def override onData(msg:uint8?; size:int)
    for i in range(size)
      var ch: uint8
      unsafe
        ch = msg[i]
      if int(ch) == '\r'
        continue

      if int(ch) == '\n' && length(current_string) > 0
        let str = string(current_string)
        if debugLogs
          print(":{port} < `{str}`\n")
        var found = false
        var needMore = false
        for matcher, idx in matchers, iter_range(matchers)
          let match <- matcher->match(str)
          if match is invalid
            continue
          if match is more
            needMore = true
            continue
          found = true
          let res = invoke(handlers[idx], str, match as args)
          if length(res) > 0
            self->sendStr(res)
          break
        if !found
          if needMore // no matches, but somebody wants more
            current_string |> push(ch)
            continue
          if unhandledHandler != null
            let res = invoke(unhandledHandler, str, [[array<string>]])
            if length(res) > 0
              self->sendStr(res)
        current_string |> clear()
        continue

      current_string |> push(ch)

    if length(current_string) > 0
      var found = false
      let str = string(current_string)
      if debugLogs
        print(":{port} < `{str}`\n")
      for matcher, idx in matchers, iter_range(matchers)
        let match <- matcher->match(str)
        if match is invalid
          continue
        if match is more
          continue
        found = true
        let res = invoke(handlers[idx], str, match as args)
        if length(res) > 0
          self->sendStr(res)
        current_string |> clear()
        break


def start_server(var server: WebServer?): bool
  var session : smart_ptr<NetworkServer> <- gc0_restore_smart_ptr(server.restore_session)
  if session != null
    if server.debugLogs
      print("restoring :{server.port} after restart\n")
    server->restore(session)
  elif server->init(server.port)
    if server.debugLogs
      print("start :{server.port}\n")
  else
    if server.debugLogs
      print(":{server.port} failed to initialize\n")
    unsafe
      delete server
    return false
  return true
