# ISC License
# Copyright (c) 2025 RowDaBoat

import tables
import macros
import config
import options


proc getTypeDef(T: NimNode): NimNode =
  result = getTypeInst(T)[1].getImpl

  if result.kind != nnkTypeDef:
    error "cliquet: the provided type is not an object."


proc getObjDef(typeDef: NimNode): NimNode =
  result = typeDef[2]

  if result.kind != nnkObjectTy:
    error "cliquet: the provided type is not an object."


proc getFields(T: NimNode): NimNode =
  let typeDef = getTypeDef(T)
  let objDef = getObjDef(typeDef)
  result = objDef[2]


proc namesAndPragmas(field: NimNode): (NimNode, NimNode) =
  if field[0].kind == nnkPragmaExpr:
    result[0] = field[0][0]
    result[1] = field[0][1]
  else:
    result[0] = field[0]
    result[1] = nil


proc getFieldName(names: NimNode): string =
  if names.kind != nnkIdent:
    error "cliquet: only a single name per field is allowed in the configuration object."

  result = $names


proc getHelp(pragma: NimNode): string =
  if (pragma.kind != nnkCall and pragma.kind != nnkExprColonExpr) or pragma.len != 2:
    error "cliquet: help pragma must have a single argument"

  let helpMsg = pragma[1]
  if not (helpMsg.kind in {nnkStrLit, nnkRStrLit, nnkTripleStrLit}):
    error "cliquet: help pragma must have a string argument"

  result = helpMsg.strVal


proc getShortOption(pragma: NimNode): char =
  if (pragma.kind != nnkCall and pragma.kind != nnkExprColonExpr) or pragma.len != 2:
    error "cliquet: shortOption pragma must have a single argument"

  let shortOptChar = pragma[1]
  if not (shortOptChar.kind == nnkCharLit):
    error "cliquet: shortOption pragma must have a char literal argument"

  result = chr(shortOptChar.intVal)


proc getShortOnly(pragma: NimNode): char =
  if (pragma.kind != nnkCall and pragma.kind != nnkExprColonExpr) or pragma.len != 2:
    error "cliquet: shortOnly pragma must have a single argument"

  let shortOptChar = pragma[1]
  if not (shortOptChar.kind == nnkCharLit):
    error "cliquet: shortOnly pragma must have a char literal argument"

  result = chr(shortOptChar.intVal)


proc getMode(pragma: NimNode): Mode =
  if (pragma.kind != nnkCall and pragma.kind != nnkExprColonExpr) or pragma.len != 2:
    error "cliquet: mode pragma must have a single argument"

  let modeNode = pragma[1]
  if modeNode.kind != nnkSym:
    error "cliquet: mode pragma must be an enum value, " & $modeNode.kind

  let modeStr = $modeNode
  case modeStr
  of "option": result = Mode.option
  of "config": result = Mode.config
  of "both": result = Mode.both
  else: error "cliquet: invalid mode pragma value '" & modeStr & "'"


proc getUsage(pragma: NimNode): Option[string] =
  if (pragma.kind != nnkCall and pragma.kind != nnkExprColonExpr) or pragma.len > 2:
    error "cliquet: usage pragma must have a single string argument or none"

  let usageText = pragma[1]
  if not (usageText.kind == nnkStrLit):
    error "cliquet: usage pragma must have a single string argument or none"

  result = if pragma.len == 1: none[string]() else: some(usageText.strVal)


proc processPragmas(pragmas: NimNode): (string, char, bool, Mode, Option[string], bool) =
  var helpText = ""
  var shortOpt = '\0'
  var shortOnly = false
  var mode = Mode.both
  var usage = none[string]()
  var required = false

  for pragma in pragmas:
    if pragma.kind == nnkSym and $pragma == "required":
      required = true
    elif $pragma[0] == "help":
      helpText &= getHelp(pragma)
    elif $pragma[0] == "shortOption":
      shortOpt = getShortOption(pragma)
    elif $pragma[0] == "shortOnly":
      shortOpt = getShortOnly(pragma)
      shortOnly = true
    elif $pragma[0] == "mode":
      mode = getMode(pragma)
    elif $pragma[0] == "usage":
      usage = getUsage(pragma)

  return (helpText, shortOpt, shortOnly, mode, usage, required)


proc configFrom(configs: NimNode, field: NimNode): NimNode =
  var (names, pragmas) = namesAndPragmas(field)
  var fieldName = getFieldName(names)
  var helpText = ""
  var shortOpt = '\0'
  var shortOnly = false
  var mode = Mode.both
  var usage = none[string]()
  var required = false

  if pragmas != nil and pragmas.kind == nnkPragma:
    (helpText, shortOpt, shortOnly, mode, usage, required) = processPragmas(pragmas)

  result = quote do:
    `configs`.add(Config(
      long: `fieldName`,
      short: `shortOpt`,
      shortOnly: `shortOnly`,
      help: `helpText`,
      mode: `mode`,
      usage: `usage`,
      required: `required`
    ))


macro configsFrom*(T: typedesc): untyped =
  result = newStmtList()

  let configs = genSym(nskVar, "configObj")

  result.add quote do:
    var `configs`: seq[Config] = @[]

  let fields = getFields(T)

  for field in fields:
    if field.kind == nnkIdentDefs:
      result.add configFrom(configs, field)

  result.add(configs)
