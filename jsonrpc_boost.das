
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


def keep_func_and_args(var func)
  func.flags |= FunctionFlags exports
  for arg in func.arguments
    arg.flags |= VariableFlags marked_used


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
  rules |> replaceVariable("func") <| new [[ExprAddr() at = at, target := call_fn_name, funcType <- typeinfo(ast_typedecl type<function<(var params: JsonValue?; id: double): void>>)]]
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
  rules |> replaceVariable("func") <| new [[ExprAddr() at = at, target := call_fn_name, funcType <- typeinfo(ast_typedecl type<function<(var params: JsonValue?): void>>)]]
  apply_template(rules, at, qblock)
  delete rules
  unsafe
    fn.body <- move_unquote_block(qblock)

  compiling_module() |> add_function(fn)


def transform_args(var func; is_call; var errors: das_string): bool
  var fn <- clone_function(func)
  fn.annotations |> clear()
  fn.name := "_{fn.name}"
  fn.flags |= FunctionFlags generated
  let at = fn.at
  var blk: ExprBlock?
  unsafe
    blk = reinterpret<ExprBlock?> fn.body

  let paramsName = "__params__"
  let argsNum = fn.arguments.length
  let processArgsNum = argsNum - (is_call ? 1 : 0)
  for i in range(processArgsNum)
    var argi <- new [[ExprCall() at = at, name := "get_arg" ]]
    argi.arguments |> emplace_new(new [[ExprVar() at = at, name := paramsName]])
    argi.arguments |> emplace_new(new [[ExprConstInt() at = at, value = i ]])

    var baseArg & = fn.arguments[i]
    var baseArgType & = baseArg._type
    if baseArgType.baseType == Type tInt
      var toValue <- new [[ExprCall() at = at, name := "as_int" ]]
      toValue.arguments |> emplace(argi)
      argi <- toValue
    elif baseArgType.baseType == Type tUInt
      var toValue <- new [[ExprCall() at = at, name := "as_uint" ]]
      toValue.arguments |> emplace(argi)
      argi <- toValue
    elif baseArgType.baseType == Type tFloat
      var toValue <- new [[ExprCall() at = at, name := "as_float" ]]
      toValue.arguments |> emplace(argi)
      argi <- toValue
    elif baseArgType.baseType == Type tDouble
      var toValue <- new [[ExprCall() at = at, name := "as_double" ]]
      toValue.arguments |> emplace(argi)
      argi <- toValue
    elif baseArgType.baseType == Type tBool
      var toValue <- new [[ExprCall() at = at, name := "as_bool" ]]
      toValue.arguments |> emplace(argi)
      argi <- toValue
    elif baseArgType.baseType == Type tString
      var toValue <- new [[ExprCall() at = at, name := "as_string" ]]
      toValue.arguments |> emplace(argi)
      argi <- toValue
    elif (baseArgType.baseType == Type tPointer && baseArgType.firstType != null && baseArgType.firstType.baseType == Type tStructure
          && string(baseArgType.firstType.structType.name) == "JsonValue" && string(baseArgType.firstType.structType._module.name) == "json")
      pass // JsonValue
    else
      errors := "{baseArg.name}: {describe(baseArgType)} - unsupported argument type"
      return false

    var vlet <- new [[ExprLet() at = at, atInit = at ]]
    vlet.variables |> emplace_new() <| new [[Variable() at = at,
            name := baseArg.name,
            _type := baseArgType,
            init <- argi
        ]]
    blk.list |> emplace(vlet, i)

    // var deb <- new [[ExprDebug() at = at, name := "debug"]]
    // var debVal <- new [[ExprVar() at = at, name := "arg_{i}"]]
    // deb.arguments |> emplace(debVal)
    // blk.list |> emplace(deb)

  for i in range(processArgsNum) // cleanup all arguments
    fn.arguments |> erase(0)

  var paramsArg <- new [[Variable()
    at = at,
    name := paramsName,
    _type <- typeinfo(ast_typedecl type<json::JsonValue? -const>)
  ]]
  fn.arguments |> emplace(paramsArg, 0)

  keep_func_and_args(fn)
  compiling_module() |> add_function(fn)
  return true


def validate_name_annotation(name_arg; var errors: das_string): bool
  if name_arg is nothing
    errors := "name is not defined"
    return false
  if !(name_arg is tString)
    errors := "name should be string value"
    return false
  return true


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


def validate_req_id_arg(arguments; var errors: das_string)
  let argsNum = arguments.length
  if argsNum < 1
    errors := "at least one argument with request id is required (req_id: double)"
    return false
  if arguments[argsNum - 1]._type.baseType != Type tDouble
    errors := "the last argument should be of double type (req_id: double)"
    return false
  return true


[function_macro(name="rpc_call")]
class RpcCallAnnotation : AstFunctionAnnotation
  [unused_argument(group)] def override apply(var func: FunctionPtr; var group: ModuleGroup; args: AnnotationArgumentList; var errors: das_string) : bool
    let nameArg = find_arg("name", args)
    if !validate_name_annotation(nameArg, errors)
      return false
    if !validate_req_id_arg(func.arguments, errors)
      return false
    if !transform_args(func, /*is_call*/true, errors)
      return false
    keep_func_and_args(func)
    add_call_reg_func(func.at, "_{func.name}", nameArg as tString)
    return true


[function_macro(name="rpc_notification")]
class RpcNotificationAnnotation : AstFunctionAnnotation
  [unused_argument(group)] def override apply(var func: FunctionPtr; var group: ModuleGroup; args: AnnotationArgumentList; var errors: das_string): bool
    let nameArg = find_arg("name", args)
    if !validate_name_annotation(nameArg, errors)
      return false
    if !transform_args(func, /*is_call*/false, errors)
      return false
    keep_func_and_args(func)
    add_notification_reg_func(func.at, "_{func.name}", nameArg as tString)
    return true


[function_macro(name="rpc_handler")]
class RpcHandlerAnnotation : AstFunctionAnnotation
  [unused_argument(group,args)] def override apply(var func: FunctionPtr; var group: ModuleGroup; args: AnnotationArgumentList; var errors: das_string): bool
    if !validate_req_id_arg(func.arguments, errors)
      return false
    if !transform_args(func, /*is_call*/true, errors)
      return false
    keep_func_and_args(func)
    return true
