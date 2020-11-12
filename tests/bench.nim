import std/macros
import std/strutils
import std/streams
import std/intsets
import std/os
import std/uri

import criterion
import json
import frosty
import flatty

when not defined(danger):
  {.error: "define danger for benchmarks".}

var cfg = newDefaultConfig()
cfg.budget = 0.5
cfg.brief = true

template strop(s: string): NimNode = nnkAccQuoted.newTree(ident s)

macro bench(n: typed) =
  proc nameType(n: NimNode): string =
    result = repr n.getTypeImpl
    if "\n" in result:
      result = n.strVal

  when false:
    let cfg = genSym(nskVar, "cfg")
    result.add newVarStmt(cfg, newCall(ident"newDefaultConfig"))
    result.add newAssignment(newDotExpr(cfg, ident"budget"), newLit 0.5)
    result.add newAssignment(newDotExpr(cfg, ident"brief"), newLit true)
  else:
    let cfg = bindSym"cfg"

  var ss = genSym(nskVar, "ss")
  var data = genSym(nskVar, "data")
  var pbody: NimNode  # proc bodies
  let pragmas = nnkPragma.newTree ident"measure"

  var body = newStmtList()
  body.add newVarStmt(ss, newCall(ident"newStringStream",
                          newCall(ident"newStringOfCap", newLit 4096)))
  body.add newVarStmt(data, n)

  pbody = newStmtList()
  pbody.add newCall(ident"setPosition", ss, newLit 0)
  pbody.add newCall(ident"freeze", n, ss)
  body.add newProc(strop "frosty_write_" & n.nameType,
                   pragmas = pragmas, body = pbody)

  pbody = newStmtList()
  pbody.add newCall(ident"setPosition", ss, newLit 0)
  pbody.add newCall(ident"thaw", ss, data)
  body.add newProc(strop "frosty_read_" & n.nameType,
                   pragmas = pragmas, body = pbody)

  pbody = newStmtList()
  pbody.add newCall(ident"setPosition", ss, newLit 0)
  pbody.add newCall(ident"write", ss, newCall(ident"toFlatty", n))
  body.add newProc(strop "flatty_write_" & n.nameType,
                   pragmas = pragmas, body = pbody)

  pbody = newStmtList()
  pbody.add newCall(ident"setPosition", ss, newLit 0)
  #let typ = genSym(nskType, "typ")
  #let typ = bindSym(getType n)
  let typ = newCall(ident"typeof", n)
  pbody.add:
    newTree nnkDiscardStmt:
      newCall(ident"fromFlatty", newCall(ident"readAll", ss), typ)
  let ex = genSym(nskLet, "e")
  let errs = newStmtList(
    newCall(ident"once", newCall(ident"echo", newDotExpr(ex, ident"msg"))))
  pbody = nnkTryStmt.newTree(pbody,
                             newTree(nnkExceptBranch,
                                     infix(ident"Exception", "as", ex),
                                     errs))
  body.add newProc(strop "flatty_read_" & n.nameType,
                   pragmas = pragmas, body = pbody)

  result  = newCall(ident"benchmark", cfg, body)

when isMainModule:
  let
    count = if paramCount() < 1: 1 else: parseInt paramStr(1)

  proc makeJs(): JsonNode =
    var
      tJsA = newJArray()
      tJsO = newJObject()
      tJs = newJObject()

    tJsA.add newJString"pigs"
    tJsA.add newJString"horses"

    tJsO.add "toads", newJBool(true)
    tJsO.add "rats", newJString"yep"

    for k, v in {
      "empty": newJNull(),
      "goats": tJsA,
      "sheep": newJInt(11),
      "ducks": newJFloat(12.0),
      "dogs": newJString("woof"),
      "cats": newJBool(false),
      "frogs": tJsO,
    }.items:
      tJs[k] = v
    result = tJs

  var
    tJs {.compileTime.} = makeJs()
    tIntset = initIntSet()
  for i in 0 .. 10:
    tIntset.incl i

  const
    jsSize = len($tJs)
    tSeq = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    tString = "https://irclogs.nim-lang.org/01-06-2020.html#20:54:23"
    tObj = parseUri(tString)

  echo "benching against " & $count & " units; jsSize = " & $jsSize

  bench tSeq
  bench tString
  bench tObj
  #bench tIntset
  #bench tJs
