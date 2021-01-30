// options log = true

require network
require fio
require strings
require daslib/strings_boost
require daslib/regex


var
    isContDev = false

typedef
    Handler = lambda<(message: string; args: array<string>): string>

class WebServer : Server
    current_string : array<uint8>
    done : bool = false
    regexps: array<Regex>
    handlers: array<Handler>
    unhandledHandler: Handler

    def WebServer
        Server`Server(cast<Server> self)

    def on(var msg: Regex; var handler: Handler)
        regexps |> emplace(msg)
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
            elif int(ch) == '\n'
                print("`{string(current_string)}` length={length(current_string)}\n")
                let str = string(current_string)
                var found = false
                for i, re in iter_range(regexps), regexps
                    let match = re |> regex_match(str, 0)
                    if match < 0
                        continue
                    found = true
                    var args: array<string>
                    for gr in re.groups
                        if gr._0.x < gr._0.y
                            args |> push <| slice(str, gr._0.x, gr._0.y)
                    let res = invoke(handlers[i], str, args)
                    self->sendStr(res)
                    break
                if !found && unhandledHandler != null
                    let res = invoke(unhandledHandler, str, [[array<string>]])
                    self->sendStr(res)
                current_string |> clear()
            else
                current_string |> push(ch)



def startServer(fileName: string; serverBuilder: block<(): WebServer?>)
    isContDev = true
    let main_time = stat(fileName).mtime
    print("server starts at {main_time}\n")
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
    unsafe
        delete telnet
    return true
