version = "0.2.1"
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
    execCmd "nim c        -f -r " & test & " write 2"
    execCmd "nim c           -r " & test & " read 2"
    execCmd "nim c -d:frostySorted:off -r -f " & test & " write 2"
    execCmd "nim c -d:frostySorted:off -r    " & test & " read 2"
    when (NimMajor, NimMinor) >= (1, 2):
      execCmd "nim c -d:danger --gc:arc -r -f " & test & " write 1000"
      execCmd "nim c -d:danger --gc:arc -r   " & test & " read 1000"
  else:
    execCmd "nim c   -d:danger  -r -f " & test & " write 1000"
    execCmd "nim c   -d:danger  -r    " & test & " read 1000"
    execCmd "nim c -d:danger -d:frostySorted=off -r -f " & test & " write 1000"
    execCmd "nim c -d:danger -d:frostySorted=off -r    " & test & " read 1000"
    execCmd "nim c   -d:danger  -r    " & test & " read 1000"
    execCmd "nim cpp -d:danger  -r -f " & test & " write 1000"
    execCmd "nim cpp -d:danger  -r    " & test & " read 1000"
    when (NimMajor, NimMinor) >= (1, 2):
      execCmd "nim c --useVersion:1.0 -d:danger -r -f " & test & " write 1000"
      execCmd "nim c --useVersion:1.0 -d:danger -r    " & test & " read 1000"
      execCmd "nim c   -d:danger --gc:arc -r -f " & test & " write 1000"
      execCmd "nim c   -d:danger --gc:arc -r    " & test & " read 1000"
      execCmd "nim cpp -d:danger --gc:arc -r -f " & test & " write 1000"
      execCmd "nim cpp -d:danger --gc:arc -r    " & test & " read 1000"

task test, "run tests for ci":
  execTest("tests/test.nim")

task bench, "generate benchmark":
  exec "termtosvg docs/bench.svg --max-frame-duration=3000 --loop-delay=3000 --screen-geometry=80x30 --template=window_frame_powershell --command=\"nim c --gc:arc --define:danger -r tests/bench.nim\""
