# luash (fork)

Tiny library for shell scripting with Lua (inspired by Python's sh module).

This fork of luash removes the pollution of `_G`, for safer use in unknown environments.

It also improves keyed-table argument parsing, adding support for function references, replacing underscores with dashes in keys, and so forth. Please read below.

Even if you read the README in [zserge/luash](https://github.com/zserge/luash), please read this in its entirety as well.

## Install

Clone this repo and copy sh.lua into your project, or install with `luarocks --local make rockspec/luash-scm-0.rockspec`.

## Quick Reference

```lua
local sh = require("sh")

-- Get command references (not yet executed)
local ls = sh("ls")              -- vararg, can do: local ls, wc = sh("ls", "wc")
local ls = sh/"ls"               -- shorthand, same thing
local ls = sh.command("ls")      -- explicit, slightly more efficient

-- Execute and get chainable result table
local ref = ls("/bin")           -- call the command reference
local ref = sh._"ls /bin"        -- shorthand for sh("ls")("/bin")

-- Get stdout as string
local out = tostring(ref)        -- trimmed stdout from result
local out = sh%"ls /bin"         -- execute and return trimmed stdout directly

-- Chaining (nested or piped syntax)
wc(grep(ls("/bin"), "ash"), "-l")
ls("/bin"):grep("ash"):wc("-l")
ls "/bin" : grep "ash" : wc "-l" -- Lua allows omitting parens

-- Fire-and-forget
sh._"curl -O http://example.com/file"
```

That's it. Everything below is just details.

## Standard Usage

```lua
local sh = require("sh")

local wc, grep = sh("wc", "grep")
local ls = sh.command("ls")

local ref = wc(grep(ls("/bin"), "ash"), "-l")
print(type(ref))        -- table
print(tostring(ref))    -- "8" (or whatever the count is)
print(ref.__exitcode)   -- 0
print(ref.__cmd)        -- the actual command that was run
```

## The Operators

### `/` - Command Reference
Same as `sh.command("cmd")`. Returns an unexecuted command reference.
```lua
local wc, grep, ls = sh/"wc", sh/"grep", sh/"ls"
```

### `%` - Direct Output
Executes immediately and returns trimmed stdout as a string.
```lua
local stdout = sh%"ls /bin | grep ash | wc -l"
print(type(stdout)) -- string
```

### `._` - Direct Invocation
Executes immediately and returns the result table. Useful for fire-and-forget or when you need the result but want concise syntax.
```lua
sh._"git push"
sh._"curl --silent -O http://example.com/file"

-- These are equivalent:
local ret = sh("ls")("/bin")
local ret = sh._"ls /bin"
```

Note: `sh%"git push"` and `sh/"git push"` are syntax errors in Lua. Use `sh._` when you need a one-liner that executes.

## Return Values

```lua
local sh = require("sh")

-- Command reference (not yet executed)
local cmd = sh("whoami")
print(type(cmd))  -- table

-- Executed result (has __input, __exitcode, etc)
local result = cmd()
print(type(result))           -- table
print(result.__input)         -- raw stdout
print(tostring(result))       -- trimmed stdout
print(result.__exitcode)      -- 0 on success
print(result.__signal)        -- signal if killed
print(result.__cmd)           -- actual command string

-- Direct string output
local str = sh%"whoami"
print(type(str))  -- string
```

## Command Arguments as a Table

Key-value arguments can be passed as a table. Keys become flags, values become their arguments.

```lua
local foo = sh("foo")

foo({
    format = "long",           -- --format='long'
    interactive = true,        -- --interactive
    u = 3,                     -- -u=3 (single-char keys get one dash)
    replace_underscore = "x",  -- --replace-underscore='x'
    removed = false,           -- (omitted entirely)
})
```

If `#table > 0` (i.e., it has array elements), key-value pairs are ignored and only indexed values are used.

Functions can be used as keys or values - they're called with the inverse as an argument, and returning nil omits that flag.

## Pipelines and Chaining

Commands can be nested or chained. The inner command runs first, its output is passed via temp file to the outer command.

```lua
local uniq, sort = sh("uniq", "sort")

local words = "foo\nbar\nfoo\nbaz\n"
local u = uniq(sort({__input = words}))
print(u) -- bar, baz, foo

-- Chained syntax (allocates new metatables per chain)
ls("/bin"):grep("ash"):wc("-l")

-- Or without parens
ls "/bin" : grep "ash" : wc "-l"
```

Note: Chaining allocates a new function metatable per command and doesn't use your local upvalues from `sh(...)`.

## Exit Status and Signal Values

Each result table has `__exitcode` and `__signal` fields. Zero exit status means success.

Since `f:close()` returns exitcode and signal in Lua 5.2+, this won't work in Lua 5.1 or current LuaJIT.

`__cmd` holds the actual command line that was executed. It doesn't concatenate through chains, so `ls("/bin"):grep("ash"):wc("-l").__cmd` only shows the final `wc` command.

## License

Code is distributed under the MIT license.
