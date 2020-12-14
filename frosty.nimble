version = "0.4.4"
author = "disruptek"
description = "serialize native Nim types to strings, streams, or sockets"
license = "MIT"

requires "https://github.com/narimiran/sorta < 1.0.0"
requires "https://github.com/disruptek/criterion < 1.0.0"
requires "https://github.com/disruptek/testes < 1.0.0"

proc execCmd(cmd: string) =
  echo "exec: " & cmd
  exec cmd

proc execTest(test: string) =
  when getEnv("GITHUB_ACTIONS", "false") != "true":
    execCmd "nim c -d:frostySorted:on  -d:danger -r -f " & test
    execCmd "nim c -d:frostySorted:off -d:danger -r -f " & test
    when (NimMajor, NimMinor) >= (1, 2):
      execCmd "nim c -d:frostySorted:on -d:danger --gc:arc -r -f " & test
      execCmd "nim c -d:frostySorted:off -d:danger --gc:arc -r -f " & test
  else:
    execCmd "nim c             -d:frostySorted=on  -r -f " & test
    execCmd "nim c   -d:danger -d:frostySorted=on  -r -f " & test
    execCmd "nim cpp -d:danger -d:frostySorted=on  -r -f " & test
    execCmd "nim c   -d:danger -d:frostySorted=off -r -f " & test
    execCmd "nim cpp -d:danger -d:frostySorted=off -r -f " & test
    when (NimMajor, NimMinor) >= (1, 2):
      execCmd "nim c --useVersion:1.0 -d:danger -r -f " & test
      execCmd "nim c   -d:danger -d:frostySorted=on --gc:arc -r -f " & test
      execCmd "nim cpp -d:danger -d:frostySorted=on --gc:arc -r -f " & test
      execCmd "nim c   -d:danger -d:frostySorted=off --gc:arc -r -f " & test
      execCmd "nim cpp -d:danger -d:frostySorted=off --gc:arc -r -f " & test

task test, "run tests for ci":
  execTest("tests/test.nim")
  execTest("tests/tvariant.nim")

task demo, "generate benchmark":
  exec """demo docs/bench.svg "nim c --out=\$1 --gc:arc --define:danger tests/bench.nim""""
