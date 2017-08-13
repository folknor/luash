# luash (fork)

Tiny library for shell scripting with Lua (inspired by Python's sh module).

This fork of luash removes the pollution of `_G`, for safer use in unknown environments.

It also simplifies the argument parsing, removing the ability to pass in non-indexed tables that map key:value to key=value.

If you've read the original README, please read this in its entirety as well, because more things have changed.

## Install

Clone this repo and copy sh.lua into your project.

## Simple usage

Every command that can be called via os.execute can be used as a global function.
All the arguments passed into the function become command arguments.

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

If a `command()` is given an argument that is a table which has a `__input` key, the value will be used as input (stdin).

Each `command()` returns a table that contains the `__input` field, so nested functions can be used to make a pipeline.

Note that the commands are not running in parallel (because Lua can only handle
one I/O loop at a time). So the inner-most command is executed, its output is
read, then the outer command is execute with the output redirected, etc.

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

## Commands with tricky names

``` lua
local sh = require("sh")

local truecmd = sh("true") -- because "true" is a Lua keyword
local chrome = sh("google-chrome") -- because "-" is an operator
local gittag = sh("git tag") -- gittag(...) is same as git("tag", ...)
-- Alternatively
local truecmd, chrome, gittag = sh("true", "google-chrome", "git tag")

gittag("-l") -- list all git tags

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
