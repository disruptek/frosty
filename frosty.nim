import std/net
import std/streams
import std/tables

# we'll only check hashes during debug builds
when not defined(release):
  import std/strutils
  import std/hashes

const
  frostyMagic* {.intdefine.} = 0xBADCAB ##
  ## A magic file value for our "format".

  enableLists = false

type
  FreezeError* = ValueError  ##
  ## An error raised during `freeze`. (unused)
  ThawError* = ValueError    ##
  ## An error raised during `thaw`.

  Serializer[T] = object
    stream: T
    ptrs: Table[int, pointer]
    when not defined(release):
      indent: int

  Cube = object
    p: int
    when not defined(release):
      h: Hash

# convenience to make certain calls more legible
template socket(s: Serializer): Socket = s.stream

template refAddr(o: typed): int =
  when o is ref:
    if o == nil: 0 else: cast[int](o)
  else:
    0

proc newSerializer[S](source: S): Serializer[S] {.raises: [].} =
  result = Serializer[S](stream: source)

proc write[S, T](s: var Serializer[S]; o: ref T; parent = 0)
proc read[S, T](s: var Serializer[S]; o: var ref T)
proc write[S, T](s: var Serializer[S]; o: T; parent = 0)
proc read[S, T](s: var Serializer[S]; o: var T)
proc write[S, T](s: var Serializer[S]; o: seq[T])
proc read[S, T](s: var Serializer[S]; o: var seq[T])
proc write(s: var Serializer[Stream]; o: string)
proc read(s: var Serializer[Stream]; o: var string)
proc write(s: var Serializer[Socket]; o: string)
proc read(s: var Serializer[Socket]; o: var string)

when enableLists:
  import std/lists

  template makeListSupport(name: untyped): untyped =
    proc write[T](s: var Serializer; o: name[T]) =
      when compiles(len(o)):
        var l = len(o)           # type inference
      else:
        var l = 0
        for item in items(o):
          inc l

      s.write l
      for item in items(o):
        s.write item.value
        dec l
      assert l == 0

    proc read[T](s: var Serializer; o: var name[T]) =
      o = `init name`[T]()
      when compiles(len(o)):
        var l = len(o)           # type inference
      else:
        var l = 0
      s.read l
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

template greatenIndent(s: var Serializer; body: untyped): untyped =
  ## Used for debugging.
  when not defined(release):
    s.indent = s.indent + 2
    defer:
      s.indent = s.indent - 2
  body

template debung(s: Serializer; msg: string): untyped =
  ## Used for debugging.
  when not defined(release):
    when not defined(nimdoc):
      echo spaces(s.indent) & msg

when not defined(nimdoc):
  export greatenIndent, debung

template audit(o: typed; g: typed) =
  when defined(release):
    discard
  else:
    # if it's a pointer,
    if g.p != 0:
      # compute a hash
      let h =
        when compiles(hash(o)):
          hash(o)
        elif compiles(hash(o[])):
          hash(o[])
        else:
          hash(g.p)
      # if we read a hash,
      if g.h != 0:
        # check it,
        assert g.h == h
      else:
        # else, save it
        g.h = h

proc write(s: var Serializer[Stream]; o: string) =
  write(s.stream, len(o))   # put the str len
  write(s.stream, o)        # put the str data

proc read(s: var Serializer[Stream]; o: var string) =
  var l = len(o)            # type inference
  read(s.stream, l)         # get the str len
  o = readStr(s.stream, l)  # get the str data

proc write(s: var Serializer[Socket]; o: string) =
  var l = len(o)            # type inference
  # send the length of the string
  if send(s.socket, data = addr l, size = sizeof(l)) != sizeof(l):
    raise newException(FreezeError, "short write; socket closed?")
  # send the string itself; this can raise...
  send(s.socket, data = o)

proc read(s: var Serializer[Socket]; o: var string) =
  var l = len(o)            # type inference
  # receive the string size
  if recv(s.socket, data = addr l, size = sizeof(l)) != sizeof(l):
    raise newException(ThawError, "short read; socket closed?")
  # for the following recv(), "data must be initialized"
  setLen(o, l)
  # receive the string
  if recv(s.socket, data = o, size = l) != l:
    raise newException(ThawError, "short read; socket closed?")

proc write[S, T](s: var Serializer[S]; o: ref T; parent = 0) =
  # compute p and store it
  var g = Cube(p: refAddr(o))
  # if it's nonzero, also compute hash
  audit(o, g)

  # write the preamble
  s.write g
  if g.p != 0:
    if g.p notin s.ptrs:
      # we haven't written the value for this address yet,
      # so record that this memory was seen,
      s.ptrs[g.p] = cast[pointer](o)
      # and write it now
      if g.p != parent:
        s.write o[], parent = g.p
      else:
        raise

proc read[S, T](s: var Serializer[S]; o: var ref T) =
  var
    g: Cube
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
      # after you read it, check the hash
      audit(o, g)

proc write[S, T](s: var Serializer[S]; o: seq[T]) =
  runnableExamples:
    # start with some data
    var q = @[1, 1, 2, 3, 5]
    # prepare a string
    var s: string
    # write the data into the string
    s.freeze q
    # check that it matches our expectation
    assert len(s) == sizeof(frostyMagic) + sizeof(0) + 5*sizeof(0)
    # prepare a new seq to hold some data
    var l: seq[int]
    # populate the seq using the string as input
    s.thaw l
    # confirm that the two sequences of data match
    assert l == q

  s.write len(o)
  for item in items(o):
    s.write item

proc read[S, T](s: var Serializer[S]; o: var seq[T]) =
  var l = len(o)          # type inference
  s.read l                # get the len of the seq
  o.setLen(l)             # pre-alloc the sequence
  for item in mitems(o):  # iterate over mutable items
    s.read item           # read into the item

proc writePrimitive[T](s: var Serializer[Stream]; o: T) =
  write(s.stream, o)

proc writePrimitive[T](s: var Serializer[Socket]; o: T) =
  if send(s.socket, data = addr o, size = sizeof(o)) != sizeof(o):
    raise newException(FreezeError, "short write; socket closed?")

proc write[S, T](s: var Serializer[S]; o: T; parent = 0) =
  when T is object or T is tuple:
    #s.debung $typeof(o)
    s.greatenIndent:
      for k, val in fieldPairs(o):
        when val is ref:
          s.write val, parent = parent
        else:
          s.write val
        #let q = repr(val)
        #s.debung k & ": " & $typeof(val) & " = " & q[low(q)..min(20, high(q))]
  else:
    writePrimitive(s, o)

proc readPrimitive[T](s: var Serializer[Stream]; o: var T) =
  read(s.stream, o)

proc readPrimitive[T](s: var Serializer[Socket]; o: var T) =
  if recv(s.socket, data = addr o, size = sizeof(o)) != sizeof(o):
    raise newException(ThawError, "short read; socket closed?")

proc read[S, T](s: var Serializer[S]; o: var T) =
  when T is object or T is tuple:
    #s.debung $typeof(o)
    s.greatenIndent:
      for k, val in fieldPairs(o):
        {.push fieldChecks: off.}
        # work around variant objects?
        var x = val
        s.read x
        val = x
        #let q = repr(val)
        #s.debung k & ": " & $typeof(val) & " = " & q[low(q)..min(20, high(q))]
        {.pop.}
  else:
    readPrimitive(s, o)

proc freeze*[T](o: T; socket: Socket) =
  ## Send `o` via `socket`.
  ##
  ## A "magic" value will be written, first.
  var s = newSerializer(socket)
  s.write frostyMagic
  s.write o

proc freeze*[T](o: T; stream: Stream) =
  ## Write `o` into `stream`.
  ##
  ## A "magic" value will be written, first.
  var s = newSerializer(stream)
  s.write frostyMagic
  s.write o

proc freeze*[T](o: T; str: var string) =
  ## Write `o` into `str`.
  ##
  ## A "magic" value will prefix the result.
  runnableExamples:
    import uri
    # start with some data
    var q = parseUri"https://github.org/nim-lang/Nim"
    # prepare a string
    var s: string
    # write the data into the string
    freeze(q, s)
    # prepare a new url object
    var url: Uri
    # populate the url using the string as input
    thaw(s, url)
    # confirm that two objects match
    assert url == q

  var ss = newStringStream(str)
  freeze(o, ss)
  setPosition(ss, 0)
  str = readAll(ss)
  close ss

proc freeze*[T](o: T): string =
  ## Turn `o` into a string.
  ##
  ## A "magic" value will prefix the result.
  runnableExamples:
    import uri
    # start with some data
    var q = parseUri"https://github.org/nim-lang/Nim"
    # freeze `q` into `s`
    var s = freeze(q)
    # thaw `s` into `u`
    var u = thaw[Uri](s)
    # confirm that two objects match
    assert u == q

  freeze(o, result)

proc thaw*[T](stream: Stream; o: var T) =
  ## Read `o` from `stream`.
  ##
  ## First, a "magic" value will be read.  A `ThawError`
  ## will be raised if the magic value is not as expected.
  var version: int
  stream.read version
  if version != frostyMagic:
    raise newException(ThawError, "expected magic " & $frostyMagic)
  else:
    var s = newSerializer(stream)
    s.read o

proc thaw*[T](socket: Socket; o: var T) =
  ## Receive `o` from `socket`.
  ##
  ## First, a "magic" value will be read.  A `ThawError`
  ## will be raised if the magic value is not as expected.
  var v: int
  if recv(socket, data = addr v, size = sizeof(v)) != sizeof(v):
    raise newException(ThawError, "short read; socket closed?")
  if v != frostyMagic:
    raise newException(ThawError, "expected magic " & $frostyMagic)
  else:
    var s = newSerializer(socket)
    s.read o

proc thaw*[T](str: string; o: var T) =
  ## Read `o` from `str`.
  ##
  ## A "magic" value must prefix the input string.
  var ss = newStringStream(str)
  thaw(ss, o)
  close ss

proc thaw*[T](str: string): T =
  ## Read value of `T` from `str`.
  ##
  ## A "magic" value must prefix the input string.
  thaw(str, result)
