
-- ------------------------------------------
-- lib_math
--   by: Brian Blose
-- ------------------------------------------

_math = {}

require "math"
require "table"
require "unicode"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_DecimalPoint = Component.LookupText("DECIMAL_POINT")
local c_ThousandSeparator = Component.LookupText("THOUSANDS_SEPARATOR")

local c_Base64Key = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_/"
local c_MaxBaseN = unicode.len(c_Base64Key)

local c_CompactAbbr = {
	"THOUSAND_ABREVIATION",
	"MILLION_ABREVIATION",
	"BILLION_ABREVIATION",
	"TRILLION_ABREVIATION",
}
local c_CompactStart = #c_CompactAbbr

-- ------------------------------------------
-- FUNCTIONS
-- ------------------------------------------
_math.gcd = function(a,b)
	if b ~= 0 then
		return _math.gcd(b, a % b)
	else
		return math.abs(a)
	end
end

_math.lcm = function(a,b)
	if a * b == 0 then
		return 0
	else
		return a * b / _math.gcd(a,b)
	end
end

_math.round = function(num)
	assert(type(num) == "number", "_math.round param 1 needs to be a number")
	return math.floor(num + 0.5)
end

_math.clamp = function(num, min, max)
	assert(type(num) == "number", "_math.clamp param 1 needs to be a number")
	assert(type(min) == "number", "_math.clamp param 2 needs to be a number")
	assert(type(max) == "number", "_math.clamp param 3 needs to be a number")
	assert(min <= max, "_math.clamp param 2 needs to be less then or equal to param 3")
	return math.min(math.max(min, num), max)
end

_math.lerp  = function(a, b, t)
	return a + ( b - a ) * t
end

_math.MakeReadable = function(stock, compact, dec)	
	-- compacts the number value from 12345 to 12.3k
	local abbr
	if compact then
		assert(type(stock) == "number", "_math.MakeReadable: Param 1 must be a number with Compact")
		local length = unicode.len(tostring(math.floor(stock)))
		if length >= 4 then
			local index
			for i=c_CompactStart, 1, -1 do
				if length > 3*i then
					index = i
					break
				end
			end
			
			local divisor = tonumber("1"..unicode.rep("0",index*3))
			stock = tonumber(unicode.format("%0.0"..(dec or 1).."f", stock / divisor))
			abbr = Component.LookupText(c_CompactAbbr[index])
		end
	end
	
	-- returns locale friendly readable numbers ie: 1234567.89 becomes 1,234,567.89 in english or possibly 1.234.567,89 in other languages
	local processed = ""
	if unicode.match(stock, "%.%d+") then
		processed = c_DecimalPoint..unicode.sub(unicode.match(stock, "%.%d+"), 2)
		stock = unicode.gsub(stock, "%.%d+", "")
	end
	while unicode.match(stock, "%d%d%d%d$") do
		processed = c_ThousandSeparator..unicode.match(stock, "%d%d%d$")..processed
		stock = unicode.gsub(stock, "%d%d%d$", "")
	end
	stock = stock..processed
	if abbr then
		stock = stock..abbr
	end
	return stock
end

_math.ArabicToRoman = function(number)
	if( not number ) then
		return "";
	end
	if type(number) ~= "number" then
		error("ArabicToRoman: number is not a number")
		return "ERROR"
	elseif number < 1 then
		error("ArabicToRoman: number is less then 1")
		return "ERROR"
	end
	local conversion = {
		{"M", 1000},
		{"CM", 900},	{"D", 500},		{"CD", 400},	{"C", 100},
		{"XC", 90},		{"L", 50},		{"XL", 40},		{"X", 10},
		{"IX", 9},		{"V", 5},		{"IV", 4},		{"I", 1},
	}
	number = math.floor(number + 0.001) --just enough to prevent float from affecting the floor
	local roman = ""
	for _, tbl in ipairs(conversion) do
		local letter, value = unpack(tbl)
		while number >= value do
			number = number - value
			roman = roman..letter
		end
	end
	return roman
end

_math.RomanToArabic = function(roman)
	if type(roman) ~= "string" then
		error("RomanToArabic: string is not a string")
		return "ERROR"
	end
	local conversion = {M = 1000, D = 500, C = 100, L = 50, X = 10, V = 5, I = 1}
	roman = unicode.upper(roman)
	local number = 0
	local index = 1
	local strlen = unicode.len(roman)
	while index < strlen do
		local a = conversion[unicode.sub(roman,index,index)]
		local b = conversion[unicode.sub(roman,index+1,index+1)]
		if not a or not b then
			error("RomanToArabic: string contains non roman numerals")
			return "ERROR"
		elseif a < b then
			number = number + b - a
			index = index + 2
		else
			number = number + a
			index = index + 1   
		end
	end
	if index == strlen then 
		local a = conversion[unicode.sub(roman,index,index)]
		if not a then
			error("RomanToArabic: string contains non roman numerals")
			return "ERROR"
		else
			number = number + a
		end
	end
	return number
end

_math.Base10ToBaseN = function(start_number, base)
	--Converts a Base10 integer to a BaseN string; ie Base16 is hexadecimal
	if base == true then --if base is true, then encode using base64 broken up into chunks
		local number = tostring(start_number)
		local sign = ""
		if unicode.sub(number, 1, 1) == "-" then
			number = unicode.gsub(number, "^%-", "")
			sign = "-"
		end
		number = unicode.rep("0", (10 - unicode.len(number) % 10))..number
		local encode = ""
		for i = 1, unicode.len(number), 10 do
			local temp = unicode.sub(number, i, i+9)
			temp = _math.Base10ToBaseN(temp, 64)
			temp = unicode.rep("0", 6 - unicode.len(temp)) .. temp
			encode = encode..temp
		end
		encode = unicode.gsub(encode, "^0+", "")
		return sign .. encode
	else --normal Base10ToBaseN to logic
		assert(unicode.len(tostring(start_number)) <= 10, "Base10ToBaseN: number too large, use base of true to compress it in chunks")
		assert(type(base) == "number" and 2 <= base and base <= c_MaxBaseN, "Base10ToBaseN: base needs to be a integer between 2 and "..c_MaxBaseN)
		local number = tonumber(start_number)
		number = math.floor(number)
		base = math.floor(base)
		local str = ""
		local sign = ""
		if number < 0 then
			sign = "-"
			number = -number
		end
		repeat
			local index = (number % base) + 1
			number = math.floor(number / base)
			str = unicode.sub(c_Base64Key, index, index) .. str
		until number == 0
		return sign .. str
	end
end

_math.BaseNToBase10 = function(str, base)
	--Converts a BaseN string to a Base10 integer; ie Base16 is hexadecimal
	str = tostring(str)
	if base == true then --decodes numbers encode using the composite Base10ToBaseN encoding
		local sign = ""
		if unicode.sub(str, 1, 1) == "-" then
			str = unicode.gsub(str, "^%-", "")
			sign = "-"
		end
		str = unicode.rep("0", (6 - unicode.len(str) % 6))..str
		local dec = ""
		for i = 1, unicode.len(str), 6 do
			local temp = unicode.sub(str, i, i+5)
			temp = tostring(_math.BaseNToBase10(temp, 64))
			temp = unicode.rep("0", 10 - unicode.len(temp)) .. temp
			dec = dec..temp
		end
		dec = unicode.gsub(dec, "^0+", "")
		return sign..dec
	else --normal BaseNToBase10 to logic
		assert(type(base) == "number" and 2 <= base and base <= c_MaxBaseN, "BaseNToBase10: base needs to be a integer between 2 and "..c_MaxBaseN)
		base = math.floor(base)
		local multi = 1
		if unicode.sub(str, 1, 1) == "-" then
			str = unicode.gsub(str, "^%-", "")
			multi = -1
		end
		local number = 0
		local length = unicode.len(str)
		for index = length, 1, -1 do
			local digit = unicode.sub(str, index, index)
			local value = unicode.find(c_Base64Key, digit)
			if value then
				value = value - 1
			else
				warn("BaseNToBase10: value contained invalid chars, returning nil")
				return nil
			end
			number = number + (value * (base ^ (length - index)))
		end
		return number * multi
	end
end

--TO DO: Add more easing functions as needed
_math.inOutQuad = function(percent, begin, change)
	percent = percent * 2
	if percent < 1 then
		return change / 2 * percent*percent + begin
	else
		return -change / 2 * ((percent - 1) * (percent - 3) - 1) + begin
	end
end
