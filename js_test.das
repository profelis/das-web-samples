options indenting = 2

require js

def printjs(data)
  print("{write_json(js(data))}\n\n")

struct Foo
  ia: array<int> <- [{auto 1; 2; 3}]

struct SomeData
  a: int = 1
  b: string = "1"
  c = true
  d: int?
  e: float?
  f: Foo?

struct Tree
  name: string
  kind: int
  children: array<Tree?>

[export]
def main()
  var x = 10
  printjs(x)
  printjs(12.f)
  printjs(12u)
  printjs(true)
  printjs([[auto[] 10u]])
  printjs([[auto[] 10lf; 20lf]])
  var tab1 <- {{ "foo" => [{auto[] "a"; "b"}] }}
  printjs(tab1)
  var tab2 <- {{ "bar" => [{auto[] 1; 2}] }}
  printjs(tab2)
  var foo = new Foo()
  printjs(foo)
  var data = new [[SomeData]]
  printjs(data)
  data.f = foo
  printjs(data)

  var tree: Tree
  tree.children |> emplace <| new [[Tree name="a"]]
  var child = new [[Tree]]
  child.name = "b"
  child.children |> emplace <| new [[Tree name="c"]]
  tree.children |> emplace <| child
  printjs(tree)
