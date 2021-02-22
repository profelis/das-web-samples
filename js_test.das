options indenting = 2

require js

def printjs(data)
  print("{write_json(js(data))}\n\n")

def printjs(a, b)
  print("{write_json(js(a, b))}\n\n")

struct Foo
  ia: array<int>

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
  printjs(tab1, tab2)
  var foo = new Foo
  foo.ia <- [{auto[] 1; 2; 3}]
  printjs(foo)
  var data = SomeData()
  printjs(data)
  data.f = foo
  printjs(data)

  var tree: Tree
  tree.children |> emplace <| new [[Tree name="a"]]
  var child = new [[Tree name="b"]]
  child.children |> emplace <| new [[Tree name="c", kind=2]]
  tree.children |> emplace <| child
  printjs(tree)

  printjs(js(j(1u)))
