import std/genasts
import std/macros
import std/tables

type
  Serializer*[T] = object
    stream*: T
    ptrs*: Table[int, pointer]

  FreezeError* = ValueError  ##
  ## An error raised during `freeze`.
  ThawError* = ValueError    ##
  ## An error raised during `thaw`.

  Op = enum
    Read  = "read"
    Write = "write"

when false:
  proc operation(n: NimNode): Op =
    case repr(n)
    of "write": result = Write
    of "read" : result = Read
    else: error"unrecognized operation"

proc initSerializer*[S](s: var Serializer[S]; source: S) {.raises: [].} =
  s.stream = source

proc write[T](s: var Serializer; o: ref T)
proc read[T](s: var Serializer; o: var ref T)
proc forObject(s, o, tipe: NimNode; call: NimNode): NimNode
proc forTuple(s: NimNode; o: NimNode; call: NimNode): NimNode
proc writeSequence(s: NimNode; o: NimNode): NimNode
proc readSequence(s: NimNode; o: NimNode): NimNode
proc writeRef(s, o: NimNode): NimNode
proc readRef(s, o: NimNode): NimNode

proc errorAst(s: string; info: NimNode = nil): NimNode =
  result =
    nnkPragma.newTree:
      ident"error".newColonExpr: newLit s
  if not info.isNil:
    copyLineInfo result[0], info

proc errorAst(n: NimNode; s: string): NimNode =
  let s = s & ":\n" & treeRepr n
  result = errorAst(s, info = n)

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
template unbind(op: Op): NimNode = unbind($op)

template unimplemented(name: untyped) =
  template `write name`[T](s: var Serializer; o: T) {.used.} =
    raise Defect.newException "write" & astToStr(name) & " not implemented"

  template `read name`[T](s: var Serializer; o: var T) {.used.} =
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

proc forTuple(s: NimNode; o: NimNode; call: NimNode): NimNode =
  let tipe = getTypeImpl o
  result = tipe.eachField(s, o):
    call

proc forObject(s, o, tipe: NimNode; call: NimNode): NimNode =
  result = newStmtList()
  case tipe.kind
  of nnkEmpty:
    discard
  of nnkOfInherit:
    # we need to consume the parent object type's fields
    result.add:
      forObject(s, o, getTypeImpl tipe.last, call)
  of nnkRefTy:
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
    of nnkRefTy:
      tipe.errorAst "creepy binding"
    of nnkDistinctTy:
      newCall(unbind op, s, newCall(tipe[0], o))
    of nnkObjectTy:
      forObject(s, o, getTypeImpl o, unbind op)
    of nnkTupleTy, nnkTupleConstr:
      forTuple(s, o, unbind op)
    elif tipe.isType("string"):
      newCall(unbind $op & "String", s, o)
    elif tipe.isGenericOf("seq"):
      case op
      of Read : readSequence(s, o)
      of Write: writeSequence(s, o)
    else:
      newCall(unbind $op & "Primitive", s, o)

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
proc write[T](s: var Serializer; o: ref T) = writeRefImpl(s, o)

macro readRefImpl[T](s: var Serializer; o: ref T) = readRef(s, o)
proc read[T](s: var Serializer; o: var ref T) = readRefImpl(s, o)

#
# put 'em down here so we don't accidentally bind somewhere
#

macro write*(s: var Serializer; o: typed): untyped =
  perform(Write, s, o)

macro read*(s: var Serializer; o: var typed) =
  perform(Read, s, o)

include frosty/streams
include frosty/net
