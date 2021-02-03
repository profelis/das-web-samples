require server
require strings
require daslib/regex
require daslib/regex_boost

var counter = 0

[export]
def main (fn:string)
    run_server(fn) <| $()
        var server = new WebServer()
        server->onRegex(%regex~\/inc/(.+)%%) <| @(msg: string; args: array<string>)
            counter += to_int(args[0])
            return "{counter}\n"
        server->onRegex(%regex~\/dec/(.+)$%%) <| @(msg: string; args: array<string>)
            counter -= to_int(args[0])
            return "{counter}\n"
        server->onStr("/get") <| @(msg: string; args: array<string>)
            return "{counter}\n"
        server->unhandled() <| @(msg: string; args: array<string>)
            return "{msg}: unhandled call. counter = {counter}\n"
        return server
    return true
