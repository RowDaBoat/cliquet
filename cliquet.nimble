packageName   = "cliquet"
version       = "0.0.1"
author        = "RowDaBoat"
description   = "A tool for building CLI applications."
license       = "ISC"

srcDir        = "src"
binDir        = "bin"
skipDirs      = @["examples"]

requires "nim >= 2.0.0"

task examples, "Build examples":
  exec "nim c src/examples/example.nim"

task docs, "Generate documentation":
  exec "nim doc --project --git.url:git@github.com:RowDaBoat/cliquet.git --index:on --outdir:docs src/cliquet.nim"
