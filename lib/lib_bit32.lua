
--
-- lib_bit32
--	by: Paul Schultz
--
-- Some bitwise functions to get us by. Inputs are positive integers
--
--[[
-- INTERFACE
--
--	z = bit32.bit(n)			- The nth bit, 1-indexed
--									bit32.bit(1) => 1
--									bit32.bit(4) => 8
--	z = bit32.band(x, y)		- Bitwise AND of x and y
--									bit32.and(3, 15) => 3
--	z = bit32.bor(x, y)			- Bitwise OR of x and y
--									bit32.or(3, 15) => 15
--	z = bit32.bxor(x, y)		- Bitwise XOR of x and y
--									bit32.xor(3, 15) => 12
--	z = bit32.bnot(x, bits)		- Bitwise NOT of x, 'bits' bits long.
--									bit32.not(15, 4) => 0
--									bit32.not(15, 5) => 16
--]]

bit32 = {};

require "math"

local MAX_BIT_WIDTH = 32;
local THIRTY_TWO_BIT_CUTOFF = 2^MAX_BIT_WIDTH;

function bit32.bit(n)
	if (n > MAX_BIT_WIDTH) then
		warn("bit32.bit passed n > "..tostring(MAX_BIT_WIDTH)..", expect a zero");
	end

	return 2^(n - 1) % THIRTY_TWO_BIT_CUTOFF;
end


function bit32.band(x, y)
	local result = 0;
	local exponent = 0;
	
	while (x > 0 or y > 0) do
		if (x % 2 == 1 and y % 2 == 1) then
			result = result + 2^exponent;
		end
		
		x = math.floor(x/2);
		y = math.floor(y/2);
		exponent = exponent + 1;
	end
	
	return result % THIRTY_TWO_BIT_CUTOFF;
end


function bit32.bor(x, y)
	local result = 0;
	local exponent = 0;
	
	while (x > 0 or y > 0) do
		if (x % 2 == 1 or y % 2 == 1) then
			result = result + 2^exponent;
		end
		
		x = math.floor(x/2);
		y = math.floor(y/2);
		exponent = exponent + 1;
	end
	
	return result % THIRTY_TWO_BIT_CUTOFF;
end


function bit32.bxor(x, y)
	local result = 0;
	local exponent = 0;
	
	while (x > 0 or y > 0) do
		if ((x % 2 + y % 2) % 2 == 1) then
			result = result + 2^exponent;
		end
		
		x = math.floor(x/2);
		y = math.floor(y/2);
		exponent = exponent + 1;
	end
	
	return result % THIRTY_TWO_BIT_CUTOFF;
end


function bit32.bnot(x, bits)
	bits = bits or MAX_BIT_WIDTH;
	if (bits > MAX_BIT_WIDTH) then
		bits = MAX_BIT_WIDTH;
	end
	
	local result = 0;
	local exponent = 0;
	
	while (exponent < bits) do
		if (x % 2 == 0) then
			result = result + 2^exponent;
		end
		
		x = math.floor(x/2);
		exponent = exponent + 1;
	end
	
	return result % THIRTY_TWO_BIT_CUTOFF;
end

function bit32.test()



































end

