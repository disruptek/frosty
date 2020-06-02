import std/hashes
import std/times
import std/strutils
import std/streams
import std/lists
import std/intsets
import std/tables
import std/os

when false:
  when getAppDir().tailDir != "runnableExamples":
    when not defined(release):
      import grok

const
  magic* = 0xBADCAB      ## a magic file value for our "format"

type
  Serializer = object
    stream: Stream
    ptrs: Table[int, pointer]
    when not defined(release):
      indent: int

template refAddr(o: typed): int =
  when o is ref:
    if o == nil: 0 else: cast[int](o)
  else:
    0

proc newSerializer(stream: Stream): Serializer =
  result = Serializer(stream: stream)

when false:
  # also did not work
  template makeListSupportDeclarations(name: untyped): untyped =
    proc write[T](s: Serializer; o: name[T])
    proc read[T](s: Serializer; o: var name[T])

  proc write[T](s: Serializer; o: SinglyLinkedList[T])
  proc read[T](s: Serializer; o: var SinglyLinkedList[T])
  proc write[T](s: Serializer; o: DoublyLinkedList[T])
  proc read[T](s: Serializer; o: var DoublyLinkedList[T])
  proc write[T](s: Serializer; o: SinglyLinkedRing[T])
  proc read[T](s: Serializer; o: var SinglyLinkedRing[T])
  proc write[T](s: Serializer; o: DoublyLinkedRing[T])
  proc read[T](s: Serializer; o: var DoublyLinkedRing[T])

proc write[T](s: var Serializer; o: ref T)
proc read[T](s: var Serializer; o: var ref T)
proc write[T](s: var Serializer; o: T)
proc read[T](s: var Serializer; o: var T)
proc write[T](s: var Serializer; o: seq[T])
proc read[T](s: var Serializer; o: var seq[T])
proc write(s: var Serializer; o: string)
proc read(s: var Serializer; o: var string)

template makeListSupport(name: untyped): untyped =
  when not compiles(len(name)):
    proc len(o: name): int {.used.} =
      for item in items(o):
        inc result

  proc write[T](s: var Serializer; o: name[T]) =
    var l = len(o)           # type inference
    s.write l
    #echo "writing ", l, " items from ", typeof(o)
    # iterate over the list members
    for item in items(o):    #
      # write the value from the node object
      s.write item.value
      dec l
    assert l == 0

  proc read[T](s: var Serializer; o: var name[T]) =
    o = `init name`[T]()
    var l = len(o)           # type inference
    s.read l
    #echo "reading ", l, " items from ", typeof(o)
    while l > 0:
      var value: T
      s.read value
      o.append value
      dec l

# generate serialize/deserialize for some linked lists and rings
makeListSupport SinglyLinkedList
makeListSupport DoublyLinkedList
makeListSupport SinglyLinkedRing
makeListSupport DoublyLinkedRing

proc write(s: var Serializer; o: string) =
  write(s.stream, len(o))   # put the str len
  write(s.stream, o)        # put the str data

proc read(s: var Serializer; o: var string) =
  var l = len(o)            # type inference
  read(s.stream, l)         # get the str len
  o = readStr(s.stream, l)  # get the str data
  assert o.len == l

template greatenIndent*(s: var Serializer; body: untyped): untyped =
  when not defined(release):
    s.indent = s.indent + 2
  body
  when not defined(release):
    s.indent = s.indent - 2

template debung*(s: Serializer; msg: string): untyped =
  when defined(debug):
    when not defined(release):
      echo spaces(s.indent) & msg

template writeComplex(s: var Serializer; o: object | tuple) =
  s.greatenIndent:
    s.debung $typeof(o) & " .. " & $refAddr(o)
    for k, val in fieldPairs(o):
      block wrote:
        when val is int:
          s.debung ".$1 $2 $3" % [ $k, $typeof(val), $val ]
        elif val is string:
          s.debung ".$1 $2 $3" % [ $k, $typeof(val), $val ]
        elif val is float:
          s.debung ".$1 $2 $3" % [ $k, $typeof(val), $val ]
        elif val is pointer:
          s.debung ".$1 $2 $3" % [ $k, $typeof(val), $val ]
        else:
          s.debung ".$1 $2 $3" % [ $k, $typeof(val), $refAddr(val) ]
        s.write val

template readComplex[T: object | tuple](s: var Serializer;
                     o: var T) =
  for k, v in fieldPairs(o):
    s.read v

type
  Chunk = object
    p: int
    when not defined(release):
      h: Hash

template audit(o: typed; p: typed): Hash =
  when defined(release):
    0
  else:
    when compiles(hash(o)):
      hash(o)
    elif compiles(hash(o[])):
      hash(o[])
    else:
      hash(p)

proc write[T](s: var Serializer; o: ref T) =
  # compute p and store it
  var g = Chunk(p: refAddr(o))
  s.debung $typeof(o) & " " & $g.p
  # if it's nonzero, also compute hash
  if g.p != 0:
    when compiles(g.h):
      g.h = audit(o, g.p)
      assert g.h != 0

  # write the preamble
  s.write g
  if g.p != 0:
    if g.p notin s.ptrs:
      # we haven't written the value for this address yet,
      # so record that this memory was seen,
      s.ptrs[g.p] = cast[pointer](o)
      # and write it now
      s.write o[]

proc read[T](s: var Serializer; o: var ref T) =
  var
    g: Chunk
  s.read g
  if g.p == 0:
    o = nil
  else:
    if g.p in s.ptrs:
      o = cast[ref T](s.ptrs[g.p])
    else:
      o = new (ref T)
      s.ptrs[g.p] = cast[pointer](o)
      s.read o[]
    when compiles(g.h):
      assert g.h == audit(o, g.p)

proc write[T](s: var Serializer; o: seq[T]) =
  runnableExamples:
    # start with some data
    var q = @[1, 1, 2, 3, 5]
    # prepare a string
    var s: string
    # write the data into the string
    s.writeThing q
    # check that it matches our expectation
    assert len(s) == sizeof(magic) + sizeof(0) + 5*sizeof(0)
    # prepare a new seq to hold some data
    var l: seq[int]
    # populate the seq using the string as input
    s.readThing l
    # confirm that the two sequences of data match
    assert l == q

  s.write len(o)
  for item in items(o):
    s.write item

proc read[T](s: var Serializer; o: var seq[T]) =
  var l = len(o)          # type inference
  s.read l                # get the len of the seq
  o.setLen(l)             # pre-alloc the sequence
  for item in mitems(o):  # iterate over mutable items
    s.read item           # read into the item

# simple types are, uh, simple
proc write[T](s: var Serializer; o: T) =
  when T is object:
    writeComplex(s, o)
  elif T is tuple:
    writeComplex(s, o)
  else:
    write(s.stream, o)

proc read[T](s: var Serializer; o: var T) =
  when T is object:
    readComplex(s, o)
  elif T is tuple:
    readComplex(s, o)
  else:
    read(s.stream, o)

proc writeThing*[T](stream: Stream; o: T) =
  var
    s = newSerializer(stream)
  s.write magic
  s.write o

proc readThing*[T](stream: Stream; o: var T) =
  var
    version: int
  stream.read version
  case version
  of magic:
    var
      s = newSerializer(stream)
    s.read o
  else:
    raise newException(Defect, "bad voodoo")

proc writeThing*[T](str: var string; o: T) =
  runnableExamples:
    import uri
    # start with some data
    var q = parseUri"https://github.org/nim-lang/Nim"
    # prepare a string
    var s: string
    # write the data into the string
    s.writeThing q
    # prepare a new url object
    var url: Uri
    # populate the url using the string as input
    s.readThing url
    # confirm that two objects match
    assert url == q

  var
    ss = newStringStream(str)
  ss.writeThing o
  ss.setPosition 0
  str = readAll(ss)
  close ss

proc readThing*[T](str: string; o: var T) =
  var
    ss = newStringStream(str)
  ss.readThing o
  close ss

when isMainModule:
  import std/random

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

  proc fileSize(path: string): float =
    result = getFileInfo(path).size.float / (1024*1024)

  proc `$`(x: MyType): string {.used.} =
    result = "$1 -> $5, $2 - $3 : $4" % [ $x.c, $x.a, $x.b, $x.j, $x.e, $x.f ]

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

  const objects = 7_500
  echo "will test against " & $objects & " units"

  when false: #defined(danger):
    import std/uri
    import criterion

    template writeSomething*(ss: Stream; w: typed): untyped =
      ss.setPosition 0
      when objects == 1:
        ss.writeThing w
      else:
        for i in 1 .. objects:
          ss.writeThing w

    template readSomething*(ss: Stream; w: typed): untyped =
      var
        r: typeof(w)
      ss.setPosition 0
      when objects == 1:
        ss.readThing r
      else:
        for i in 1 .. objects:
          ss.readThing r
      r

    const
      tSeq = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      tString = "https://irclogs.nim-lang.org/01-06-2020.html#20:54:23"
      tObj = parseUri(tString)
    var
      tIntset = initIntSet()
    for i in 0 .. 10:
      tIntset.incl i

    var cfg = newDefaultConfig()
    cfg.budget = 0.5

    benchmark cfg:
      var
        ss = newStringStream()

      proc write_seq() {.measure.} =
        ss.writeSomething tSeq

      proc read_seq() {.measure.} =
        discard ss.readSomething tSeq

      proc write_string() {.measure.} =
        ss.writeSomething tString

      proc read_string() {.measure.} =
        discard ss.readSomething tString

      proc write_obj() {.measure.} =
        ss.writeSomething tObj

      proc read_obj() {.measure.} =
        discard ss.readSomething tObj

      proc write_intset() {.measure.} =
        ss.writeSomething tIntset

      proc read_intset() {.measure.} =
        let r = ss.readSomething tIntset

  else:  # ^^ danger      vv no danger

    proc makeChunks(n: int): seq[MyType] =
      var n = n
      while n > 0:
        let jj = toTable {$n: n, $(n+1): n*2}
        let kk = newTable {$n: n, $(n+1): n*2}
        var l = initIntSet()
        for i in 0 .. 100:
          l.incl rand(int.high)
        result.add MyType(a: rand(int n), b: rand(float n),
                          e: G(n mod 2),
                          j: jj, c: $n, f: F(x: 66, y: 77),
                          l: l, k: kk)
        if len(result) > 1:
          result[^1].d = result[^2]
        dec n

    const
      fn = "goats"

    echo "makin' goats..."
    let vals = makeChunks(objects)

    if not fileExists(fn):
      var fh = openFileStream(fn, fmWrite)
      timer "write some goats":
        writeThing(fh, vals)
      close fh
      echo "file size in meg: ", fileSize(fn)
    else:
      var q: typeof(vals)
      var fh = openFileStream(fn, fmRead)
      timer "read some goats":
        readThing(fh, q)
      close fh
      assert hash(q) == hash(vals)
