
options indenting = 2
options remove_unused_symbols = false
module jsonrpc_boost shared

require ast
require debugapi public

require daslib/ast_boost
require daslib/template_boost

require server_agent public
require jsonrpc_handler public
require jsonrpc_args public

// [init,export]
// def register_<func_name>_<bind_name>()
//   unsafe
//     let debugAgent = addr(get_debug_agent_context())
//     if debugAgent != null && debugAgent != addr(this_context())
//       add_call(<bind_name>, @@<func_name>)

def get_ast_struct(mod_name: string; type_name: string)
  var mod = get_module(mod_name)
  var res: smart_ptr<Structure>
  mod |> for_each_structure() <| $(s)
    if res == null && string(s.name) == type_name
      res := s
  return res


def add_call_reg_func(at; call_fn_name; call_fn_alias)
  let fn_name = "register_{call_fn_name}_{call_fn_alias}"
  var fn <- new [[Function() at = at, atDecl = at, name := fn_name]]
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
  rules |> replaceVariable("func_name") <| new [[ExprConstString() at = at, value := call_fn_alias]]
  rules |> replaceVariable("func") <| new [[ExprAddr() at = at, target := call_fn_name]]
  apply_template(rules, at, qblock)
  delete rules
  unsafe
    fn.body <- move_unquote_block(qblock)

  compiling_module() |> add_function(fn)

def add_notification_reg_func(at; call_fn_name; call_fn_alias)
  let fn_name = "register_{call_fn_name}_{call_fn_alias}"
  var fn <- new [[Function() at = at, atDecl = at, name := fn_name]]
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
  rules |> replaceVariable("func_name") <| new [[ExprConstString() at = at, value := call_fn_alias]]
  rules |> replaceVariable("func") <| new [[ExprAddr() at = at, target := call_fn_name]]
  apply_template(rules, at, qblock)
  delete rules
  unsafe
    fn.body <- move_unquote_block(qblock)

  compiling_module() |> add_function(fn)


def add_proxy_func(at; var func; fn_proxy_name; is_call)
  var fn <- new [[Function() at = at, atDecl = at, name := fn_proxy_name]]
  fn.flags |= FunctionFlags generated
  fn.flags |= FunctionFlags exports
  // fn.sideEffectFlags |= FunctionSideEffectFlags modifyExternal
  fn.result <- new [[TypeDecl() baseType=Type tVoid, at=at]]
  var jsonStruct := get_ast_struct("json", "JsonValue")
  var jsonStructType <- new [[TypeDecl() at = at, baseType = Type tStructure, structType = get_ptr(jsonStruct) ]]
  // jsonStructType.flags &= ~TypeDeclFlags constant
  // jsonStructType.flags |= TypeDeclFlags removeConstant
  var paramsArg <- new [[Variable()
    at = at,
    name := "params",
    _type <- new [[TypeDecl() at = at, baseType = Type tPointer, firstType <- jsonStructType ]]
  ]]
  paramsArg._type.flags |= TypeDeclFlags removeConstant
  // paramsArg.flags &= ~(FieldDeclarationFlags capturedConstant)
  fn.arguments |> emplace(paramsArg)
  if is_call
    var idVal <- new [[Variable()
      at = at,
      name := "id",
      _type <- new [[TypeDecl() at = at, baseType = Type tDouble ]]
    ]]
    idVal._type.flags |= TypeDeclFlags constant
    fn.arguments |> emplace(idVal)

  // debug(func.arguments[0])

  for arg in fn.arguments
    arg.flags |= VariableFlags marked_used

  var blk <- new [[ExprBlock() at = at]]

  var callBase <- new [[ExprCall() at = at, name := func.name ]]
  let argsNum = func.arguments.length
  for i in range(argsNum - (is_call ? 1 : 0))
    var argi <- new [[ExprCall() at = at, name := "get_arg" ]]
    argi.arguments |> emplace_new(new [[ExprVar() at = at, name := "params"]])
    argi.arguments |> emplace_new(new [[ExprConstInt() at = at, value = i ]])

    var baseArgType & = func.arguments[i]._type
    if baseArgType.baseType == Type tInt
      var toInt <- new [[ExprCall() at = at, name := "as_int" ]]
      toInt.arguments |> emplace(argi)
      argi <- toInt
    elif baseArgType.baseType == Type tUInt
      var toInt <- new [[ExprCall() at = at, name := "as_uint" ]]
      toInt.arguments |> emplace(argi)
      argi <- toInt
    elif baseArgType.baseType == Type tFloat
      var toInt <- new [[ExprCall() at = at, name := "as_float" ]]
      toInt.arguments |> emplace(argi)
      argi <- toInt
    elif baseArgType.baseType == Type tDouble
      var toInt <- new [[ExprCall() at = at, name := "as_double" ]]
      toInt.arguments |> emplace(argi)
      argi <- toInt
    elif baseArgType.baseType == Type tBool
      var toInt <- new [[ExprCall() at = at, name := "as_bool" ]]
      toInt.arguments |> emplace(argi)
      argi <- toInt
    elif baseArgType.baseType == Type tString
      var toInt <- new [[ExprCall() at = at, name := "as_string" ]]
      toInt.arguments |> emplace(argi)
      argi <- toInt

    var vlet <- new [[ExprLet() at = at, atInit = at ]]
    vlet.variables |> emplace_new() <| new [[Variable() at = at,
            name := "arg_{i}",
            _type <- new [[TypeDecl() baseType = Type autoinfer, at = at]],
            init <- argi
        ]]
    blk.list |> emplace(vlet)
    callBase.arguments |> emplace_new(new [[ExprVar() at = at, name := "arg_{i}"]])

    // var deb <- new [[ExprDebug() at = at, name := "debug"]]
    // var debVal <- new [[ExprVar() at = at, name := "arg_{i}"]]
    // deb.arguments |> emplace(debVal)
    // blk.list |> emplace(deb)

  if is_call
    callBase.arguments |> emplace_new(new [[ExprVar() at = at, name := func.arguments[argsNum - 1].name]])

  blk.list |> emplace(callBase)

  fn.body <- blk
  compiling_module() |> add_function(fn)


def validate_name_annotation(name_arg; var errors: das_string): bool
  if name_arg is nothing
    errors := "name is not defined"
    return false
  if !(name_arg is tString)
    errors := "name should be string value"
    return false
  return true


def keep_func_and_args(var func)
  func.flags |= FunctionFlags exports
  for arg in func.arguments
    arg.flags |= VariableFlags marked_used


[function_macro(name="rpc_call_raw")]
class RpcCallRawAnnotation : AstFunctionAnnotation
  [unused_argument(group)] def override apply(var func: FunctionPtr; var group: ModuleGroup; args: AnnotationArgumentList; var errors: das_string) : bool
    let nameArg = find_arg("name", args)
    if !validate_name_annotation(nameArg, errors)
      return false

    keep_func_and_args(func)
    add_call_reg_func(func.at, func.name, nameArg as tString)
    return true


[function_macro(name="rpc_notification_raw")]
class RpcNotificationRawAnnotation : AstFunctionAnnotation
  [unused_argument(group)] def override apply(var func: FunctionPtr; var group: ModuleGroup; args: AnnotationArgumentList; var errors: das_string): bool
    let nameArg = find_arg("name", args)
    if !validate_name_annotation(nameArg, errors)
      return false

    keep_func_and_args(func)
    add_notification_reg_func(func.at, func.name, nameArg as tString)
    return true


[function_macro(name="rpc_call")]
class RpcCallAnnotation : AstFunctionAnnotation
  [unused_argument(group)] def override apply(var func: FunctionPtr; var group: ModuleGroup; args: AnnotationArgumentList; var errors: das_string) : bool
    let nameArg = find_arg("name", args)
    if !validate_name_annotation(nameArg, errors)
      return false
    let argsNum = func.arguments.length
    if argsNum < 1
      errors := "at least one argument with request id is required (id: double)"
      return false
    if func.arguments[argsNum - 1]._type.baseType != Type tDouble
      errors := "the last argument should be of double type (id: double)"
      return false

    keep_func_and_args(func)

    let proxyName = "proxy_{func.name}"
    add_proxy_func(func.at, func, proxyName, /*is_call*/true)
    add_call_reg_func(func.at, proxyName, nameArg as tString)
    return true


[function_macro(name="rpc_notification")]
class RpcNotificationAnnotation : AstFunctionAnnotation
  [unused_argument(group)] def override apply(var func: FunctionPtr; var group: ModuleGroup; args: AnnotationArgumentList; var errors: das_string): bool
    let nameArg = find_arg("name", args)
    if !validate_name_annotation(nameArg, errors)
      return false

    keep_func_and_args(func)
    let proxyName = "proxy_{func.name}"
    add_proxy_func(func.at, func, proxyName, /*is_call*/false)
    add_notification_reg_func(func.at, proxyName, nameArg as tString)
    return true
