options indenting = 4
options remove_unused_symbols = false
module jsonrpc

require strings
require server
require daslib/json
require daslib/json_boost


class RpcCall
    def abstract call(var params: RpcParams; id: double): void

class LambdaRpcCall : RpcCall
    fn: lambda<(var params: RpcParams; id: double):void>
    def LambdaRpcCall(var f: lambda<(var params: RpcParams; id: double):void>)
        fn <- f

    def override call(var params: RpcParams; id:double): void
        invoke(fn, params, id)


class LambdaRpcNotification : RpcCall
    fn: lambda<(var params: RpcParams):void>
    def LambdaRpcNotification(var f: lambda<(var params: RpcParams):void>)
        fn <- f

    [unused_argument(id)] def override call(var params: RpcParams; id:double): void
        invoke(fn, params)


class FunctionRpcCall : RpcCall
    fn: function<(var params: RpcParams; id: double):void>
    def FunctionRpcCall(var f: function<(var params: RpcParams; id: double):void>)
        fn <- f

    def override call(var params: RpcParams; id:double): void
        invoke(fn, params, id)


class FunctionRpcNotification : RpcCall
    fn: function<(var params: RpcParams):void>
    def FunctionRpcNotification(var f: function<(var params: RpcParams):void>)
        fn <- f

    [unused_argument(id)] def override call(var params: RpcParams; id:double): void
        invoke(fn, params)


class RpcParams
    params: JsonValue?
    num : int = 0
    def set(data: JsonValue?)
        params = data
        num = 0
        if params != null
            if params is _array
                num = length(params as _array)
            elif params is _object
                num = length(params as _object)

    def getArgN(idx: int): JsonValue?
        if idx == 0 && num == 0
            return params
        if idx >= num
            return null

        if params is _array
            return (params as _array)[idx]
        return null

    def getArg(name: string): JsonValue?
        if params is _object
            return (params as _object)[name]
        return null

def is_bool(js: JsonValue?): bool
    return js != null && js is _bool

def as_bool(js: JsonValue?): bool
    if js == null
        return false
    if js is _bool
        return js as _bool
    if js is _number
        return (js as _number) != 0lf
    if js is _string
        return to_int(js as _string) != 0
    return js is _object || js is _array

def is_string(js: JsonValue?): bool
    return js != null && js is _string

def as_string(js: JsonValue?): string
    if js == null
        return ""
    if js is _string
        return js as _string
    if js is _bool
        return js as _bool ? "true" : "false"
    if js is _number
        return string(float(js as _number))
    return js is _object ? "[Object object]" : js is _array ? "[Array array]" : ""

def is_number(js: JsonValue?): bool
    return js != null && js is _number

def as_number(js: JsonValue?): double
    return as_double(js)

def as_double(js: JsonValue?): double
    if js == null
        return 0lf
    if js is _number
        return js as _number
    if js is _bool
        return js as _bool ? 1lf : 0lf
    if js is _string
        return double(js as _string)

    return 0lf

def as_float(js: JsonValue?): float
    if js == null
        return 0f
    if js is _number
        return float(js as _number)
    if js is _bool
        return js as _bool ? 1f : 0f
    if js is _string
        return to_float(js as _string)

    return 0f

def as_int(js: JsonValue?): int
    if js == null
        return 0
    if js is _number
        return int(js as _number)
    if js is _bool
        return js as _bool ? 1 : 0
    if js is _string
        return to_int(js as _string)

    return 0
