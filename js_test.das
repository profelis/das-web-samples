options indenting = 2

require js

def printjs(data)
  print("{write_json(js(data))}\n\n")

def printjs(a, b)
  print("{write_json(js(a, b))}\n\n")

struct Foo
  ia: array<int> <- [{auto 1; 2; 3; 4}]

class SomeData
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
  printjs([[auto[] 10.2lf; 20.4lf]])
  var tab1 <- {{ "foo" => [{auto[] "a"; "b"}] }}
  printjs(tab1)
  var tab2 <- {{ "bar" => [{auto[] 1; 2}] }}
  printjs(tab2)
  printjs(tab1, tab2)
  var foo = new Foo()
  printjs(foo)
  var data = new SomeData()
  printjs(data)
  data.f = foo
  printjs(data)

  var tree: Tree
  tree.children |> emplace <| new [[Tree name="a"]]
  var child = new [[Tree name="b", kind=1]]
  child.children |> emplace <| new [[Tree name="c", kind=2]]
  tree.children |> emplace <| child
  printjs(tree)

  printjs(js(j(1u)))
  print(write_json(js(1, "2")))
  print(write_json(js(1, "2", 3)))
  print(write_json(js(1, "2", 3, 4u)))
  print(write_json(js(1, "2", 3, 4u, 5)))
  print(write_json(js(1, "2", 3, 4u, 5, 6)))
  print(write_json(js(1, "2", 3, 4u, 5, 6lf, 7)))
  print(write_json(js(1, "2", 3, 4u, 5, 6lf, 7, 8f)))
  print(write_json(js(1, "2", 3, 4u, 5, 6lf, 7, 8f, 9)))
  print(write_json(js(1, "2", 3, 4u, 5, 6lf, 7, 8f, 9, 10)))
