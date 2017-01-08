local function main()
lootManager = require "./NoLootMode/classes/LootManager"

TableHelper = require "./NoLootMode/classes/TableHelper"


t2 = {}
pos = #t2 + 1
table.insert(t2, pos, {name = 'aaa', val = 1} )
pos = #t2 + 1
table.insert(t2, pos, {name = 'bbb', val = 1})

pos = #t2 + 1
table.insert(t2, pos, {name = 'ccc', val = 1})

pos = #t2 + 1
table.insert(t2, pos, {name = 'ddd', val = 1})
pos = #t2 + 1
table.insert(t2, pos, {name = 'eee', val = 1})

print('before...')
print(dump_table(t2))
TableHelper.removeByColumnValue(t2, 'name', 'aaa')
print('after...')
print(dump_table(t2))

--[[
t1 = {}
t2 = {}
t3 = {}

pos = #t2 + 1
t1.a = 'aa'
table.insert(t2, pos, 'aaa')
t3.a = pos

pos = #t2 + 1
t1.b = 'bb'
table.insert(t2, pos, 'bbb')
t3.b = pos

pos = #t2 + 1
t1.c = 'cc'
table.insert(t2, pos, 'ccc')
t3.c = pos

print(dump_table(t1))
print(dump_table(t2))
print(dump_table(t3))


--removing 

pos = t3.b
table.remove(t2, pos)
t1.b = nil
t3.b = nil

print(dump_table(t1))
print(dump_table(t2))
print(dump_table(t3))

print(type(t1))
--]]

--[[
t4 = {1, 2, 3}
t4['a'] = 100500
--t4.nll = nil
t4.test = function() print('test') end
t4.tb = {"a","b", "c"}
t4.tb.d = {'da', 'db', 'dc', 'dd'}
print (dump_table(t4))

--]]
end

function removeLinkedRow(tbl1, tbl2, linkTbl, key)
    tbl1[key] = nil
    pos = linkTbl[key]
    --table.remove(tbl1
return tbl1, tbl2, linkTbl
end

function dump_table(tbl, indent)
    if result == nil then result = '' end
    if indent == nil then indent = 1 end

    local spaces = string.rep(' ', indent)

    local result = result .. string.rep(' ', indent - 1) .. '{\n'
    for key, value in pairs(tbl) do
        result = result .. spaces .. tostring(key) .. ' => '
        if value == nil then
            result = result .. 'nil'
            break
        elseif type(value) == 'table' then
            result = result .. '(table) ' .. dump_table(value, indent + 1)
        else
            result = result .. '(' .. type(value) .. ') '
            result = result .. tostring(value)
        end
        result = result .. ',\n'
    end
    result = result .. string.rep(' ', indent - 1) .. '}'
    return result
end

function print_table (tbl)
    print ('{')
    for key, value in pairs(tbl) do
        print(tostring(key) .. ' => ' .. tostring(value))
    end
    print ('}')
end

function table_print (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    local sb = {}
    for key, value in pairs (tt) do
      table.insert(sb, string.rep (" ", indent)) -- indent it
      if value == nil then
      table.insert(sb, string.format("\"%s\"\n", "nil..."))
      elseif type (value) == "table" and not done [value] then
        done [value] = true
        table.insert(sb, "{\n");
        table.insert(sb, table_print (value, indent + 2, done))
        table.insert(sb, string.rep (" ", indent)) -- indent it
        table.insert(sb, "}\n");
      elseif "number" == type(key) then
        table.insert(sb, string.format("\"%s\"\n", tostring(value)))
      else
        table.insert(sb, string.format(
            "%s => \"%s\"\n", tostring (key), tostring(value)))
       end
    end
    return table.concat(sb)
  else
    return tt .. "\n"
  end
end

function to_string( tbl )
    if  "nil"       == type( tbl ) then
        return tostring(nil)
    elseif  "table" == type( tbl ) then
        return table_print(tbl)
    elseif  "string" == type( tbl ) then
        return tbl
    else
        return tostring(tbl)
    end
end

main()