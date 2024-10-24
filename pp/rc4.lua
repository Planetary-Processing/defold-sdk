--[[
	lrc4 - Native Lua/LuaJIT RC4 stream cipher library - https://github.com/CheyiLin/lrc4

	The MIT License (MIT)

	Copyright (c) 2015-2021 Cheyi Lin <cheyi.lin@gmail.com>

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]]

local require = require
local setmetatable = setmetatable

local string_char = string.char
local table_concat = table.concat

local is_luajit
local bit_xor

if jit and jit.version_num > 20000 then
	is_luajit = true
	bit_xor = bit.bxor
elseif _VERSION == "Lua 5.2" then
	bit_xor = bit32.bxor
elseif _VERSION == "Lua 5.3" or _VERSION == "Lua 5.4" then
	--local bitwise = require("bitwise")
	bit_xor = bitwise.xor
else
	bit_xor = bit.bxor
end

local new_ks, rc4_crypt

if is_luajit then
	-- LuaJIT ffi implementation
	local ffi = package.preload.ffi()
	local ffi_string = ffi.string
	local ffi_copy = ffi.copy

	ffi.cdef [[
		typedef struct { uint8_t v; } idx_t;
	]]

	local st_ct = ffi.typeof("uint8_t[256]")
	local idx_ct = ffi.typeof("idx_t")	-- NOTE: boxed uint8_t for the overflow behavoir
	local buf_ct = ffi.typeof("uint8_t[?]")

	new_ks =
		function (key)
			local st = st_ct()
			for i = 0, 255 do st[i] = i end

			local key_len = #key
			local buf = buf_ct(key_len)	-- NOTE: buf_ct(#key, key) will cause segfault and not compiled,
			ffi_copy(buf, key, key_len)	--       separating alloc & copy is safer and faster

			local j = idx_ct()
			for i = 0, 255 do
				j.v = j.v + st[i] + buf[i % key_len]
				st[i], st[j.v] = st[j.v], st[i]
			end

			return {x=idx_ct(), y=idx_ct(), st=st}
		end

	rc4_crypt =
		function (ks, input)
			local x, y, st = ks.x, ks.y, ks.st

			local input_len = #input
			local buf = buf_ct(input_len)
			ffi_copy(buf, input, input_len)

			for i = 0, (input_len - 1) do
				x.v = x.v + 1
				y.v = y.v + st[x.v]
				st[x.v], st[y.v] = st[y.v], st[x.v]
				buf[i] = bit_xor(buf[i], st[(st[x.v] + st[y.v]) % 256])
			end

			return ffi_string(buf, input_len)
		end
else
	-- plain Lua implementation
	new_ks =
		function (key)
			local st = {}
			for i = 0, 255 do st[i] = i end

			local len = #key
			local j = 0
			for i = 0, 255 do
				j = (j + st[i] + key:byte((i % len) + 1)) % 256
				st[i], st[j] = st[j], st[i]
			end

			return {x=0, y=0, st=st}
		end

	rc4_crypt =
		function (ks, input)
			local x, y, st = ks.x, ks.y, ks.st

			local t = {}
			for i = 1, #input do
				x = (x + 1) % 256
				y = (y + st[x]) % 256;
				st[x], st[y] = st[y], st[x]
				t[i] = string_char(bit_xor(input:byte(i), st[(st[x] + st[y]) % 256]))
			end

			ks.x, ks.y = x, y
			return table_concat(t)
		end
end

local function new_rc4(m, key)
	local o = new_ks(key)
	return setmetatable(o, {__call=rc4_crypt, __metatable=false})
end

----
-- @module rc4
--
-- @usage local rc4 = require("rc4")
--        local key = "my_secret"
--        local rc4_enc = rc4(key)
--        local rc4_dec = rc4(key)
--
--        local plain = "plain_text_string"
--        local encrypted = rc4_enc(plain)
--        local decrypted = rc4_dec(encrypted)
--        assert(plain == decrypted)

return setmetatable({}, {__call=new_rc4, __metatable=false})
