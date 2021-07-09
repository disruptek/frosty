import std/genasts
import std/macros
import std/tables

type
  Serializer[T] = object
    serial: T
    ptrs: Table[int, pointer]

  FreezeError* = ValueError  ##
  ## An error raised during `freeze`.
  ThawError* = ValueError    ##
  ## An error raised during `thaw`.

  Op = enum
    Read  = "deserialize"
    Write = "serialize"

proc serialize[T](s: var Serializer; o: ref T)
proc deserialize[T](s: var Serializer; o: var ref T)
proc forObject(s, o, tipe: NimNode; call: NimNode): NimNode
proc forTuple(s: NimNode; o: NimNode; call: NimNode): NimNode
proc writePrimitive(s: NimNode; o: NimNode): NimNode
proc readPrimitive(s: NimNode; o: NimNode): NimNode
proc writeString(s: NimNode; o: NimNode): NimNode
proc readString(s: NimNode; o: NimNode): NimNode
proc writeSequence(s: NimNode; o: NimNode): NimNode
proc readSequence(s: NimNode; o: NimNode): NimNode
proc writeRef(s, o: NimNode): NimNode
proc readRef(s, o: NimNode): NimNode

proc isType(n: NimNode): bool =
  n.kind == nnkSym and n.symKind == nskType

proc isType(n: NimNode; s: string): bool =
  n.isType and n.strVal == s

proc isGenericOf(n: NimNode; s: string): bool =
  if n.kind == nnkBracketExpr:
    if n.len > 0:
      return n[0].isType s

template dot(a, b: NimNode): NimNode =
  newDotExpr(a, b)

template eq(a, b: NimNode): NimNode =
  nnkExprEqExpr.newNimNode(a).add(a).add(b)

template eq(a: string; b: NimNode): NimNode {.used.} =
  eq(ident(a), b)

template sq(a, b: NimNode): NimNode =
  nnkBracketExpr.newNimNode(a).add(a).add(b)

template sq(a: NimNode; b: SomeInteger) =
  sq(a, newLit b)

{.experimental: "dynamicBindSym".}
template unbound(s: string): NimNode =
  bindSym(s, rule = brForceOpen)
template unbind(s: string): NimNode =
  unbound s
template unbind(op: Op): NimNode =
  unbind $op

proc eachField(n, s, o: NimNode; call: NimNode): NimNode =
  result = newStmtList()
  for index, node in n.pairs:
    case node.kind

    of nnkRecList:
      result.add:
        node.eachField(s, o, call)

    of nnkIdentDefs:
      result.add:
        newCall(call, s, o.dot node[0])

    of nnkRecCase:
      let kind = node[0][0]
      result.insert 0:
        genAst(call, s, o, kind, temp = nskTemp.genSym"kind", tipe = node[0][1]):
          var temp: tipe
          call(s, temp)
          o.kind = temp
      let kase = nnkCaseStmt.newTree(o.dot kind)
      for branch in node[1 .. ^1]:                # skip discriminator
        let clone = copyNimNode branch
        case branch.kind
        of nnkOfBranch:
          for expr in branch[0 .. ^2]:
            clone.add expr
          clone.add:
            eachField(branch.last, s, o, call)
        of nnkElse:
          clone.add:
            eachField(branch.last, s, o, call)
        else:
          raise ValueError.newException:
            "unrecognized ast:\n" & treeRepr(node)
        kase.add clone
      result.add kase

    else:
      result.add:
        newCall(call, s, o.sq index)

  # produce an empty discard versus an empty statement list
  if result.len == 0:
    result = nnkDiscardStmt.newTree newEmptyNode()

proc forTuple(s: NimNode; o: NimNode; call: NimNode): NimNode =
  let tipe = getTypeImpl o
  result = tipe.eachField(s, o):
    call

proc forObject(s, o, tipe: NimNode; call: NimNode): NimNode =
  result = newStmtList()
  case tipe.kind
  of nnkEmpty:
    discard
  of nnkOfInherit, nnkRefTy:
    # we need to consume the parent object type's fields, or
    # unwrap a ref type modifier
    result.add:
      forObject(s, o, getTypeImpl tipe.last, call)
  of nnkObjectTy:
    # first see about writing the parent object's fields
    result.add:
      forObject(s, o, tipe[1], call)

    # now we can write the records in this object
    let records = tipe[2]
    case records.kind
    of nnkEmpty:
      discard
    of nnkRecList:
      result.add:
        records.eachField(s, o):
          call
    else:
      raise ValueError.newException:
        "unrecognized object type ast\n" & treeRepr(tipe)
  else:
    raise ValueError.newException:
      "unrecognized object type ast\n" & treeRepr(tipe)

proc perform(op: Op; s: NimNode; o: NimNode): NimNode =
  let tipe = getTypeImpl o
  result =
    case tipe.kind
    of nnkDistinctTy:
      newCall(unbind op, s, newCall(tipe[0], o))
    of nnkObjectTy:
      forObject(s, o, getTypeImpl o, unbind op)
    of nnkTupleTy, nnkTupleConstr:
      forTuple(s, o, unbind op)
    elif tipe.isType("string"):
      case op
      of Read : readString(s, o)
      of Write: writeString(s, o)
    elif tipe.isGenericOf("seq"):
      case op
      of Read : readSequence(s, o)
      of Write: writeSequence(s, o)
    else:
      case op
      of Read : readPrimitive(s, o)
      of Write: writePrimitive(s, o)

proc writeRef(s, o: NimNode): NimNode =
  genAst(s, o, writer = unbind Write):
    let p = cast[int](o)    # cast the pointer
    s.writer p              # write the pointer
    if p != 0:
      if not hasKeyOrPut(s.ptrs, p, cast[pointer](o)):
        # write the value for this novel address
        s.writer o[]

proc readRef(s, o: NimNode): NimNode =
  genAst(s, o, reader = unbind Read):
    var g: int
    s.reader g
    if g == 0:
      o = nil
    else:
      # a lookup is waaaay cheaper than an alloc
      let p = getOrDefault(s.ptrs, g, cast[pointer](-1))
      if p == cast[pointer](-1):
        o = new (ref T)
        s.ptrs[g] = cast[pointer](o)
        s.reader o[]
      else:
        o = cast[ref T](p)

template asString(s: typed): untyped =
  when s is string:
    s                 # a string
  else:
    string(s)         # a distinct string

proc writeString(s: NimNode; o: NimNode): NimNode =
  genAst(s, o, asString, writer = unbind Write):
    let l = len(o)
    s.writer l                         # write the size of the string
    writer(s.serial, asString(o), l)   # write the string

proc readString(s: NimNode; o: NimNode): NimNode =
  genAst(s, o, asString, reader = unbind Read):
    var l = len(asString o)            # type inference
    s.reader l                         # read the string length
    setLen(asString o, l)              # set the new length
    if l > 0:
      reader(s.serial, asString o, l)  # read the string

proc writePrimitive(s: NimNode; o: NimNode): NimNode =
  genAst(s, o, writer = unbind Write):
    writer(s.serial, o)      # write the value

proc readPrimitive(s: NimNode; o: NimNode): NimNode =
  genAst(s, o, reader = unbind Read):
    reader(s.serial, o)      # read the value

proc writeSequence(s: NimNode; o: NimNode): NimNode =
  genAst(s, o, writer = unbind Write):
    s.writer len(o)          # write the size of the sequence
    for item in items(o):    # iterate over the contents
      s.writer item          #     write the item

proc readSequence(s: NimNode; o: NimNode): NimNode =
  genAst(s, o, reader = unbind Read):
    var l = len(o)           # type inference
    s.reader l               # get the size of the sequence
    setLen(o, l)             # resize the sequence
    for index in 0..<l:      # iterate over mutable items
      s.reader o[index]      #     read the item

#
# this hack lets nim "cache" the logic for handling a reference as a
# generic as opposed to just recursively following cyclic references
#

macro writeRefImpl[T](s: var Serializer; o: ref T) = writeRef(s, o)
proc serialize[T](s: var Serializer; o: ref T) = writeRefImpl(s, o)

macro readRefImpl[T](s: var Serializer; o: ref T) = readRef(s, o)
proc deserialize[T](s: var Serializer; o: var ref T) = readRefImpl(s, o)

#
# put 'em down here so we don't accidentally bind somewhere
#

macro serialize(s: var Serializer; o: typed): untyped =
  perform(Write, s, o)

macro deserialize(s: var Serializer; o: var typed) =
  perform(Read, s, o)

proc freeze*[S, T](output: S; input: T) =
  ## Write `input` into `output`.
  var s: Serializer[S]
  s.serial = output
  serialize(s, input)

proc thaw*[S, T](input: S; output: var T) =
  ## Read `output` from `input`.
  var s: Serializer[S]
  s.serial = input
  deserialize(s, output)
