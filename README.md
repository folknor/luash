# luash (fork)

Tiny library for shell scripting with Lua (inspired by Python's sh module).

This fork of luash removes the pollution of `_G`, for safer use in unknown environments.

It also improves keyed-table argument parsing, adding support for function references, replacing underscores with dashes in keys, and so forth. Please read below.

Even if you read the README in [zserge/luash](https://github.com/zserge/luash), please read this in its entirety as well, because more things have changed.

## Install

Clone this repo and copy sh.lua into your project.

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

## Command input and pipelines

If a `command()` is given an argument that is a table which has a `__input` key, the value will be used as input (stdin). Even if the table is an indexed array.

Each `command()` returns a table that contains an `__input` field, so nested functions can be used to make a pipeline.

Chained commands are not executed in parallel (because Lua can only handle
one I/O loop at a time). So the inner-most command is executed, its output is
written to a `os.tmpname()` file, read into the `__input` field, and then the outer command is executed, etc.

The `os.tmpname()` file name remains the same throughout your Lua contexts life, but is deleted immediately upon a command invokations return.

``` lua
local sh = require("sh")
local uniq, sort = sh("uniq", "sort")

local words = "foo\nbar\nfoo\nbaz\n"
local u = uniq(sort({__input = words})) -- like $(echo ... | sort | uniq)
print(u) -- prints "bar", "baz", "foo", with newlines between
```

Pipelines can be also written as chained function calls. Lua allows to omit parens, so the syntax can resemble unix shell:

``` lua
local sh = require("sh")
local wc, grep, ls = sh("wc", "grep", "ls")

-- $ ls /bin | grep $filter | wc -l

-- normal syntax
wc(grep(ls("/bin"), filter), "-l")

-- chained syntax
ls("/bin"):grep(filter):wc("-l")

-- Note that chaining commands allocates a
-- new function closure per command, and does not use
-- your local upvalues returned from sh(...)

-- chained syntax without parens
ls "/bin" : grep "filter" : wc "-l"
```

Quick reference:
```lua
-- see example.lua as well
local sh = require("sh")

-- All produce the same result
local who = sh("whoami")
local who = sh/"whoami"
local who = sh.command("whoami")

-- Produce the same result, immediately invoking
-- the command with no arguments
local str = tostring(who)
print(str)
print(who) -- |who| is a table, but print() invokes __tostring on it

-- All produce the same result
local ret = tostring(who())
local ret = sh%"whoami"
local ret = sh._"whoami"

-- Can be used directly without a syntax error
sh._"curl --download-this" -- Execution hangs until curl returns.

local foo = sh("foo")
-- $ foo --format='long' --inter_active -u=3
-- Both produce the same result
local ret = foo("--format='long'", "--inter-active", "-u=3")
local ret = foo({
	format = "long",
	inter_active = true,
	u = 3,
})
```

## Aquiring a shell-command function reference

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

## Immediate non-standard invocation

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
print(ref) -- Invokes __tostring
ref() -- Invokes __call
```

Another shorthand is `%`:
```lua
local sh = require("sh")

local stringReturn = sh%"type ls"
assert(stringReturn == "ls is /bin/ls")

local typec = sh.command("type")
local convoluted = tostring(typec("ls"))
assert(convoluted == stringReturn)

sh%"rm -rf /" -- Syntax error
```

And yet another is sh._, for the same effect as above, but usable on its own without a variable assignment.
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

## License

Code is distributed under the MIT license.
