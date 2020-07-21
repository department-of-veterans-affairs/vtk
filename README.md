vsp-toolkit
===========

- Add modules like `vsp-toolkit-ops` or `vsp-toolkit-web` for extended functionality!


[![oclif](https://img.shields.io/badge/cli-oclif-brightgreen.svg)](https://oclif.io)
[![Version](https://img.shields.io/npm/v/vsp-toolkit.svg)](https://npmjs.org/package/vsp-toolkit)
[![Downloads/week](https://img.shields.io/npm/dw/vsp-toolkit.svg)](https://npmjs.org/package/vsp-toolkit)
[![License](https://img.shields.io/npm/l/vsp-toolkit.svg)](https://github.com/kfrz/vsp-toolkit/blob/master/package.json)

<!-- toc -->
* [Usage](#usage)
* [Commands](#commands)
<!-- tocstop -->
# Usage
<!-- usage -->
```sh-session
$ npm install -g vsp-toolkit
$ vsptk COMMAND
running command...
$ vsptk (-v|--version|version)
vsp-toolkit/0.0.0 linux-x64 node-v10.15.3
$ vsptk --help [COMMAND]
USAGE
  $ vsptk COMMAND
...
```
<!-- usagestop -->
# Commands
<!-- commands -->
* [`vsptk doctor [FILE]`](#vsptk-doctor-file)
* [`vsptk hello [FILE]`](#vsptk-hello-file)
* [`vsptk help [COMMAND]`](#vsptk-help-command)

## `vsptk doctor [FILE]`

describe the command here

```
USAGE
  $ vsptk doctor [FILE]

OPTIONS
  -f, --force
  -h, --help       show CLI help
  -n, --name=name  name to print
```

_See code: [src/commands/doctor.ts](https://github.com/kfrz/vsp-toolkit/blob/v0.0.0/src/commands/doctor.ts)_

## `vsptk hello [FILE]`

describe the command here

```
USAGE
  $ vsptk hello [FILE]

OPTIONS
  -f, --force
  -h, --help       show CLI help
  -n, --name=name  name to print

EXAMPLE
  $ vsptk hello
  hello world from ./src/hello.ts!
```

_See code: [src/commands/hello.ts](https://github.com/kfrz/vsp-toolkit/blob/v0.0.0/src/commands/hello.ts)_

## `vsptk help [COMMAND]`

display help for vsptk

```
USAGE
  $ vsptk help [COMMAND]

ARGUMENTS
  COMMAND  command to show help for

OPTIONS
  --all  see all commands in CLI
```

_See code: [@oclif/plugin-help](https://github.com/oclif/plugin-help/blob/v3.0.1/src/commands/help.ts)_
<!-- commandsstop -->
