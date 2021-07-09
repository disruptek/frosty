import std/uri
import std/hashes
import std/times
import std/strutils
import std/streams
import std/intsets
import std/tables
import std/os
import std/random
import std/json
import std/options

import balls
import frosty/streams as brrr

template testFreeze(body: untyped): untyped =
  var ss = newStringStream()
  try:
    freeze(ss, body)
    freeze(ss, body)
    setPosition(ss, 0)
    readAll ss
  finally:
    close ss

template testThaw(body: untyped; into: typed): untyped =
  let ss = newStringStream(body)
  try:
    thaw(ss, into)
    let s = repr(into)
    let r = thaw[typeof(into)](body)
    check r == into, "api insane: " & s & " vs " & repr(r)
  finally:
    close ss

template roundTrip(value: typed): untyped =
  let foo = testFreeze: value
  check foo.len != 0
  var bar: typeof(value)
  check bar == default typeof(bar)
  testThaw(foo, bar)
  check bar == value
  check bar != default typeof(bar)

type
  E = enum One, Two, Three
  W = ref object of RootObj
    a: int
  X = ref object of W
    b: int
  Y = object of RootObj
    a: int
  Z = object of Y
    b: int
  S = distinct string
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
    g: (string, int)
    h: (VType, VType, VType, VType, VType)
    i: seq[string]
    j: Table[string, int]
    k: TableRef[string, int]
    l: IntSet
    m: JsonNode
    n: Uri
    o: seq[int]
    p: Option[F]
    s: S
    t, u: int
    w: W
    x: X
    y: Y
    z: Z

  VType = object
    ignore: bool
    case kind: G
    of Even:
      even: int
    of Odd:
      odd: bool
      case also: uint8
      of 3:
        discard
      of 4:
        omg, wtf, bbq: float
      else:
        `!!!11! whee`: string

proc `==`(a, b: S): bool {.borrow.}

proc `==`(a, b: W | X): bool =
  if a.isNil == b.isNil:
    if a.isNil:
      true
    else:
      a[] == b[]
  else:
    false

suite "frosty basics":
  ## primitive
  roundTrip 46
  ## enum
  roundTrip Two
  ## set
  roundTrip {Two, Three}
  ## string
  roundTrip NimVersion
  ## sequence
  roundTrip @["goats", "pigs"]
  ## named tuple
  roundTrip (food: "pigs", quantity: 43)
  ## naked tuple
  roundTrip ("pigs", 43, 22.0, Three)
  ## distinct
  roundTrip S"snakes"
  ## object
  roundTrip F(x: 4, y: 5.3)
  ## ref inheritance
  roundTrip W(a: 23)
  roundTrip X(a: 48, b: 59)
  ## value inheritance
  roundTrip Y(a: 23)
  roundTrip Z(a: 23, b: 59)

const
  fn {.strdefine.} = "test-data.frosty"

let
  count = when defined(release): 1000 else: 2

proc fileSize(path: string): float =
  when not defined(Windows) or not defined(gcArc):
    # nim bug #15286; no problem outside arc
    result = getFileInfo(path).size.float / (1024*1024)

proc `$`(x: MyType): string {.used.} =
  result = "$1 -> $5, $2 - $3 : $4" % [ $x.c, $x.a, $x.b, $x.j, $x.e, $x.f ]

proc hash*(url: Uri): Hash =
  ## help hash URLs
  var h: Hash = 0
  for field in url.fields:
    when field is string:
      h = h !& field.hash
    elif field is bool:
      h = h !& field.hash
  result = !$h

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

proc hash(t: VType): Hash =
  var h: Hash = 0
  h = h !& hash(t.ignore)
  h = h !& hash(t.kind)
  case t.kind
  of Even:
    h = h !& hash(t.even)
  of Odd:
    h = h !& hash(t.odd)
    h = h !& hash(t.also)
    case t.also
    of 3:
      discard
    of 4:
      h = h !& hash(t.wtf)
      h = h !& hash(t.omg)
      h = h !& hash(t.bbq)
    else:
      h = h !& hash(t.`!!!11! whee`)
  result = !$h

proc hash(s: S): Hash {.borrow.}

proc hash(w: W): Hash =
  if w.isNil:
    raise
  var h: Hash = 0
  h = h !& hash(w.a)
  result = !$h

proc hash(x: X): Hash =
  if x.isNil:
    raise
  var h: Hash = 0
  h = h !& hash(W x)
  h = h !& hash(x.b)
  result = !$h

proc hash(m: MyType): Hash =
  var h: Hash = 0
  h = h !& hash(m.a)
  h = h !& hash(m.b)
  h = h !& hash(m.c)
  h = h !& hash(m.e)
  h = h !& hash(m.f)
  h = h !& hash(m.g)
  h = h !& hash(m.h)
  h = h !& hash(m.i)
  h = h !& hash(m.j)
  h = h !& hash(m.k)
  h = h !& hash(m.l)
  h = h !& hash(m.s)
  h = h !& hash(m.p)
  h = h !& hash(m.t)
  h = h !& hash(m.u)
  when compiles(m.m):
    if m.m != nil:
      h = h !& hash(m.m)
  when compiles(m.n):
    h = h !& hash(m.n)
  h = h !& hash(m.o)
  when compiles(m.w):
    h = h !& hash(m.w)
  when compiles(m.x):
    h = h !& hash(m.x)
  when compiles(m.y):
    h = h !& hash(m.y)
  when compiles(m.z):
    h = h !& hash(m.z)
  result = !$h

proc hash(m: seq[MyType]): Hash {.used.} =
  var h: Hash = 0
  for item in items(m):
    h = h !& hash(item)
  result = !$h

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
                      e: G(n mod 2), m: tJs,
                      j: jj, c: $n, f: F(x: 66, y: 77),
                      p: F(x: 44, y: 33.0).some,
                      i: @["one", "", "", "", "", "", "two"],
                      g: ("hello", 22), s: S("string " & spaces(n)),
                      # ref inheritance
                      w: W(a: 23), x: X(a: 48, b: 59),
                      # value inheritance
                      y: Y(a: 23), z: Z(a: 48, b: 59),
                      # variant objects
                      h: (VType(ignore: true, kind: Even, even: 11),
                          VType(kind: Odd, also: 3),
                          VType(kind: Odd, also: 4, wtf: 5.4, bbq: 6.6),
                          VType(kind: Odd, also: 5, `!!!11! whee`: "lol"),
                          VType(ignore: false, kind: Odd, odd: true)),
                      l: l, k: kk, n: tObj, o: tSeq, t: 55, u: 66)
    if len(result) > 1:
      # link the last item to the previous item
      result[^1].d = result[^2]
    dec n

suite "stress test":
  let vals = makeChunks(count)
  var q: typeof(vals)

  block:
    ## read/write a lot of data
    for mode in [fmWrite, fmRead]:
      var fh = openFileStream(fn, mode)
      try:
        case mode
        of fmWrite:
          suite "writes":
            block:
              ## writing values to stream
              fh.freeze vals
          echo "file size in meg: ", fileSize(fn)
        of fmRead:
          suite "reads":
            block:
              ## reading values from stream
              fh.thaw q
            block:
              ## verify that read data matches
              check len(q) == len(vals)
              for i in vals.low .. vals.high:
                if hash(q[i]) != hash(vals[i]):
                  checkpoint "index: ", i
                  checkpoint " vals: ", vals[i]
                  checkpoint "    q: ", q[i]
                  fail"audit fail"
        else:
          discard
      finally:
        close fh
