# ISC License
# Copyright (c) 2025 RowDaBoat

import strutils
import strformat
import sequtils
import tables
import sets
import os
import typetraits
import macros
import configsFrom
import config
import generators
import errors

export Mode


type Cliquet*[T] = object
  namesInOrder: seq[string]
  configDefinitions: Table[string, Config]
  default: T
  longArgs: Table[string, string]
  shortArgs: Table[string, string]
  configs: Table[string, string]


template help*(message: string) {.pragma.}
  ## Help message for the configuration field.


template shortOption*(opt: char) {.pragma.}
  ## Short option alternative for the configuration field.


template shortOnly*(opt: char) {.pragma.}
  ## Only expose the short option for the configuration field, suppressing the long form.


template mode*(mode: Mode) {.pragma.}
  ## Mode pragma for the configuration field.


template usage*(usage: string = "") {.pragma.}
  ## Usage example for the configuration field.


template required*() {.pragma.}
  ## Required pragma for the configuration field.


proc appendArg(
    args: var Table[string, string],
    name, value, display: string,
    isSeq: bool
) =
  if name notin args:
    args[name] = value
  elif isSeq:
    args[name] &= "," & value
  else:
    optionRepeated(display)


proc longIsSeq(definitions: Table[string, Config], name: string): bool =
  name in definitions and definitions[name].isSeq


proc shortIsSeq(definitions: Table[string, Config], short: string): bool =
  for config in definitions.values:
    if config.short != '\0' and $config.short == short:
      return config.isSeq

  return false


proc parseLongOption(
    arg: string,
    args: var Table[string, string],
    definitions: Table[string, Config]
) =
  let split = arg.split("=", maxsplit=1)
  let name = split[0][2..^1]

  if split.len < 2:
    args[name] = "true"
  else:
    appendArg(args, name, split[1], "--" & name, longIsSeq(definitions, name))


proc parseShortOptions(
    arg: string,
    args: var Table[string, string],
    definitions: Table[string, Config]
) =
  let split = arg[1..^1].split("=", maxsplit=1)
  let singles = split[0]

  if split.len < 2:
    for single in singles:
      args[$single] = "true"
  elif singles.len == 1:
    appendArg(args, singles, split[1], "-" & singles, shortIsSeq(definitions, singles))
  else:
    invalidShortOptions(arg)


proc showEnum[T: enum](value: T): string =
  typeof(value).mapIt(fmt"{it}").join("|")


proc showEnumList[T: enum](value: seq[T]): string =
  showEnum(default(T))


proc setFieldValue[T](name: string, fieldValue: var T, strValue: string, source: ConfigSource) =
  if source == Default:
    return

  var stripped = strValue.strip

  when fieldValue is bool:
    try: fieldValue = parseBool(stripped)
    except: invalidValue(name, stripped, source, "is not true or false")
  elif fieldValue is int:
    try: fieldValue = parseInt(stripped)
    except: invalidValue(name, stripped, source, "is not an integer number")
  elif fieldValue is float:
    try: fieldValue = parseFloat(stripped)
    except: invalidValue(name, stripped, source, "is not a floating point number")
  elif fieldValue is enum:
    try: fieldValue = parseEnum[typeof(fieldValue)](stripped)
    except: invalidValue(name, stripped, source, "is not one of: " & showEnum(fieldValue))
  elif fieldValue is string:
    fieldValue = stripped
  elif fieldValue is seq[bool]:
    try: fieldValue = stripped.split(",").mapIt(parseBool(it.strip))
    except: invalidValue(name, stripped, source, "contains elements that are not true or false")
  elif fieldValue is seq[int]:
    try: fieldValue = stripped.split(",").mapIt(parseInt(it.strip))
    except: invalidValue(name, stripped, source, "contains elements that are not integer numbers")
  elif fieldValue is seq[float]:
    try: fieldValue = stripped.split(",").mapIt(parseFloat(it.strip))
    except: invalidValue(name, stripped, source, "contains elements that are not floating point numbers")
  elif fieldValue is seq[enum]:
    try: fieldValue = stripped.split(",").mapIt(parseEnum[typeof(fieldValue[0])](it.strip))
    except: invalidValue(name, stripped, source, "contains elements that are not one of: " & showEnumList(fieldValue))
  elif fieldValue is seq[string]:
    fieldValue = stripped.split(",").mapIt(it.strip)
  else:
    {.error: "cliquet: '" & $typeof(fieldValue) & "' is not supported for field: '" & name & "'."}


proc stringType[T](value: T): string =
  const listDescription = "list of"

  when value is bool:
    return "true|false"
  elif value is int:
    return "int number"
  elif value is float:
    return "float number"
  elif value is string:
    return "string"
  elif value is enum:
    return showEnum(value)
  elif value is seq[bool]:
    return listDescription & " true|false"
  elif value is seq[int]:
    return listDescription & " int numbers"
  elif value is seq[float]:
    return listDescription & " float numbers"
  elif value is seq[string]:
    return listDescription & " strings"
  elif value is seq[enum]:
    return listDescription & " " & showEnumList(value)


proc stringDefault[T](value: T): string =
  if value is seq:
    return ($value)[2..^2]
  else:
    return $value


proc initCliquet*[T: object](default: T = default(T)): Cliquet[T] =
  ## Initialize Cliquet, optionally with the default configurations.

  var namesInOrder: seq[string]
  let configs = configsFrom(T)
  var configsTable: Table[string, Config]

  for name, value in default.fieldPairs:
    when not (value is bool | int | float | enum | string | seq[bool] | seq[int] | seq[float] | seq[enum] | seq[string]):
      {.error: "cliquet: '" & $typeof(value) & "' is not supported for field: '" & name & "'."}

  for config in configs:
    namesInOrder.add(config.long)
    configsTable[config.long] = config

  for name, val in default.fieldPairs:
    configsTable[name].typ = stringType(val)
    configsTable[name].default = stringDefault(val)
    configsTable[name].isSeq = val is seq

  result = Cliquet[T](
    namesInOrder: namesInOrder,
    configDefinitions: configsTable,
    default: default
  )


proc parseOptions*[T: object](self: var Cliquet[T], args: seq[string]): seq[string] =
  ## Parse command line options, the result is the remaining arguments from the first non-option argument.
  ## raises an `InvalidShortOptions` error if the short options are ill-formed ex: -abc=def.

  var remaining = args

  while remaining.len > 0:
    let arg = remaining[0]

    if arg == "--":
      return remaining[1..^1]
    elif arg.startsWith("--"):
      parseLongOption(arg, self.longArgs, self.configDefinitions)
    elif arg.startsWith("-"):
      parseShortOptions(arg, self.shortArgs, self.configDefinitions)
    else:
      return remaining

    remaining = remaining[1..^1]

  return remaining


proc parseConfig*[T: object](self: var Cliquet[T], config: string) =
  ## Parse configurations from a string.
  ## The config string is a list of key=value pairs separated by newlines.
  ## The `config` parameter is usually the contents of a configuration file.
  ## Lines starting with `#` are ignored.

  let configs = config.splitLines()
    .mapIt(it.strip)
    .filterIt(it.len > 0 and it[0] != '#')
    .mapIt(it.split('=', maxsplit=1))

  for config in configs:
    let name = config[0].strip

    if config.len == 1:
      self.configs[name] = "true"
    else:
      appendArg(self.configs, name, config[1].strip, name, longIsSeq(self.configDefinitions, name))


proc checkRequirement*[T: object](self: var Cliquet[T], definition: Config): bool =
  let long = definition.long
  let short = $definition.short

  let longOptionPresent = not definition.shortOnly and long in self.longArgs
  let shortOptionPresent = short.len > 0 and short in self.shortArgs
  let configPresent = long in self.configs

  let satisfiedOption = definition.mode == Mode.option and
    (longOptionPresent or shortOptionPresent)

  let satisfiedConfig = definition.mode == Mode.config and
    configPresent

  let satisfiedBoth = definition.mode == Mode.both and
    (longOptionPresent or shortOptionPresent or configPresent)

  result = satisfiedOption or satisfiedConfig or satisfiedBoth


proc config*[T: object](self: var Cliquet[T]): T =
  ## Get the parsed configurations into a configuration object.
  ## Arguments, configurations and defaults, are merged in that order of priority.
  ## raises an `InvalidValue` error if an option of an argument or configuration is not valid for the field type.

  result = self.default

  for name, value in result.fieldPairs:
    var source = Default
    var stringValue = ""
    let definition = self.configDefinitions[name]
    let isOption = definition.mode in {Mode.option, Mode.both}
    let isConfig = definition.mode in {Mode.config, Mode.both}
    let short = definition.short

    if isOption and not definition.shortOnly and name in self.longArgs:
      source = Args
      stringValue = self.longArgs[name]
    elif isOption and short != '\0' and $short in self.shortArgs:
      source = Args
      stringValue = self.shortArgs[$short]
    elif isConfig and name in self.configs:
      source = ConfigFile
      stringValue = self.configs[name]

    setFieldValue(name, value, stringValue, source)


proc unknownOptions*[T](self: var Cliquet[T]): seq[string] =
  ## Get the user's arguments that are not listed as options in the configuration object.

  let optionModes = { Mode.option, Mode.both }
  let definitions = self.configDefinitions.values.toSeq
    .filterIt(it.mode in optionModes)

  let knownLongs = definitions
    .filterIt(not it.shortOnly)
    .mapIt(it.long)
    .toHashSet()

  let knownShorts = definitions
    .filterIt(it.short != '\0')
    .mapIt($it.short)
    .toHashSet()

  for arg in self.longArgs.keys:
    if arg notin knownLongs:
      result.add("--" & arg)

  for arg in self.shortArgs.keys:
    if arg notin knownShorts:
      result.add("-" & arg)


proc unknownConfigs*[T](self: var Cliquet[T]): seq[string] =
  ## Get the user's configurations that do not belong to the configuration object.

  let configModes = { Mode.config, Mode.both }
  let knownConfigs = self.configDefinitions.values.toSeq
    .filterIt(it.mode in configModes)
    .mapIt(it.long)
    .toHashSet()

  for arg in self.configs.keys:
    if arg notin knownConfigs:
      result.add(arg)


proc unmetRequirments*[T](self: var Cliquet[T]): seq[string] =
  ## Get the user's arguments that are required but not provided.

  for definition in self.configDefinitions.values:
    if definition.required and not self.checkRequirement(definition):
      result.add(definition.long)


proc generateUsage*[T: object](self: Cliquet[T]): string =
  ## Generate a usage message for the defined command line options.
  let program = splitFile(getAppFileName()).name
  generateUsage(program, self.namesInOrder, self.configDefinitions)


proc generateConfig*[T: object](self: Cliquet[T]): string =
  ## Generate a default configuration file for the defined settings.
  generateConfig(self.namesInOrder, self.configDefinitions)


proc generateHelp*[T: object](self: Cliquet[T]): string =
  ## Generate a help message for the defined command line options.
  generateHelp(self.namesInOrder, self.configDefinitions)
