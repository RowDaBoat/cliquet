# ISC License
# Copyright (c) 2025 RowDaBoat

import options


type ConfigSource* = enum Args, ConfigFile, Default
type Mode* = enum option, config, both

type Config* = object
  long*: string
  short*: char
  shortOnly*: bool
  isSeq*: bool
  typ*: string
  default*: string
  help*: string
  mode*: Mode
  usage*: Option[string]
  required*: bool
