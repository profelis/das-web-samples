
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


def transform_args(var fn; is_call)
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
            name := baseArg.name,
            _type <- baseArgType,
            init <- argi
        ]]
    blk.list |> emplace(vlet, i)

    // var deb <- new [[ExprDebug() at = at, name := "debug"]]
    // var debVal <- new [[ExprVar() at = at, name := "arg_{i}"]]
    // deb.arguments |> emplace(debVal)
    // blk.list |> emplace(deb)

  for i in range(processArgsNum) // cleanup all arguments
    fn.arguments |> erase(0)

  var jsonStruct := get_ast_struct("json", "JsonValue")
  var jsonStructType <- new [[TypeDecl() at = at, baseType = Type tStructure, structType = get_ptr(jsonStruct) ]]
  // jsonStructType.flags &= ~TypeDeclFlags constant
  // jsonStructType.flags |= TypeDeclFlags removeConstant
  var paramsArg <- new [[Variable()
    at = at,
    name := paramsName,
    _type <- new [[TypeDecl() at = at, baseType = Type tPointer, firstType <- jsonStructType ]]
  ]]
  paramsArg._type.flags |= TypeDeclFlags removeConstant
  // paramsArg.flags &= ~(FieldDeclarationFlags capturedConstant)
  fn.arguments |> emplace(paramsArg, 0)

  for arg in fn.arguments
    arg.flags |= VariableFlags marked_used


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

    keep_func_and_args(func)

    transform_args(func, /*is_call*/true)
    add_call_reg_func(func.at, func.name, nameArg as tString)
    return true


[function_macro(name="rpc_notification")]
class RpcNotificationAnnotation : AstFunctionAnnotation
  [unused_argument(group)] def override apply(var func: FunctionPtr; var group: ModuleGroup; args: AnnotationArgumentList; var errors: das_string): bool
    let nameArg = find_arg("name", args)
    if !validate_name_annotation(nameArg, errors)
      return false

    keep_func_and_args(func)
    transform_args(func, /*is_call*/false)
    add_notification_reg_func(func.at, func.name, nameArg as tString)
    return true


[function_macro(name="rpc_handler")]
class RpcHandlerAnnotation : AstFunctionAnnotation
  [unused_argument(group,args)] def override apply(var func: FunctionPtr; var group: ModuleGroup; args: AnnotationArgumentList; var errors: das_string): bool
    if !validate_req_id_arg(func.arguments, errors)
      return false

    keep_func_and_args(func)
    transform_args(func, /*is_call*/true)
    return true
