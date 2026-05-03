# ISC License
# Copyright (c) 2025 RowDaBoat

import config
import tables
import sequtils
import strutils
import options


proc generateUsage*(program: string, namesInOrder: seq[string], definitions: Table[string, Config]): string =
  result = "Usage: " & program

  for name in namesInOrder:
    var config = definitions[name]
    var usage = ""

    if config.usage.isSome:
      if config.shortOnly:
        usage &= "-" & $config.short
      else:
        usage &= "--" & config.long

      if config.usage.get != "":
        usage &= "=" & config.usage.get

      if not config.required:
        usage = "[" & usage & "]"

      result &= " " & usage


proc generateConfig*(namesInOrder: seq[string], definitions: Table[string, Config]): string =
  for name in namesInOrder:
    var config = definitions[name]

    if config.mode in {Mode.config, Mode.both}:
      result &= "# " & config.help & "\n"
      result &= "# " & config.long & " = " & config.default & " \n\n"


proc generateHelp*(namesInOrder: seq[string], definitions: Table[string, Config]): string =
  var table: seq[(string, string, string, string)] = @[
    ("Options", "Type", "Default", "Help")
  ]
  var optionsWidth = table[0][0].len
  var typesWidth = table[0][1].len
  var defaultsWidth = table[0][2].len

  for name in namesInOrder:
    var config = definitions[name]

    if config.mode in {Mode.option, Mode.both}:
      var short = if config.short != '\0': "-" & $config.short else: ""
      var long = if config.long != "" and not config.shortOnly: "--" & $config.long else: ""
      var options = @[short, long].filterIt(it != "").join(",")
      optionsWidth = max(optionsWidth, options.len)

      var typ = config.typ
      typesWidth = max(typesWidth, typ.len)

      var default = config.default
      defaultsWidth = max(defaultsWidth, default.len)

      table.add((options, typ, config.default, config.help))

  for (options, typ, default, help) in table:
    result &= options.alignLeft(optionsWidth) & "  "
    result &= typ.alignLeft(typesWidth) & "  "
    result &= default.alignLeft(defaultsWidth) & "  "
    result &= help & "\n"
