version = "0.2.0"
author = "disruptek"
description = "serialize native Nim objects via streams, sockets"
license = "MIT"

requires "nim >= 1.0.0 & < 2.0.0"
requires "https://github.com/narimiran/sorta < 1.0.0"

proc execCmd(cmd: string) =
  echo "exec: " & cmd
  exec cmd

proc execTest(test: string) =
  when getEnv("GITHUB_ACTIONS", "false") != "true":
    execCmd "nim c        -f -r " & test & " write"
    execCmd "nim c           -r " & test & " read"
    execCmd "nim c -d:danger -r " & test & " write 500"
    execCmd "nim c -d:danger -r " & test & " read 500"
  else:
    execCmd "nim c              -r " & test & " write 500"
    execCmd "nim c   -d:danger  -r " & test & " read 500"
    execCmd "nim cpp            -r " & test & " write 500"
    execCmd "nim cpp -d:danger  -r " & test & " read 500"
    when (NimMajor, NimMinor) >= (1, 2):
      execCmd "nim c --useVersion:1.0 -d:danger -r " & test & " write 500"
      execCmd "nim c --useVersion:1.0 -d:danger -r " & test & " read 500"
      execCmd "nim c   --gc:arc -r " & test & " write 500"
      execCmd "nim cpp --gc:arc -r " & test & " read 500"

task test, "run tests for travis":
  execTest("tests/test.nim")
