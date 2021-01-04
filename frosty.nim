import std/typetraits
import std/macros
import std/streams

import cps
import cps/eventqueue

const
  frostyDebug* {.booldefine.} = false
  frostySorted* {.booldefine.} = false
  frostyNet* {.booldefine.} = true

# we'll only check hashes during debug builds
when frostyDebug:
  import std/strutils
  import std/hashes
  type
    Ice = object
      p: int
      h: Hash
else:
  type
    Ice = object
      p: int

when frostySorted:
  when frostyDebug:
    {.hint: "frosty using sorta".}
  import sorta

  type
    Serializer[T] = ref object of Cont
      stream: T
      stack: seq[pointer]
      ptrs: SortedTable[int, pointer]
      when frostyDebug:
        indent: int

else:
  when frostyDebug:
    {.hint: "frosty using stdlib".}
  import std/tables

  type
    Serializer[T] = ref object of Cont
      stream: T
      stack: seq[pointer]
      ptrs: Table[int, pointer]
      pos: int
      when frostyDebug:
        indent: int

type
  FreezeError* = ValueError  ##
  ## An error raised during `freeze`.
  ThawError* = ValueError    ##
  ## An error raised during `thaw`.

template refAddr(o: typed): int =
  when o is ref:
    if o.isNil: 0 else: cast[int](o)
  else:
    0

proc write[S, T](s: var Serializer[S]; o: ref T; parent = 0)
proc read[S, T](s: var Serializer[S]; o: var ref T)
proc writeSequence[S, T](s: var Serializer[S]; o: seq[T])
proc readSequence[S, T](s: var Serializer[S]; o: var seq[T])
proc writeString[T](s: var Serializer[Stream]; o: T)
proc readString[T](s: var Serializer[Stream]; o: var T)
proc readPrimitive[T](s: var Serializer[Stream]; o: var T)
proc writePrimitive[T](s: var Serializer[Stream]; o: T)
proc readTuple[S, T](s: var Serializer[S]; o: var T; skip = "")
proc writeTuple[S, T](s: var Serializer[S]; o: T; skip = ""; parent = 0)

type
  Bytes = concept c
    len(c) is int
    sizeof(c[int]) == sizeof(byte)
    setLen(c, int)                      ## arrays unsupported (yet)

  Bs = concept c
    c[] is Bytes

  Copy = concept c
    supportsCopyMem c
    c isnot string

  Other = not(string or Copy)           ## not copyable

proc newSerializer[S](source: S): auto {.raises: [].} =
  when source is Bytes:
    result = Serializer[ptr S](stream: unsafeAddr source)
  else:
    result = Serializer[S](stream: source)

template head(s: Bytes): pointer = unsafeAddr s[0]
template head(p: not Bytes): pointer = unsafeAddr p

# pointer reads; can't use Bytes because dumb
proc `{}`(s: string or seq; index: int): pointer =
  unsafeAddr s[index]
proc `{}`(s: string or seq; index: BackwardsIndex): pointer =
  unsafeAddr s[len(s) - index.int]
proc `{}`[T: Bs](s: Serializer[T];
                 pos: int or BackwardsIndex): pointer =
  s.stream[]{pos}

# pointer writes
template `[]=`(s: Serializer[Bs]; pos: untyped; o: typed) =
  cast[ptr typeof o](s{pos})[] = o
proc assign[T](o: var T; s: pointer) =
  o = cast[ptr T](s)[]
proc grow[T: Bs](s: Serializer[T]; n: int) =
  setLen(s.stream[], len(s.stream[]) + n)

template willWrite(s: Serializer[Bs]; n: int; body: untyped) =
  ## maybe perform a write and ensure we have enough output to do so
  if n > 0:
    grow(s, n)
    body

template willRead(s: Serializer[Bs]; n: int; body: untyped) =
  ## maybe perform a read and ensure we have enough input to do so
  if n > 0:
    if s.pos > len(s.stream[]) - n:
      raise newException(ThawError, $(len(s.stream[]) - s.pos) &
                                    " bytes left; need " & $n)
    else:
      body
      inc s.pos, n

proc write[T: Copy or Other](s: var Serializer[Bs]; o: T) =
  const l = sizeof o
  s.willWrite l:
    when o is Copy:
      copyMem(s{^l}, head o, l)
    elif o is Other:
      s[^l] = o
    else:
      {.error: $T & " is not supported by frosty".}

proc read[T: Copy or Other](s: var Serializer[Bs]; o: var T) =
  const l = sizeof o
  s.willRead l:
    when o is Copy:
      copyMem(head o, s{s.pos}, l)
    elif o is Other:
      o.assign s{s.pos}
    else:
      {.error: $T & " is not supported by frosty".}

proc write[T: string](s: var Serializer[Bs]; o: T) =
  var l = len o
  s.write l
  s.willWrite l:
    copyMem(s{^l}, head o, l)

proc read[T: string](s: var Serializer[Bs]; o: var T) =
  var l = len o
  s.read l
  s.willRead l:
    o.setLen l
    copyMem(head o, s{s.pos}, l)

proc write[T: not Copy](s: var Serializer[Bs]; o: seq[T]) =
  template n: int = len o
  s.write n
  # XXX: optimize a grow here?
  for n in o.items:
    s.write n

proc read[T: not Copy](s: var Serializer[Bs]; o: var seq[T]) =
  var n = len o
  s.read n
  o.setLen n
  for i in 0 ..< n:
    s.read o[i]

proc write[T: Copy](s: var Serializer[Bs]; o: seq[T]) =
  const l = sizeof T
  template z: int = l * o.len
  s.write o.len
  s.willWrite z:
    copyMem(s{^z}, head o, z)

proc read[T: Copy](s: var Serializer[Bs]; o: var seq[T]) =
  const l = sizeof T
  var n = len o
  template z: int = l * n
  s.read n
  o.setLen n
  s.willRead z:
    copyMem(head o, s{s.pos}, z)

# support for the macros
proc writePrimitive[T](s: var Serializer[Bs]; o: T) = s.write o
proc readPrimitive[T](s: var Serializer[Bs]; o: var T) = s.read o
proc writeSequence[T](s: var Serializer[Bs]; o: T) = s.write o
proc readSequence[T](s: var Serializer[Bs]; o: var T) = s.read o
proc writeString[T](s: var Serializer[Bs]; o: T) = s.write o
proc readString[T](s: var Serializer[Bs]; o: var T) = s.read o

# (try to) ignore the string->string conversion warning
{.push hint[ConvFromXtoItselfNotNeeded]: off.}

when frostyNet:
  import std/net

  proc writeString[T](s: var Serializer[Socket]; o: T)
  proc readString[T](s: var Serializer[Socket]; o: var T)
  proc readPrimitive[T](s: var Serializer[Socket]; o: var T)

  # convenience to make certain calls more legible
  template socket(s: Serializer): Socket = s.stream

template parentEq(parent: NimNode): NimNode =
  nnkExprEqExpr.newTree(ident"parent", parent)

macro writeObject[S, T](s: var Serializer[S]; o: T; parent = 0) =
  # do nothing by default
  result = newEmptyNode()
  let
    writeTuple = bindSym"writeTuple"
    writer = bindSym("writePrimitive", rule = brClosed)
    typ = o.getTypeImpl
  when defined(frostyDebug):
    echo typ.treeRepr
    echo typ.repr
  let variant = findChild(typ[^1], it.kind == nnkRecCase)
  if variant.isNil:
    # it's a simple named tuple/object
    result = newCall(writeTuple, s, o)
  else:
    let
      name = variant[0][0]   # the symbol of the discriminator
    result = newStmtList()
    # write the value of the discriminator
    result.add newCall(writer, s, newDotExpr(o, name))
    # prepare a skip="field" argument to writeTuple()
    let skipper = nnkExprEqExpr.newTree(ident"skip", newLit name.strVal)
    # write the remaining fields as determined by the discriminator
    result.add newCall(writeTuple, s, o, skipper, parentEq(parent))

macro readObject[S, T](s: var Serializer[S]; o: var T) =
  # do nothing by default
  result = newEmptyNode()
  let
    readTuple = bindSym"readTuple"
    reader = bindSym("readPrimitive", rule = brClosed)
    typ = o.getTypeImpl
    sym = o.getTypeInst
  when defined(frostyDebug):
    echo typ.treeRepr
    echo typ.repr
  let variant = findChild(typ[^1], it.kind == nnkRecCase)
  if variant.isNil:
    # it's a simple named tuple/object
    result = newCall(readTuple, s, o)
  else:
    let
      disc = variant[0]        # the first IdentDefs under RecCase
      name = disc[0]           # the symbol of the discriminator
      dtyp = disc[1]           # the type of the discriminator
    when defined(frostyDebug):
      echo dtyp.getTypeImpl.treeRepr
    # it's an object variant; we need to unpack the discriminator first
    result = newStmtList()
    # create a variable into which we can read the discriminator
    let kind = genSym(nskVar, "kind")
    # declare our kind variable with its value type
    result.add nnkVarSection.newTree(newIdentDefs(kind, dtyp,
                                                  newEmptyNode()))
    # read the value of the discriminator into our `kind` variable
    result.add newCall(reader, s, kind)
    # create an object constructor for the variant object
    var ctor = nnkObjConstr.newNimNode
    # the first child is the name of the object type
    ctor.add ident(sym.strVal)
    # add `name: kind` to the variant object constructor
    ctor.add newColonExpr(name, kind)
    # assign it to the input symbol
    result.add newAssignment(o, ctor)
    # prepare a skip="field" argument to readTuple()
    let skipper = nnkExprEqExpr.newTree(ident"skip", newLit name.strVal)
    # read the remaining fields as determined by the discriminator
    result.add newCall(readTuple, s, o, skipper)

macro write(s: var Serializer; o: typed; parent = 0) =
  var typ = o.getTypeImpl
  let parent = parentEq(parent)
  case typ.kind
  of nnkDistinctTy:
    # naive unwrap of distinct types
    result = newCall(bindSym"write", s, newCall(typ[0], o), parent)
  of nnkObjectTy:
    # here we need to consider variant objects
    result = newCall(bindSym"writeObject", s, o, parent)
  of nnkTupleTy, nnkTupleConstr:
    # this is a naive write of ordered fields
    result = newCall(bindSym"writeTuple", s, o, parent)
  elif typ.kind == nnkSym and $typ == "string":
    # we want to handle strings specially
    result = newCall(bindSym"writeString", s, o)
  elif typ.kind == nnkBracketExpr and $typ[0] == "seq":
    result = newCall(bindSym"writeSequence", s, o)
  else:
    # a naive write of any other arbitrary type
    result = newCall(bindSym"writePrimitive", s, o)

macro read(s: var Serializer; o: var typed) =
  var typ = o.getTypeImpl
  case typ.kind
  of nnkDistinctTy:
    # naive unwrap of distinct types
    result = newCall(bindSym"read", s, newCall(typ[0], o))
  of nnkObjectTy:
    # here we need to consider variant objects
    result = newCall(bindSym"readObject", s, o)
  of nnkTupleTy, nnkTupleConstr:
    # this is a naive read of ordered fields
    result = newCall(bindSym"readTuple", s, o)
  elif typ.kind == nnkSym and $typ == "string":
    # we want to handle strings specially
    result = newCall(bindSym"readString", s, o)
  elif typ.kind == nnkBracketExpr and $typ[0] == "seq":
    result = newCall(bindSym"readSequence", s, o)
  else:
    # a naive read of any other arbitrary type
    result = newCall(bindSym"readPrimitive", s, o)

template audit(o: typed; g: typed) =
  when not frostyDebug:
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
      if g.h != 0:         # if we read a hash,
        assert g.h == h    #   check it,
      else:                # else,
        g.h = h            #   save it

proc readTuple[S, T](s: var Serializer[S]; o: var T; skip = "") =
  var skipped = skip == ""
  for k, val in fieldPairs(o):
    if not skipped and k == skip:
      skipped = true
    else:
      # create a var that we can pass to the read()
      var x: typeof(val)
      s.read x
      val = x

proc writeString[T](s: var Serializer[Stream]; o: T) =
  write(s.stream, len(o))   # put the str len
  write(s.stream, o)        # put the str data

proc readString[T](s: var Serializer[Stream]; o: var T) =
  var l = len(string o)              # type inference
  read(s.stream, l)                  # get the str len
  setLen(string o, l)                # set the length
  if l > 0:
    if readData(s.stream, o.cstring, l) != l:
      raise newException(ThawError, "short read!")

proc write[S, T](s: var Serializer[S]; o: ref T; parent = 0) =
  # compute p and store it
  var g = Ice(p: refAddr(o))
  audit(o, g)        # if it's nonzero, also compute hash

  s.write g          # write the preamble
  if g.p != 0:
    if not hasKeyOrPut(s.ptrs, g.p, cast[pointer](o)):
      # we haven't written the value for this address yet,
      # so write it now
      if g.p != parent:
        s.write o[], parent = g.p
      else:
        raise newException(FreezeError, "unexpected cycle")

proc writeTuple[S, T](s: var Serializer[S]; o: T; skip = ""; parent = 0) =
  var skipped = skip == ""
  for k, val in fieldPairs(o):
    if not skipped and k == skip:
      skipped = true
    else:
      when val is ref:
        s.write val, parent = parent
      else:
        s.write val

proc read[S, T](s: var Serializer[S]; o: var ref T) =
  const
    unlikely = cast[pointer](-1)
  var
    g: Ice
  s.read g
  if g.p == 0:
    o = nil
  else:
    # a lookup is waaaay cheaper than an alloc
    let p = getOrDefault(s.ptrs, g.p, unlikely)
    if p == unlikely:
      o = new (ref T)
      s.ptrs[g.p] = cast[pointer](o)
      s.read o[]
      audit(o, g)     # after you read it, check the hash
    else:
      o = cast[ref T](p)

proc writeSequence[S, T](s: var Serializer[S]; o: seq[T]) =
  s.write len(o)
  for i, item in o.pairs:
    s.write item

proc readSequence[S, T](s: var Serializer[S]; o: var seq[T]) =
  var l = len(o)          # type inference
  s.read l                # get the len of the seq
  o.setLen(l)             # pre-alloc the sequence
  for item in o.mitems:   # iterate over mutable items
    s.read item           # read into the item

proc writePrimitive[T](s: var Serializer[Stream]; o: T) {.used.} =
  write(s.stream, o)

proc readPrimitive[T](s: var Serializer[Stream]; o: var T) =
  streams.read(s.stream, o)

template guard(T: typed; body: typed) =
  ## don't try to serialize stuff we can't copy
  when T is seq or T is string or T is object or supportsCopyMem T:
    body
  else:
    {.error: "frosty cannot operate on " & $T.}

proc freeze*[T](stream: Stream; o: T) =
  ## Write `o` into `stream`.
  var s = newSerializer stream
  s.write o

proc freeze*[T](bytes: var Bytes; o: T) =
  ## Write `o` into `bytes`.
  runnableExamples:
    import uri
    # start with some data
    let q = parseUri"https://github.org/nim-lang/Nim"
    # prepare a string
    var s: string
    # write the data into the string
    s.freeze q
    # prepare a new uri object
    var url: Uri
    # populate the uri using the string as input
    s.thaw url
    # confirm that two objects match
    assert url == q

  var s = newSerializer bytes
  s.write o

proc freeze*[T](o: T): string =
  ## Turn `o` into a string.
  runnableExamples:
    import uri
    # start with some data
    var q = parseUri"https://github.org/nim-lang/Nim"
    # freeze `q` into `s`
    var s = freeze q
    # thaw `s` into `u`
    var u = s.thaw Uri
    # confirm that two objects match
    assert u == q

  var s = newSerializer result
  s.write o
  result = s.stream[]

proc thaw*[T](stream: Stream; o: var T) =
  ## Read `o` from `stream`.
  var s = newSerializer stream
  s.read o

proc thaw*[T](bytes: Bytes; o: var T) =
  ## Read `o` from `bytes`.
  runnableExamples:
    # start with some data
    var q = @[1, 1, 2, 3, 5]
    # prepare a string to hold the data
    var s: string
    # write the data into the string
    s.freeze q
    # check that it matches our expectation
    assert len(s) == sizeof(int) + 5*sizeof(int)
    # prepare a new seq to hold some data
    var l: seq[int]
    # populate the seq using the string as input
    s.thaw l
    # confirm that the two sequences of data match
    assert l == q

  var s = newSerializer bytes
  s.read o

proc thaw*[R](src: R; T: typedesc): T =
  ## Read value of type `T` from serial source `src`.
  var s = newSerializer src
  s.read result

proc thaw*[T](bytes: Bytes): T =
  ## Read value of `T` from serial source `bytes`.
  result = thaw(bytes, T)

when frostyNet:
  proc writeString[T](s: var Serializer[Socket]; o: T) =
    var l = len(o)            # type inference
    # send the length of the string
    if send(s.socket, data = addr l, size = sizeof(l)) != sizeof(l):
      raise newException(FreezeError, "short write; socket closed?")
    # send the string itself; this can raise...
    send(s.socket, data = o)

  proc readString[T](s: var Serializer[Socket]; o: var T) =
    var l = len(o)            # type inference
    # receive the string size
    if recv(s.socket, data = addr l, size = sizeof(l)) != sizeof(l):
      raise newException(ThawError, "short read; socket closed?")
    # for the following recv(), "data must be initialized"
    setLen(o, l)
    if l > 0:
      # receive the string
      if recv(s.socket, data = o, size = l) != l:
        raise newException(ThawError, "short read; socket closed?")

  proc writePrimitive[T](s: var Serializer[Socket]; o: T) {.used.} =
    if send(s.socket, data = addr o, size = sizeof(o)) != sizeof(o):
      raise newException(FreezeError, "short write; socket closed?")

  proc readPrimitive[T](s: var Serializer[Socket]; o: var T) =
    if net.recv(s.socket, data = addr o, size = sizeof(o)) != sizeof(o):
      raise newException(ThawError, "short read; socket closed?")

  proc freeze*[T](socket: Socket; o: T) =
    ## Send `o` via `socket`.
    var s = newSerializer socket
    s.write o

  proc thaw*[T](socket: Socket; o: var T) =
    ## Receive `o` from `socket`.
    var s = newSerializer socket
    s.read o

{.pop.}
