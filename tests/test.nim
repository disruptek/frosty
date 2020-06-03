import std/uri
import std/hashes
import std/times
import std/strutils
import std/streams
import std/lists
import std/intsets
import std/tables
import std/os
import std/random
import std/json

import frosty

const
  fn {.strdefine.} = "goats"

let
  mode = if paramCount() < 1: "write" else: paramStr(1)
  count = if paramCount() < 2: 1 else: parseInt paramStr(2)

echo "testing " & mode & " against " & $count & " units in " & fn

type
  G = enum
    Even
    Odd
  F = object
    x: int
    y: float
  MyType = ref object
    a: int
    b: float
    c: string
    d: MyType
    e: G
    f: F
    j: Table[string, int]
    k: TableRef[string, int]
    l: IntSet
    m: JsonNode

proc fileSize(path: string): float =
  result = getFileInfo(path).size.float / (1024*1024)

proc `$`(x: MyType): string {.used.} =
  result = "$1 -> $5, $2 - $3 : $4" % [ $x.c, $x.a, $x.b, $x.j, $x.e, $x.f ]

proc hash(o: object): Hash =
  var h: Hash = 0
  for k, v in fieldPairs(o):
    h = h !& hash(v)
  result = !$h

proc hash(m: F): Hash =
  var h: Hash = 0
  h = h !& hash(m.x)
  h = h !& hash(m.y)
  result = !$h

proc hash(l: IntSet): Hash =
  var h: Hash = 0
  for i in items(l):
    h = h !& hash(i)
  result = !$h

proc hash[A, B](t: Table[A, B]): Hash =
  var h: Hash = 0
  for k, v in t.pairs:
    h = h !& hash(k)
    h = h !& hash(v)
  result = !$h

proc hash[A, B](t: TableRef[A, B]): Hash =
  var h: Hash = 0
  if t != nil:
    for k, v in t.pairs:
      h = h !& hash(k)
      h = h !& hash(v)
  result = !$h

proc hash(m: MyType): Hash =
  var h: Hash = 0
  h = h !& hash(m.a)
  h = h !& hash(m.b)
  h = h !& hash(m.c)
  h = h !& hash(m.e)
  h = h !& hash(m.f)
  h = h !& hash(m.j)
  h = h !& hash(m.k)
  h = h !& hash(m.l)
  when compiles(m.m):
    if m.m != nil:
      h = h !& hash(m.m)
  result = !$h

proc hash(m: seq[MyType]): Hash =
  var h: Hash = 0
  for item in items(m):
    h = h !& hash(item)
  result = !$h

template timer(name: string; body: untyped): untyped =
  var clock = cpuTime()
  try:
    body
    echo name, " took ", cpuTime() - clock
  except CatchableError as e:
    echo e.msg
    echo name, " failed after ", cpuTime() - clock

let
  tJs = %* {
    "goats": ["pigs", "horses"],
    "sheep": 11,
    "ducks": 12.0,
    "dogs": "woof",
    "cats": false,
    "frogs": { "toads": true, "rats": "yep" },
  }

const
  tSeq = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  tString = "https://irclogs.nim-lang.org/01-06-2020.html#20:54:23"
  tObj = parseUri(tString)
var
  tIntset = initIntSet()
for i in 0 .. 10:
  tIntset.incl i

proc makeChunks(n: int): seq[MyType] =
  var n = n
  while n > 0:
    let jj = toTable {$n: n, $(n+1): n*2}
    let kk = newTable {$n: n, $(n+1): n*2}
    var l = initIntSet()
    for i in 0 .. 40:
      l.incl rand(int.high)
    result.add MyType(a: rand(int n), b: rand(float n),
                      e: G(n mod 2), #m: tJs,
                      j: jj, c: $n, f: F(x: 66, y: 77),
                      l: l, k: kk)
    if len(result) > 1:
      # link the last item to the previous item
      result[^1].d = result[^2]
    dec n

let vals = makeChunks(count)

if mode == "write":
  var fh = openFileStream(fn, fmWrite)
  timer "write some goats":
    freeze(vals, fh)
  close fh
  echo "file size in meg: ", fileSize(fn)
else:
  if not fileExists(fn):
    echo "no input to read"
    quit(1)
  var q: typeof(vals)
  var fh = openFileStream(fn, fmRead)
  timer "read some goats":
    thaw(fh, q)
  close fh
  for i in vals.low .. vals.high:
    if hash(q[i]) != hash(vals[i]):
      echo "index: ", i
      echo " vals: ", vals[i]
      echo "    q: ", q[i]
      quit(1)
