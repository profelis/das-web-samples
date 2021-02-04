options indenting = 4
options remove_unused_symbols = false
module server

require network
require fio
require strings
require daslib/strings_boost
require daslib/regex


var
    isContDev = false

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
        print("server error: {code} - {msg}\n")

    def override onConnect
        print("connected\n")

    def override onDisconnect
        if length(current_string) > 0
            print(string(current_string))
            current_string |> clear()
        print("disconnected\n")

    def restart
        if _server != null
            var session : smart_ptr<NetworkServer>
            self->save(session)
            gc0_save_smart_ptr("telnet-session", session)

    def sendStr(str: string)
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
                print("`{str}` length={length(current_string)}\n")
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



def run_server(fileName: string; serverBuilder: block<(): WebServer?>): bool
    isContDev = true
    let main_time = stat(fileName).mtime
    print("server starts at {main_time} file: {fileName}\n")
    let port = 9000
    var telnet = invoke(serverBuilder)
    var session : smart_ptr<NetworkServer> <- gc0_restore_smart_ptr("telnet-session")
    if session != null
        print("restoring server after restart\n")
        telnet->restore(session)
    elif telnet->init(9000)
        print("sever at port {port}\n")
    else
        print("server failed to initialize\n")
        return false
    while !telnet.done
        telnet->tick()
        let new_time = stat(fileName).mtime
        if new_time != main_time
            print("restarting via source change {new_time}\n")
            telnet->restart()
            break
        sleep(0u)
    unsafe
        delete telnet
    return true


def start_server(serverBuilder: block<(): WebServer?>): bool
    isContDev = false
    let port = 9000
    var telnet = invoke(serverBuilder)
    var session : smart_ptr<NetworkServer> <- gc0_restore_smart_ptr("telnet-session")
    if session != null
        print("restoring server after restart\n")
        telnet->restore(session)
    elif telnet->init(9000)
        print("sever at port {port}\n")
    else
        print("server failed to initialize\n")
        delete telnet
        return false
    return true
