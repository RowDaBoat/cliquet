# ISC License
# Copyright (c) 2025 RowDaBoat

import strformat
import config

type InvalidShortOptionsError* = object of ValueError
  arg*: string


type OptionRepeatedError* = object of ValueError
  option*: string


type InvalidValueError* = object of ValueError
  configName*: string
  value*: string
  chosen*: ConfigSource
  expected*: string


proc invalidShortOptions*(arg: string) =
  raise (ref InvalidShortOptionsError)(
    msg: fmt"cliquet: invalid short form arguments: '{arg}'.",
    arg: arg
  )


proc optionRepeated*(option: string) =
  raise (ref OptionRepeatedError)(
    msg: fmt"cliquet: option '{option}' is only allowed once.",
    option: option
  )


proc invalidValue*(configName: string, value: string, chosen: ConfigSource, expected: string) =
  let typ = if chosen == Args: "argument" else: "configuration"
  raise (ref InvalidValueError)(
    msg: fmt"cliquet: invalid value for {typ} '{configName}': '{value}' {expected}.",
    configName: configName,
    value: value,
    chosen: chosen,
    expected: expected
  )


proc typeNotSupported*(typename: string) =
  raise newException(ValueError, fmt"cliquet: type '{typename}' is not supported, this is a bug.")
