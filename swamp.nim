import std/times
import std/strutils
import std/streams
import std/lists
import std/intsets

const
  refsAreSpecial = true

type
  Serializer = object
    stream: Stream
    refs: IntSet

template write(s: Serializer; v: typed) =
  write(s.stream, v)

template read(s: Serializer; v: typed) =
  read(s.stream, v)

template readStr(s: Serializer; l: int): string =
  readStr(s.stream, l)

when false:
  # did not work out
  type
    ObjectLike = object or tuple

when false:
  # also did not work
  template makeListSupportDeclarations(name: untyped): untyped =
    proc writeThing*[T](s: Serializer; o: name[T])
    proc readThing*[T](s: Serializer; o: var name[T])

  proc writeThing*[T](s: Serializer; o: SinglyLinkedList[T])
  proc readThing*[T](s: Serializer; o: var SinglyLinkedList[T])
  proc writeThing*[T](s: Serializer; o: DoublyLinkedList[T])
  proc readThing*[T](s: Serializer; o: var DoublyLinkedList[T])
  proc writeThing*[T](s: Serializer; o: SinglyLinkedRing[T])
  proc readThing*[T](s: Serializer; o: var SinglyLinkedRing[T])
  proc writeThing*[T](s: Serializer; o: DoublyLinkedRing[T])
  proc readThing*[T](s: Serializer; o: var DoublyLinkedRing[T])

proc writeThing*[T](s: Serializer; o: seq[T])
proc readThing*[T](s: Serializer; o: var seq[T])
when refsAreSpecial:
  proc writeThing*[T](s: var Serializer; o: ref T)
  proc readThing*[T](s: var Serializer; o: var ref T)
proc writeThing*(s: Serializer; o: string)
proc readThing*(s: Serializer; o: var string)

template makeListSupport(name: untyped): untyped =
  when not compiles(len(name)):
    proc len(o: name): int {.used.} =
      for item in o.items:
        inc result

  proc writeThing*[T](s: Serializer; o: name[T]) =
    var l = len(o)
    s.write l
    #echo "writing ", l, " items from ", typeof(o)
    # iterate over the list members
    for item in o.items:
      # write the value from the node object
      s.writeThing item.value
      dec l
    assert l == 0

  proc readThing*[T](s: Serializer; o: var name[T]) =
    o = `init name`[T]()
    var l = len(o) # type inference
    s.read l
    while l > 0:
      var value: T
      s.readThing value
      o.append value
      dec l

# generate serialize/deserialize for some linked lists and rings
makeListSupport SinglyLinkedList
makeListSupport DoublyLinkedList
makeListSupport SinglyLinkedRing
makeListSupport DoublyLinkedRing

proc writeThing*(s: Serializer; o: string) =
  s.write len(o)
  s.write o

proc readThing*(s: Serializer; o: var string) =
  var l = len(o) # type inference
  s.read l
  o = s.readStr l
  assert o.len == l

proc writeObject*[T](s: Serializer; o: T) =
  #echo "write an object ", typeof(o)
  for k, val in o.fieldPairs:
    #echo "w" & k
    s.writeThing val

proc readObject*[T](s: Serializer; o: var T) =
  for k, v in o.fieldPairs:
    #echo "r" & k
    # XXX: because bug
    var x = v
    s.readThing x
    v = x

proc writeThing*[T](s: Serializer; o: T) =
  #echo "write a thing ", typeof(o)
  when T is object:
    s.writeObject o
  elif T is tuple:
    s.writeObject o
  else:
    s.write o

proc readThing*[T](s: Serializer; o: var T) =
  when T is object:
    #echo "read an object ", typeof(o)
    s.readObject o
  elif T is tuple:
    #echo "read a tuple ", typeof(o)
    s.readObject o
  else:
    s.read o

when refsAreSpecial:
  proc writeThing*[T](s: var Serializer; o: ref T) =
    #echo "write a ref ", typeof(o)
    let
      p = if o == nil: 0 else: cast[int](o)
    s.writeThing p
    if p != 0 and p notin s.refs:
      incl s.refs, p
      echo "added ", p
      s.writeThing o[]

  proc readThing*[T](s: var Serializer; o: var ref T) =
    #echo "read a ", typeof(o)
    var
      p: int
    s.readThing p
    if p != 0:
      if p in s.refs:
        echo "repeat"
      incl s.refs, p
      o = new (ref T)
      s.readThing o[]
    else:
      o = nil

proc writeThing*[T](s: Serializer; o: seq[T]) =
  s.write len(o)
  for item in o.items:
    s.writeThing item

proc readThing*[T](s: Serializer; o: var seq[T]) =
  var l = len(o) # type inference
  s.read l
  o.setLen(l)
  for item in o.mitems:
    s.readThing item

proc writeThing*[T](stream: Stream; o: T) =
  var
    s = Serializer(stream: stream, refs: initIntSet())
  s.writeThing o

proc readThing*[T](stream: Stream; o: var T) =
  var
    s = Serializer(stream: stream, refs: initIntSet())
  s.readThing o

when isMainModule:
  import std/random
  import std/times
  import std/strutils
  import std/hashes
  import std/tables
  import std/os

  import criterion

  type
    G = enum
      Even
      Odd
    F = object
      x: int
      y: float
    MyType = object
      a: int
      b: float
      c: string
      e: G
      f: F
      j: Table[string, int]
      k: TableRef[string, int]

  proc fileSize(path: string): float =
    result = getFileInfo(path).size.float / (1024*1024)

  randomize()

  proc `$`(x: MyType): string {.used.} =
    result = "$1 -> $5, $2 - $3 : $4" % [ $x.c, $x.a, $x.b, $x.j, $x.e, $x.f ]
  var cfg = newDefaultConfig()

  benchmark cfg:
    proc hash(m: F): Hash =
      var h: Hash = 0
      h = h !& hash(m.x)
      h = h !& hash(m.y)
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
      result = !$h

    proc hash(m: seq[MyType]): Hash =
      var h: Hash = 0
      for item in m.items:
        h = h !& hash(item)
      result = !$h

    template timer(name: string; body: untyped): untyped =
      var clock = cpuTime()
      body
      echo name, " took ", cpuTime() - clock

    const objects = 300_000

    var fh: FileStream
    var h: Hash

    var vals: seq[MyType]
    proc makeGoats(n: int) =
      var n = n
      while n > 0:
        let jj = {$n: n, $(n+1): n*2}.toTable
        let kk = {$n: n, $(n+1): n*2}.newTable
        assert kk.len == 2
        vals.add MyType(a: rand(int n), b: rand(float n),
                        e: G(n mod 2),
                        j: jj, c: $n, f: F(x: 66, y: 77),
                        k: kk)
        dec n

    timer "blame it on the goats":
      makeGoats(objects)

    timer "read goats hash":
      h = hash(vals)

    const
      fn = "goats"
    when true:
      fh = openFileStream(fn, fmWrite)
      timer "write some goats":
        for x in vals.items:
          #echo "write ", x
          fh.writeThing x
      fh.flush
      fh.close

      fh = openFileStream(fn, fmRead)
      fh.setPosition 0
      timer "read some goats from a file":
        while not fh.atEnd:
          var x = MyType()
          fh.readThing x
          #echo "read ", x
      fh.close
      echo "file size in meg: ", fileSize(fn)

      when true:
        fh = openFileStream(fn, fmRead)
        let data = fh.readAll
        fh.close
        timer "read some goats from a string":
          var ss = newStringStream(data)
          while not ss.atEnd:
            var x = MyType()
            ss.readThing x
            #echo "read ", x
          ss.close

      when true:
        var q: seq[MyType]
        q.setLen(vals.len)
        fh = openFileStream(fn, fmRead)
        while not fh.atEnd:
          var x = MyType()
          fh.readThing x
          q.add x
        fh.close

        timer "check hash of goats":
          assert hash(q) == h
