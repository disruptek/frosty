version = "0.0.3"
author = "disruptek"
description = "marshal native Nim objects via streams, channels"
license = "MIT"

requires "nim >= 1.0.0 & < 2.0.0"
requires "https://github.com/disruptek/criterion"

proc execCmd(cmd: string) =
  echo "execCmd:" & cmd
  exec cmd

proc execTest(test: string) =
    execCmd "nim c              -r " & test
    execCmd "nim c   -d:danger  -r " & test
    execCmd "nim cpp            -r " & test
    execCmd "nim cpp -d:danger  -r " & test
    when NimMajor >= 1 and NimMinor >= 1:
      execCmd "nim c --useVersion:1.0 -d:danger -r " & test
      execCmd "nim c   --gc:arc --exceptions:goto -r " & test
      execCmd "nim cpp --gc:arc --exceptions:goto -r " & test

task test, "run tests for travis":
  execTest("frosty.nim")
