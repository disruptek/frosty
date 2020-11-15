version = "0.4.1"
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

task bench, "generate benchmark":
  exec "termtosvg docs/bench.svg --max-frame-duration=3000 --loop-delay=3000 --screen-geometry=80x30 --template=window_frame_powershell --command=\"nim c --gc:arc --define:danger -r tests/bench.nim\""
