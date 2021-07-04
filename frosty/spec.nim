import std/genasts
import std/macros
import std/tables

type
  Serializer*[T] = object
    stream*: T
    stack*: seq[pointer]
    ptrs*: Table[int, pointer]

  FreezeError* = ValueError  ##
  ## An error raised during `freeze`.
  ThawError* = ValueError    ##
  ## An error raised during `thaw`.

proc initSerializer*[S](s: var Serializer[S]; source: S) {.raises: [].} =
  s.stream = source

proc write*[T](s: var Serializer; o: ref T)
proc read*[T](s: var Serializer; o: var ref T)
proc forObject*(s: NimNode; o: NimNode; call: NimNode): NimNode
proc forTuple*(s: NimNode; o: NimNode; call: NimNode): NimNode
proc writeSequence*(s: NimNode; o: NimNode): NimNode
proc readSequence*(s: NimNode; o: NimNode): NimNode

proc isType(n: NimNode): bool =
  n.kind == nnkSym and n.symKind == nskType

proc isType(n: NimNode; s: string): bool =
  n.isType and n.strVal == s

proc isGenericOf(n: NimNode; s: string): bool =
  if n.kind == nnkBracketExpr:
    if n.len > 0:
      return n[0].isType s

proc doc(s: string): NimNode {.used.} =
  newCommentStmtNode s

proc doc(s: string; body: NimNode): NimNode {.used.} =
  when defined(release):
    body
  else:
    newStmtList [
      doc("begin: " & s),
      body,
      doc("  end: " & s),
    ]

template dot*(a, b: NimNode): NimNode =
  newDotExpr(a, b)

template eq*(a, b: NimNode): NimNode =
  nnkExprEqExpr.newNimNode(a).add(a).add(b)

template eq*(a: string; b: NimNode): NimNode =
  eq(ident(a), b)

template sq*(a, b: NimNode): NimNode =
  nnkBracketExpr.newNimNode(a).add(a).add(b)

template sq*(a: NimNode; b: SomeInteger) =
  sq(a, newLit b)

{.experimental: "dynamicBindSym".}
template unbind(s: string): NimNode = bindSym(s, rule = brForceOpen)

template unimplemented(name: untyped) =
  template `write name`[T](s: var Serializer; o: T) {.used.} =
    raise Defect.newException "write" & astToStr(name) & " not implemented"

  template `read name`[T](s: Serializer; o: var T) {.used.} =
    raise Defect.newException "read" & astToStr(name) & " not implemented"

unimplemented Primitive
unimplemented String

proc eachField(n, s, o: NimNode; call: NimNode): NimNode =
  result = newStmtList()
  for index, node in n.pairs:
    case node.kind

    of nnkRecList:
      result.add:
        doc "record list":
          node.eachField(s, o, call)

    of nnkIdentDefs:
      result.add:
        doc "for field " & node[0].strVal:
          newCall(call, s, o.dot node[0])

    of nnkRecCase:
      let kind = node[0][0]
      result.insert 0:
        doc "for discriminator " & kind.strVal:
          genAst(call, s, o, kind,
                 temp = nskTemp.genSym"kind", tipe = node[0][1]):
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
        doc "for index " & $index:
          newCall(call, s, o.sq index)

  # produce an empty discard versus an empty statement list
  if result.len == 0:
    result = nnkDiscardStmt.newTree newEmptyNode()

proc forObject*(s: NimNode; o: NimNode; call: NimNode): NimNode =
  let tipe = getTypeImpl o
  let records = tipe[^1]
  case records.kind
  of nnkRecList:
    result = records.eachField(s, o):
      call
  else:
    raise ValueError.newException "unrecognized ast"

proc performWrite(s: NimNode; o: NimNode): NimNode =
  let tipe = getTypeImpl o
  result =
    case tipe.kind
    of nnkDistinctTy:
      # naive unwrap of distinct types
      doc "frosty unwraps a distinct":
        newCall(unbind"write", s, newCall(tipe[0], o))
    of nnkObjectTy:
      # here we need to consider variant objects
      doc "frosty writes an object":
        forObject(s, o, unbind"write")
    of nnkTupleTy, nnkTupleConstr:
      # this is a naive write of ordered fields
      doc "frosty writes a tuple":
        forTuple(s, o, unbind"write")
    elif tipe.isType("string"):
      # we want to handle strings specially
      doc "frosty writes a string":
        newCall(unbind"writeString", s, o)
    elif tipe.isGenericOf("seq"):
      # sequences are similarly special
      doc "frosty writes a sequence":
        writeSequence(s, o)
    else:
      # a naive write of any other arbitrary type
      doc "frosty writes a primitive":
        newCall(unbind"writePrimitive", s, o)

macro write*(s: var Serializer; o: typed): untyped =
  result = performWrite(s, o)

proc performRead(s: NimNode; o: NimNode): NimNode =
  let tipe = getTypeImpl o
  result =
    case tipe.kind
    of nnkDistinctTy:
      # naive unwrap of distinct types
      doc "frosty unwraps a distinct":
        newCall(unbind"read", s, newCall(tipe[0], o))
    of nnkObjectTy:
      # here we need to consider variant objects
      doc "frosty reads an object":
        forObject(s, o, unbind"read")
    of nnkTupleTy, nnkTupleConstr:
      # this is a naive read of ordered fields
      doc "frosty reads a tuple":
        forTuple(s, o, unbind"read")
    elif tipe.isType("string"):
      # we want to handle strings specially
      doc "frosty reads a string":
        newCall(unbind"readString", s, o)
    elif tipe.isGenericOf("seq"):
      doc "frosty reads a sequence":
        readSequence(s, o)
    else:
      # a naive read of any other arbitrary type
      doc "frosty reads a primitive":
        newCall(unbind"readPrimitive", s, o)

macro read*(s: var Serializer; o: var typed) =
  result = performRead(s, o)

proc write*[T](s: var Serializer; o: ref T) =
  let p = cast[int](o)    # cast the pointer
  s.write p               # write the pointer
  if p != 0:
    if not hasKeyOrPut(s.ptrs, p, cast[pointer](o)):
      # write the value for this novel address
      s.write(o[])

proc read*[T](s: var Serializer; o: var ref T) =
  const
    unlikely = cast[pointer](-1)
  var g: int
  s.read g
  if g == 0:
    o = nil
  else:
    # a lookup is waaaay cheaper than an alloc
    let p = getOrDefault(s.ptrs, g, unlikely)
    if p == unlikely:
      o = new (ref T)
      s.ptrs[g] = cast[pointer](o)
      s.read o[]
    else:
      o = cast[ref T](p)

proc forTuple*(s: NimNode; o: NimNode; call: NimNode): NimNode =
  let tipe = getTypeImpl o
  result = tipe.eachField(s, o):
    call

proc writeSequence*(s: NimNode; o: NimNode): NimNode =
  genAst(s, o):
    s.write len(o)          # write the size of the sequence
    for item in items(o):   # iterate over the contents
      s.write item          #     write the item

proc readSequence*(s: NimNode; o: NimNode): NimNode =
  genAst(s, o):
    var l = len(o)            # type inference
    s.read l                  # get the size of the sequence
    setLen(o, l)              # resize the sequence
    for item in mitems(o):    # iterate over mutable items
      s.read item             #     read the item

include frosty/streams
include frosty/net
