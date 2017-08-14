# luash (fork)
<!-- TOC -->

- [About](#about)
- [Install](#install)
- [Simple usage](#simple-usage)
- [Usage](#usage)
	- [Standard use](#standard-use)
	- [Slash - shorthand](#slash---shorthand)
	- [Modulo - direct output](#modulo---direct-output)
	- [Underscore - direct invocation shorthand](#underscore---direct-invocation-shorthand)
- [Command arguments as a table](#command-arguments-as-a-table)
- [Difference between returns](#difference-between-returns)
- ["Quick" reference sheet](#quick-reference-sheet)
- [Command input and pipelines](#command-input-and-pipelines)
- [Aquiring a command() function reference](#aquiring-a-command-function-reference)
- [Additional examples of shorthand](#additional-examples-of-shorthand)
- [Exit status and signal values](#exit-status-and-signal-values)
- [License](#license)

<!-- /TOC -->
## About

Tiny library for shell scripting with Lua (inspired by Python's sh module).

This fork of luash removes the pollution of `_G`, for safer use in unknown environments.

It also improves keyed-table argument parsing, adding support for function references, replacing underscores with dashes in keys, and so forth. Please read below.

Even if you read the README in [zserge/luash](https://github.com/zserge/luash), please read this in its entirety as well.

## Install

Clone this repo and copy sh.lua into your project, or install with `luarocks --local make rockspec/luash-scm-0.rockspec`.

## Simple usage
``` lua
local sh = require("sh")
local pwd, ls = sh("pwd", "ls")
local _ = tostring

local wd = _(pwd()) -- calls `pwd` and returns its output as a string

local files = _(ls("/tmp")) -- calls `ls /tmp`
for f in files:gmatch("[^\n]+") do
	print(f)
end
```
## Usage
### Standard use
This is all you need. You can ignore all the fancy shorthands and utilities explained further down in the README.
```lua
local sh = require("sh")

local wc, grep = sh("wc", "grep") -- ... vararg
local ls = sh.command("ls") -- skips iterating varargs

local filter = "ash" -- bash, dash, etc
-- The following line contains the next 3 chained
local ref = wc(grep(ls("/bin"), filter), "-l")
--local bin = ls("/bin")
--local grepped = grep(bin, filter)
--local ref = wc(grepped, "-l")
print(type(ref)) -- table
local str = tostring(ref) -- __tostring returns the shell output

-- This doesn't work, because it would yield `grep /etc/hosts </tmp/lua_xx`
-- where the tmp file contained the output of tostring(ref).
local chain = grep(ref, "/etc/hosts")
-- This works perfectly, because tostring(ref) contains the output
-- of wc -l, which is simply a number, so this yields
-- `grep 3 /etc/hosts`, for example.
local chain = grep(tostring(ref), "/etc/hosts")
```
### Slash - shorthand
Same as invoking `sh.command("cmd")`. Simple shorthand.
```lua
local sh = require("sh")
local wc, grep, ls = sh/"wc", sh/"grep", sh/"ls"
wc(grep(ls("/bin"), filter), "-l")
```
### Modulo - direct output
`%` always returns the output of the command directly.
```lua
local sh = require("sh")
local stdout = sh%"ls /bin | grep filter | wc -l"
print(type(stdout)) -- string, actual stdout output
local who = sh%"whoami" -- shorthand for tostring(sh("whoami"))
```
### Underscore - direct invocation shorthand
Utility shorthand for fire-and-forget (though execution obviously await the return) commands where you don't care about the return.
```lua
local sh = require("sh")
-- sh._ is meant for fire-and-forget commands like so:
sh._"curl --long --list -o -f --options"
sh._"git push"
-- because these are not valid lua syntax:
sh%"git push"
sh/"git push"
-- and this does not actually execute the command, it returns
-- a function that, when invoked, executes the command
sh "git push"

-- all rets identical
local ret = sh("ls")("/bin")
local ret = sh("ls /bin")
local ret = sh._"ls /bin"
-- table, same as sh("cmd")() returns, pass it on to
-- other command()s for __input chaining
print(type(ret))
-- or __tostring for the output
print(ret)
```
## Command arguments as a table

Key-value arguments can be specified as a keyed hash table, like below.

If your argument table `#` operator returns anything but zero, the table will be considered an indexed array, and key values will be ignored entirely.

```lua
local sh = require("sh")
local foo = sh("foo")
local function getkey(value) return "test_key" end

-- $ foo --format='long' \
--       --interactive \
--       -u=3 \
--       --replace-underscore='real value' \
--       --test-key \
local args = {
	format = "long",
	interactive = true,
	u = 3, -- If keys are strings with a length of 1, they get 1 dash.
	replace_underscore = function(keyName)
		-- keyName="replace_underscore"
		return "real value"
	end,
	[getkey] = true,
	removed = false, -- This does not yield anything.
}

foo(args) -- Executes the command with all arguments in |args|

table.insert(args, "--borked")
print(#args) -- No longer 0, but 1.
foo(args) -- Runs `foo --borked`
```

If either a key or a value in the argument table is a function reference, the function is invoked, with the inverse given as an argument, and no other context.

A key funcref must return a string, or nil.

A value funcref can return a string, boolean, number, or nil.

If either of these functions return nil, the key=value pair will just silently not appear in the constructed command.

## Difference between returns
There is a difference between what is returned when a command reference is invoked, depending on how you do it.

```lua
local sh = require("sh")

-- These return a reference to a command,
-- the command has not yet been executed.
local cmd = sh("cmd") -- or sh.command("cmd")
local cmd = sh/"cmd"

-- 1. These execute the command and populate the
--    __input field
-- 2. Both return a chainable command reference
-- 3. __tostring returns the stdout from the command
--   (same as __input, but trimmed)
cmd(...)
sh._"cmd"

-- % immediately executes the given shell command,
-- and returns a trimmed stdout as a string
local stdout = sh%"cmd"
-- It has no metadata, so this method can not
-- be chained like cmd().
-- You can obviously pass it like this:
cmd({__input = sh%"cmd"}) -- Same as cmd(cmd()), only trimmed
cmd(stdout) -- Or if the next command simply takes a string argument

-- tostring behaves differently if you apply it to a command()
-- function reference, or the return value of a command() call.
local cmd = sh("cmd")
-- Immediately invokes the command in the same manner as
-- sh%"cmd" (does not populate __input)
local run = tostring(cmd)

local stdout = cmd()
-- Let's say $ cmd outputs "  testing foo bar  "
local test = tostring(stdout) -- "testing foo bar", trimmed
local raw = stdout.__input -- "  testing foo bar  "
```

## "Quick" reference sheet
```lua
-- see example.lua as well
local sh = require("sh")
-- Execution always waits for shell commands to return.

-- Note that all the functionality can be done with this:
local ls = sh("ls")
-- There is no need to use the / % or ._ methods, they are
-- only there for fun and .. underpants profit?

-- All produce the same result
local who = sh("whoami")
local who = sh/"whoami"
local who = sh.command("whoami")
-- |who| is a command reference, with custom __call and __tostring handlers
-- __tostring on a command reference executes with zero args, returns trimmed stdout
-- __call(...) returns a chainable reference

local ref = who("--version") -- __call()
local ref = sh._"whoami --version" -- immediately executes and returns reference
-- |ref| is a chainable reference you can pass on to other command()s
-- so that it will pass on its output through stdin

-- All produce the same result, the stdout from the shell command
local ret = tostring(ref)
local ret = sh%"whoami --version" -- immediately executes and returns trimmed stdout
-- |ret| is a string that contains the actual output

-- sh._ is easy to use for fire-and-forget
sh._"curl --download-this --output='file'"
sh._("curl", "--download-this", "--output='file'")
sh._("curl", {
	download_this = true,
	output = "file",
})
sh("curl")("--download-this", "--output='file'")

local foo = sh("foo")
-- $ foo --format='long' --inter_active -u=3
-- All produce the same result
local ref = sh/"foo --format='long' --inter_active -u=3"
local ref = foo("--format='long'", "--inter-active", "-u=3")
local ref = foo({
	format = "long",
	inter_active = true,
	u = 3,
})
-- |ref| is a chainable reference
```
## Command input and pipelines

If a `command()` is given an argument that is a table which has a `__input` key, the value will be used as input (stdin). Even if the table is an indexed array.

Each `command()` returns a table that contains an `__input` field, so nested functions can be used to make a pipeline.

Chained commands are not executed in parallel (because Lua can only handle
one I/O loop at a time). So the inner-most command is executed, its output is
written to a `os.tmpname()` file, read into the `__input` field, and then the outer command is executed, etc.

The `os.tmpname()` file name remains the same throughout your Lua contexts life, but is deleted immediately upon each command invocations return.

``` lua
local sh = require("sh")
local uniq, sort = sh("uniq", "sort")

local words = "foo\nbar\nfoo\nbaz\n"
local u = uniq(sort({__input = words})) -- like $(echo ... | sort | uniq)
print(u) -- prints "bar", "baz", "foo", with newlines between
```

Pipelines can be also written as chained function calls. Lua allows to omit parens, so the syntax can resemble unix shell.

``` lua
local sh = require("sh")
local wc, grep, ls = sh("wc", "grep", "ls")

-- $ ls /bin | grep $filter | wc -l

-- normal syntax
wc(grep(ls("/bin"), filter), "-l")

-- chained syntax
ls("/bin"):grep(filter):wc("-l")

-- Note that chaining commands allocates a new function
-- metatable per chained command, and does not use
-- your local upvalues returned from sh(...)

-- chained syntax without parens
ls "/bin" : grep "filter" : wc "-l"
```
## Aquiring a command() function reference

There are three ways; `sh.command("ls")`, `sh / "ls"`, and the vararg `sh(...)`. The first two are identical. Note that `"ls" / sh` (the inverse) does not work.

The first two are more efficient than the vararg-aware `sh(...)` loop wrapper. All produce exactly the same result, but `sh(...)` can produce multiple results.

``` lua
local sh = require("sh")

local truecmd = sh.command("true") -- because "true" is a Lua keyword
local chrome = sh/"google-chrome" -- because "-" is an operator
-- sh/"cmd" works with or without space around /
local gittag = sh("git tag") -- gittag(...) is same as git("tag", ...)
-- Alternatively
local truecmd, chrome, gittag = sh("true", "google-chrome", "git tag")

gittag("-l") -- list all git tags
```

The obvious reason `sh(...)` escapes my axe is because it's much less verbose, and thus more pleasant in environments where execution speed or efficiency are irrelevant.

## Additional examples of shorthand
```lua
local sh = require("sh")
sh._"sudo rm -rf /"
sh._("sudo", "/bin/reinstall", os.iso_filename())

local ret = sh._'type ls'
-- |ret| is a type string that contains the result of `$ type ls`
assert(ret == "ls is /bin/ls")
```
```lua
local sh = require("sh")
-- syntax error
print(sh/"type ls"())
-- both the below print "ls is /bin/ls"
print((sh/"type ls")())
print(sh/"type ls") -- Works because print() invokes __tostring

sh/"rm -rf /" -- Syntax error

local ref = sh/"type ls"
assert(type(ref) == "table")
tostring(ref) -- Invokes __call on command-reference
print(ref) -- Invokes __tostring, so __call on command-reference
ref() -- Invokes command
```
```lua
local sh = require("sh")

local stringReturn = sh%"type ls"
assert(stringReturn == "ls is /bin/ls")

local typec = sh.command("type")
local convoluted = tostring(typec("ls"))
assert(convoluted == stringReturn)

sh%"rm -rf /" -- Syntax error
```
```lua
local sh = require("sh")
sh._"rm -rf /"
```

## Exit status and signal values

Each command function returns a table with `__exitcode` and `__signal` fields.
Those hold the exit status and signal value as numbers. Zero exit status means
the command was executed successfully.

Since `f:close()` returns exitcode and signal in Lua 5.2 or newer, this will
not work in Lua 5.1 and current LuaJIT.

This fork adds `__cmd` to the return table, which holds the actual command line that was executed, as a string. `__cmd` does not concatenate through chained commands, so `print(ls("/bin"):grep("lol"):wc("-l").__cmd)` will only yield `wc </tmp/lua_DEADBEEF -l`, for example.

## License

Code is distributed under the MIT license.
