# Cliquet

`cliquet` is a tool for building CLI applications from a single configuration object definition, it can:
- parse options from command line arguments in long (`--opt`) and short (`-o`) forms.
- parse settings from a configuration file.
- get defaults from an instance of the configuration object.
- get a merged configuration object prioritizing in the following order: command line arguments, configurations, and defaults.
- build a help message detailing each option, their types, default values, and usage.

`cliquet` is not designed to take over, resolve, and/or automate every possible use case of a command line application, but rather serves as a non-intrusive tool to simplify the creation of one.


## Documentation
The API reference is available [here](https://rowdaboat.github.io/cliquet/).


### Usage
```nim
# Define the configuration object
type Choice = enum yes, no, maybe

type Configuration = object
  flag    {.help: "flags".}                           : bool
  str     {.help: "String arguments".}                : string
  number  {.help: "Float or int arguments".}          : int
  options {.help: "Enums work too".}                  : Choice
  list    {.help: "Lists are also supported".}        : seq[string]
  short   {.help: "Short options", shortOption: 's'.} : bool
```
```nim
# Initialize `cliquet` with the default settings
let defaults = Configuration(
  flag: false,
  str: "Hello",
  number: 10,
  options: Choice.yes,
  list: @["one", "two", "three"],
  short: false
)

var cliquet = initCliquet(defaults)
```
```nim
# Command line arguments are parsed up to the first non-option argument, returning the remaining ones
let remainingArgs = cliquet.parseOptions(commandLineParams())
```
```bash
# A command line for this example looks like this
./example --flag --str="Hello World" --number=10 --options=Maybe --list=one,two,three -s
```
```nim
# Parse configurations, typically obtained from a configuration file
cliquet.parseConfig(readFile("config.ini"))
```
```ini
# A configuration file for this example looks like this
flag 
str     = Hello World
number  = 10 
options = Maybe 
list    = one,two,three
short
# Lines preceded by # are ignored
```
```nim
# Get the final merged configuration object
let configuration = cliquet.generateConfig()
```

```nim
# Get a help message for the defined configuration
let help = cliquet.generateHelp()
```
```
# The help message looks like this:
Options     Type                          Default                Help
--flag      true|false                    false                  flags
--str       text                          Hello                  String arguments
--number    int number                    10                     Float or int arguments
--options   yes|no|maybe                  yes                    Enums work too
--list      ',' separated list of text    "one", "two", "three"  Lists are also supported
-s,--short  true|false                    false                  Short options
```

## (Tentative) Roadmap
- [x] Generate default config file contents
- [x] Allow excluding some config from the options, or the config file
- [x] Generate 'usage' message
- [x] Required options
- [ ] Parse non-option command line arguments?
- [ ] Support for environment variables?
- [ ] Multiple lines support for help messages?
- [ ] Support other configuration formats?
- [ ] Support overriding the type name in the help message?
