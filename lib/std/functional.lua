--[[--
 Functional programming.

 A selection of higher-order functions to enable a functional style of
 programming in Lua.

 @module std.functional
]]


local base     = require "std.base"
local debug    = require "std.debug"
local operator = require "std.operator"

local ipairs, ireverse, len, pairs =
  base.ipairs, base.ireverse, base.len, base.pairs



--- Partially apply a function.
-- @function bind
-- @func fn function to apply partially
-- @tparam table argt table of *fn* arguments to bind
-- @return function with *argt* arguments already bound
-- @usage
-- cube = bind (lambda "^", {[2] = 3})
local function bind (fn, ...)
  local argt = {...}
  if type (argt[1]) == "table" and argt[2] == nil then
    argt = argt[1]
  else
    io.stderr:write (debug.DEPRECATIONMSG ("39",
                       "multi-argument 'std.functional.bind'",
                       "use a table of arguments as the second parameter instead", 2))
  end

  return function (...)
           local arg = {}
           for i, v in pairs (argt) do
             arg[i] = v
           end
           local i = 1
           for _, v in pairs {...} do
             while arg[i] ~= nil do i = i + 1 end
             arg[i] = v
           end
           return fn (unpack (arg))
         end
end


--- Identify callable types.
-- @function callable
-- @param x an object or primitive
-- @return `true` if *x* can be called, otherwise `false`
-- @usage
-- if callable (functable) then functable (args) end
local callable = base.functional.callable


--- A rudimentary case statement.
-- Match *with* against keys in *branches* table.
-- @function case
-- @param with expression to match
-- @tparam table branches map possible matches to functions
-- @return the value associated with a matching key, or the first non-key
--   value if no key matches. Function or functable valued matches are
--   called using *with* as the sole argument, and the result of that call
--   returned; otherwise the matching value associated with the matching
--   key is returned directly; or else `nil` if there is no match and no
--   default.
-- @see cond
-- @usage
-- return case (type (object), {
--   table  = "table",
--   string = function ()  return "string" end,
--            function (s) error ("unhandled type: " .. s) end,
-- })
local function case (with, branches)
  local match = branches[with] or branches[1]
  if callable (match) then
    return match (with)
  end
  return match
end


--- Collect the results of an iterator.
-- @function collect
-- @func[opt=std.ipairs] ifn iterator function
-- @param ... *ifn* arguments
-- @treturn table of results from running *ifn* on *args*
-- @see filter
-- @see map
-- @usage
-- --> {"a", "b", "c"}
-- collect {"a", "b", "c", x=1, y=2, z=5}
local collect = base.functional.collect


--- Compose functions.
-- @function compose
-- @func ... functions to compose
-- @treturn function composition of fnN .. fn1: note that this is the
-- reverse of what you might expect, but means that code like:
--
--     functional.compose (function (x) return f (x) end,
--                         function (x) return g (x) end))
--
-- can be read from top to bottom.
-- @usage
-- vpairs = compose (table.invert, ipairs)
-- for v, i in vpairs {"a", "b", "c"} do process (v, i) end
local function compose (...)
  local arg = {...}
  local fns, n = arg, #arg
  for i = 1, n do
    local f = fns[i]
  end

  return function (...)
           local arg = {...}
           for i = 1, n do
             arg = {fns[i] (unpack (arg))}
           end
           return unpack (arg)
         end
end


--- A rudimentary condition-case statement.
-- If *expr* is "truthy" return *branch* if given, otherwise *expr*
-- itself. If the return value is a function or functable, then call it
-- with *expr* as the sole argument and return the result; otherwise
-- return it explicitly.  If *expr* is "falsey", then recurse with the
-- first two arguments stripped.
-- @function cond
-- @param expr a Lua expression
-- @param branch a function, functable or value to use if *expr* is
--   "truthy"
-- @param ... additional arguments to retry if *expr* is "falsey"
-- @see case
-- @usage
-- -- recursively calculate the nth triangular number
-- function triangle (n)
--   return cond (
--     n <= 0, 0,
--     n == 1, 1,
--             function () return n + triangle (n - 1) end)
-- end
local function cond (expr, branch, ...)
  if branch == nil and select ("#", ...) == 0 then
    expr, branch = true, expr
  end
  if expr then
    if callable (branch) then
      return branch (expr)
    end
    return branch
  end
  return cond (...)
end


--- Curry a function.
-- @function curry
-- @func fn function to curry
-- @int n number of arguments
-- @treturn function curried version of *fn*
-- @usage
-- add = curry (function (x, y) return x + y end, 2)
-- incr, decr = add (1), add (-1)
local function curry (fn, n)
  if n <= 1 then
    return fn
  else
    return function (x)
             return curry (bind (fn, x), n - 1)
           end
  end
end


--- Filter an iterator with a predicate.
-- @function filter
-- @tparam predicate pfn predicate function
-- @func[opt=std.pairs] ifn iterator function
-- @param ... iterator arguments
-- @treturn table elements e for which `pfn (e)` is not "falsey".
-- @see collect
-- @see map
-- @usage
-- --> {2, 4}
-- filter (lambda '|e|e%2==0', std.elems, {1, 2, 3, 4})
local function filter (pfn, ifn, ...)
  local argt = {...}
  if not callable (ifn) then
    ifn, argt = pairs, {ifn, ...}
  end

  local nextfn, state, k = ifn (unpack (argt))
  local t = {nextfn (state, k)}	-- table of iteration 1

  local r = {}			-- new results table
  while t[1] ~= nil do		-- until iterator returns nil
    k = t[1]
    if pfn (unpack (t)) then	-- pass all iterator results to p
      if t[2] ~= nil then
	r[k] = t[2]		-- k,v = t[1],t[2]
      else
	r[#r + 1] = k		-- k,v = #r + 1,t[1]
      end
    end
    t = {nextfn (state, k)}	-- maintain loop invariant
  end
  return r
end


--- Fold a binary function into an iterator.
-- @function reduce
-- @func fn reduce function
-- @param d initial first argument
-- @func ifn iterator function
-- @param ... iterator arguments
-- @return result
-- @see foldl
-- @see foldr
-- @usage
-- --> 2 ^ 3 ^ 4 ==> 4096
-- reduce (lambda '^', 2, std.ipairs, {3, 4})
local reduce = base.functional.reduce


--- Fold a binary function left associatively.
-- If parameter *d* is omitted, the first element of *t* is used,
-- and *t* treated as if it had been passed without that element.
-- @function foldl
-- @func fn binary function
-- @param[opt=t[1]] d initial left-most argument
-- @tparam table t a table
-- @return result
-- @see foldr
-- @see reduce
-- @usage
-- foldl (lambda "/", {10000, 100, 10}) == (10000 / 100) / 10
local function foldl (fn, d, t)
  if t == nil then
    local tail = {}
    for i = 2, len (d) do tail[#tail + 1] = d[i] end
    d, t = d[1], tail
  end
  return reduce (fn, d, ipairs, t)
end


--- Fold a binary function right associatively.
-- If parameter *d* is omitted, the last element of *t* is used,
-- and *t* treated as if it had been passed without that element.
-- @function foldr
-- @func fn binary function
-- @param[opt=t[1]] d initial right-most argument
-- @tparam table t a table
-- @return result
-- @see foldl
-- @see reduce
-- @usage
-- foldr (lambda "/", {10000, 100, 10}) == 10000 / (100 / 10)
local function foldr (fn, d, t)
  if t == nil then
    local u, last = {}, len (d)
    for i = 1, last - 1 do u[#u + 1] = d[i] end
    d, t = d[last], u
  end
  return reduce (function (x, y) return fn (y, x) end, d, ipairs, ireverse (t))
end


--- Identity function.
-- @function id
-- @param ... arguments
-- @return *arguments*
local function id (...)
  return ...
end


--- Memoize a function, by wrapping it in a functable.
--
-- To ensure that memoize always returns the same results for the same
-- arguments, it passes arguments to *fn*. You can specify a more
-- sophisticated function if memoize should handle complicated argument
-- equivalencies.
-- @function memoize
-- @func fn pure function: a function with no side effects
-- @tparam[opt=std.tostring] normalize normfn function to normalize arguments
-- @treturn functable memoized function
-- @usage
-- local fast = memoize (function (...) --[[ slow code ]] end)
local function memoize (fn, normalize)
  if normalize == nil then
    normalize = function (...) return base.tostring {...} end
  end

  return setmetatable ({}, {
    __call = function (self, ...)
               local k = normalize (...)
               local t = self[k]
               if t == nil then
                 t = {fn (...)}
                 self[k] = t
               end
               return unpack (t)
             end
  })
end


--- Compile a lambda string into a Lua function.
--
-- A valid lambda string takes one of the following forms:
--
--   1. `'operator'`: where *op* is a key in @{std.operator}, equivalent to that operation
--   1. `'=expression'`: equivalent to `function (...) return (expression) end`
--   1. `'|args|expression'`: equivalent to `function (args) return (expression) end`
--
-- The second form (starting with `=`) automatically assigns the first
-- nine arguments to parameters `_1` through `_9` for use within the
-- expression body.
--
-- The results are memoized, so recompiling an previously compiled
-- lambda string is extremely fast.
-- @function lambda
-- @string s a lambda string
-- @treturn table compiled lambda string, can be called like a function
-- @usage
-- -- The following are all equivalent:
-- lambda '<'
-- lambda '= _1 < _2'
-- lambda '|a,b| a<b'
local lambda = memoize (function (s)
  local expr

  -- Support operator table lookup.
  if operator[s] then
    return operator[s]
  end

  -- Support "|args|expression" format.
  local args, body = s:match "^|([^|]*)|%s*(.+)$"
  if args and body then
    expr = "return function (" .. args .. ") return " .. body .. " end"
  end

  -- Support "=expression" format.
  if not expr then
    body = s:match "^=%s*(.+)$"
    if body then
      expr = [[
        return function (...)
          local _1,_2,_3,_4,_5,_6,_7,_8,_9 = unpack {...}
	  return ]] .. body .. [[
        end
      ]]
    end
  end

  local ok, fn
  if expr then
    ok, fn = pcall (loadstring (expr))
  end

  -- Diagnose invalid input.
  if not ok then
    return nil, "invalid lambda string '" .. s .. "'"
  end

  return fn
end, id)


--- Map a function over an iterator.
-- @function map
-- @func fn map function
-- @func[opt=std.pairs] ifn iterator function
-- @param ... iterator arguments
-- @treturn table results
-- @see filter
-- @see map_with
-- @see zip
-- @usage
-- --> {1, 4, 9, 16}
-- map (lambda '=_1*_1', std.ielems, {1, 2, 3, 4})
local function map (mapfn, ifn, ...)
  local argt = {...}
  if not callable (ifn) or not next (argt) then
    ifn, argt = pairs, {ifn, ...}
  end

  local nextfn, state, k = ifn (unpack (argt))
  local mapargs = {nextfn (state, k)}

  local r = {}
  while mapargs[1] ~= nil do
    k = mapargs[1]
    local d, v = mapfn (unpack (mapargs))
    if v == nil then d, v = #r + 1, d end
    if v ~= nil then
      r[d] = v
    end
    mapargs = {nextfn (state, k)}
  end
  return r
end


--- Map a function over a table of argument lists.
-- @function map_with
-- @func fn map function
-- @tparam table tt a table of *fn* argument lists
-- @treturn table new table of *fn* results
-- @see map
-- @see zip_with
-- @usage
-- --> {"123", "45"}, {a="123", b="45"}
-- conc = bind (map_with, {lambda '|...|table.concat {...}'})
-- conc {{1, 2, 3}, {4, 5}}, conc {a={1, 2, 3, x="y"}, b={4, 5, z=6}}
local function map_with (mapfn, tt)
  local r = {}
  for k, v in pairs (tt) do
    r[k] = mapfn (unpack (v))
  end
  return r
end


--- No operation.
-- This function ignores all arguments, and returns no values.
-- @function nop
-- @usage
-- if unsupported then vtable["memrmem"] = nop end
local nop = base.nop


--- Zip a table of tables.
-- Make a new table, with lists of elements at the same index in the
-- original table. This function is effectively its own inverse.
-- @function zip
-- @tparam table tt a table of tables
-- @treturn table new table with lists of elements of the same key
--   from *tt*
-- @see map
-- @see zip_with
-- @usage
-- --> {{1, 3, 5}, {2, 4}}, {a={x=1, y=3, z=5}, b={x=2, y=4}}
-- zip {{1, 2}, {3, 4}, {5}}, zip {x={a=1, b=2}, y={a=3, b=4}, z={a=5}}
local function zip (tt)
  local r = {}
  for outerk, inner in pairs (tt) do
    for k, v in pairs (inner) do
      r[k] = r[k] or {}
      r[k][outerk] = v
    end
  end
  return r
end


--- Zip a list of tables together with a function.
-- @function zip_with
-- @tparam function fn function
-- @tparam table tt table of tables
-- @treturn table a new table of results from calls to *fn* with arguments
--   made from all elements the same key in the original tables; effectively
--   the "columns" in a simple list
-- of lists.
-- @see map_with
-- @see zip
-- @usage
-- --> {"135", "24"}, {a="1", b="25"}
-- conc = bind (zip_with, {lambda '|...|table.concat {...}'})
-- conc {{1, 2}, {3, 4}, {5}}, conc {{a=1, b=2}, x={a=3, b=4}, {b=5}}
local function zip_with (fn, tt)
  return map_with (fn, zip (tt))
end


local export = debug.export

--- @export
local M = {
  bind     = export "bind     (func, any?*)",
  callable = callable,
  case     = export "case     (any?, #table)",
  collect  = export "collect  ([func], any*)",
  compose  = export "compose  (func*)",
  cond     = cond,
  curry    = export "curry    (func, int)",
  filter   = export "filter   (func, [func], any*)",
  foldl    = export "foldl    (function, [any], table)",
  foldr    = export "foldr    (function, [any], table)",
  id       = id,
  lambda   = export "lambda   (string)",
  map      = export "map      (func, [func], any*)",
  map_with = export "map_with (function, table of tables)",
  memoize  = export "memoize  (func, func?)",
  nop      = nop,
  reduce   = export "reduce   (func, any, func, any*)",
  zip      = export "zip      (table of tables)",
  zip_with = export "zip_with (function, table of tables)",
}


M.op = operator  -- for backwards compatibility


--[[ ============= ]]--
--[[ Deprecations. ]]--
--[[ ============= ]]--


local DEPRECATED = debug.DEPRECATED


M.eval = DEPRECATED ("41", "'std.functional.eval'",
  "use 'std.eval' instead", base.eval)


M.fold = DEPRECATED ("41", "'std.functional.fold'",
  "use 'std.functional.reduce' instead", reduce)


return M



--- Types
-- @section Types


--- Signature of a @{memoize} argument normalization callback function.
-- @function normalize
-- @param ... arguments
-- @treturn string normalized arguments
-- @usage
-- local normalize = function (name, value, props) return name end
-- local intern = std.functional.memoize (mksymbol, normalize)


--- Signature of a @{filter} predicate callback function.
-- @function predicate
-- @param ... arguments
-- @treturn boolean "truthy" if the predicate condition succeeds,
--   "falsey" otherwise
-- @usage
-- local predicate = lambda '|k,v|type(v)=="string"'
-- local strvalues = filter (predicate, std.pairs, {name="Roberto", id=12345})
