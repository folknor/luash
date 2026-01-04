-- Just in case the user has luash installed as well
package.path = "./?.lua;" .. package.path

-- Remember that all arguments to print() are
-- automatically __tostring'd.

local sh = require('sh')
local whoami, pwd, wc, ls, sed, echo, tr = sh("whoami", "pwd", "wc", "ls", "sed", "echo", "tr")
local grep = sh/"grep"

local cmd = sh/"ls"
local r1 = cmd()
local r2 = sh._"ls"
assert(r1.__input == r2.__input, "/() and _ not equal.")

local r1 = sh("ls")("/bin")
local r2 = sh("ls /bin")
local r3 = sh._"ls /bin"

assert(tostring(r1) == tostring(r2), "r1 and r2 mismatch.")
assert(tostring(r2) == tostring(r3), "r2 and r3 mismatch.")

local ash1 = grep(ls("/bin"), "ash")
assert(ash1.__cmd:match("^grep ash </tmp/"), "wrapped command failed.")

local grep = sh("grep") -- ... vararg
local ac = wc(grep(ls("/bin"), "ash"), "-l")
assert(type(ac) == "table", "invalid return, ref not table")

local acs = tostring(ac) -- __tostring returns the shell output
assert(acs == "8", "invalid number of ash'es in /bin")

local ash2 = sh%"ls /bin | grep ash"
assert(type(ash2) == "string", "stdout isn't a string")
-- tostring(ash1) runs it and returns stdout for comparison
assert(tostring(ash1) == ash2, "ashes don't match")

local lst = (sh/"type ls")()

-- These two return stdout as is - no trimming
local lst1 = lst.__input
local lst2 = tostring(lst1)
-- These three return stdout, through a trim ("^%s*(.-)%s*$")
local lst3 = tostring(lst)
local lst4 = tostring(sh/"type ls") -- tostring invokes __tostring which runs it like () and returns output
local lst5 = sh%"type ls" -- % always returns stdout.

assert(lst1 == lst2, "untrimmed stdouts don't match")
assert(lst2 ~= lst3, "untrimmed and trimmed match, which they shouldn't")
assert(lst3 == lst4, "trimmed 3 and 4 don't match")
assert(lst4 == lst5, "trimmed 4 and 5 don't match")

-- local ref = sh/"type ls"
-- assert(type(ref) == "table")
-- print(ref) -- Invokes __tostring
-- ref() -- Invokes __call

-- local ret = sh._'pwd'
-- print(ret)

local stringReturn = sh%"type ls"
assert(stringReturn:match(".-ls is /usr/bin/ls$"))
local typec = sh.command("type")
local convoluted = tostring(typec("ls"))
assert(convoluted == stringReturn)

-- any shell command can be called as a function
print('User:', whoami())
print('Current directory:', pwd())

-- commands can be grouped into the pipeline as nested functions
print('Files in /bin:', wc(ls('/bin'), '-l'))
print('Files in /usr/bin:', wc(ls('/usr/bin'), '-l'))
print('files in both /usr/bin and /bin:', wc(ls('/usr/bin'), ls('/bin'), '-l'))

-- commands can be chained as in unix shell pipeline
local binc1 = ls('/bin'):wc("-l")
-- Lua allows to omit parens
local binc2 = ls '/bin' : wc '-l'

assert(tostring(binc1) == tostring(binc2))

-- intermediate output in the pipeline can be stored into variables
local sedecho = sed(echo('hello', 'world'), 's/world/Lua/g')
assert(tostring(sedecho) == "hello Lua")
assert(sedecho.__exitcode == 0)
local res = tr(sedecho, '[[:lower:]]', '[[:upper:]]')
assert(tostring(res) == "HELLO LUA")

-- command functions can be created dynamically. Optionally, some arguments
-- can be prepended (like partially applied functions)
local e = sh.command('echo')
local greet = sh.command('echo hello')
assert(tostring(e('this', 'is', 'some', 'output')) == "this is some output")

assert(tostring(greet('world')) == "hello world")
assert(tostring(greet('foo')) == "hello foo")
