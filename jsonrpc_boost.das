
options indenting = 2
options remove_unused_symbols = false
module jsonrpc_boost shared

require ast
require debugapi public
require server_agent public

require daslib/ast_boost
require daslib/template_boost

// [init,export]
// def register_<func_name>()
//   unsafe
//     let debugAgent = addr(get_debug_agent_context())
//     if debugAgent != null && debugAgent != addr(this_context())
//       add_call("reverse", @@reverse_handler)

[function_macro(name="rpc_call")]
class RpcCallAnnotation : AstFunctionAnnotation
  def override apply ( var func:FunctionPtr; var group:ModuleGroup; args:AnnotationArgumentList; var errors : das_string ) : bool
    let nameArg = find_arg("name", args)
    if nameArg is nothing
      errors := "name is not defined"
      return false
    if !(nameArg is tString)
      errors := "name should be string value"
      return false
    func.flags |= FunctionFlags exports
    let at = func.at
    var fn <- new [[Function() at = at, atDecl = at, name := "register_{func.name}_{nameArg as tString}"]]
    fn.flags |= FunctionFlags generated
    fn.flags |= FunctionFlags privateFunction
    fn.flags |= FunctionFlags init
    fn.result <- new [[TypeDecl() baseType=Type autoinfer, at=at]]

    var qblock <- quote() <|
      unsafe
        let debugAgent = addr(get_debug_agent_context())
        if debugAgent != null && debugAgent != addr(this_context())
          add_call(func_name, func)

    var rules : Template
    rules |> replaceVariable("func_name") <| new [[ExprConstString() at = at, value := nameArg as tString]]
    rules |> replaceVariable("func") <| new [[ExprAddr() at = at, target := func.name]]
    apply_template(rules, at, qblock)
    delete rules
    var b <- move_unquote_block(qblock)
    unsafe
      fn.body <- b

    compiling_module() |> add_function(fn)
    return true


[function_macro(name="rpc_notification")]
class RpcNotificationAnnotation : AstFunctionAnnotation
  def override apply ( var func:FunctionPtr; var group:ModuleGroup; args:AnnotationArgumentList; var errors : das_string ) : bool
    let nameArg = find_arg("name", args)
    if nameArg is nothing
      errors := "name is not defined"
      return false
    if !(nameArg is tString)
      errors := "name should be string value"
      return false
    func.flags |= FunctionFlags exports
    let at = func.at
    var fn <- new [[Function() at = at, atDecl = at, name := "register_{func.name}_{nameArg as tString}"]]
    fn.flags |= FunctionFlags generated
    fn.flags |= FunctionFlags privateFunction
    fn.flags |= FunctionFlags init
    fn.result <- new [[TypeDecl() baseType=Type autoinfer, at=at]]

    var qblock <- quote() <|
      unsafe
        let debugAgent = addr(get_debug_agent_context())
        if debugAgent != null && debugAgent != addr(this_context())
          add_notification(func_name, func)

    var rules : Template
    rules |> replaceVariable("func_name") <| new [[ExprConstString() at = at, value := nameArg as tString]]
    rules |> replaceVariable("func") <| new [[ExprAddr() at = at, target := func.name]]
    apply_template(rules, at, qblock)
    delete rules
    var b <- move_unquote_block(qblock)
    unsafe
      fn.body <- b

    compiling_module() |> add_function(fn)
    return true