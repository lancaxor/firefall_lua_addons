--[[

Funky Instance Name Generator (Fing)
v1.01 by Kristakis
http://AstrekAssociation.com/

This unit can be used in your addons! 
Just put a copy of this file in the same folder as your addon
and put this at the top of your code:

require './fing'

If you have any questions or comments, feel free to 
visit Astrek or PM me on the Firefall forums :)

]]--

-- requires
require "string"
require "math"

-- namespace
fing = {}

-- functions
fing.GetInstanceName = 
	function (InstanceID)
		-- setup variables
		local caLetters = 'auoietbsjnkvhlm';
		local sInstanceID = '';
		if InstanceID == nil then
			sInstanceID = tostring(Chat.GetInstanceID()); 
		else
			sInstanceID = tostring(InstanceID);
		end;
		local iStop = string.len(sInstanceID);
		local iStart = iStop - 5;
		if string.sub(sInstanceID, iStop, iStop)=='7' then iStart=iStart-1; end;
		if string.sub(sInstanceID, iStop, iStop)=='3' then iStart=iStart+1; end;
		local sDisplayName = '';
		if iStart < 1 then iStart = 1; end;
		-- get name
		for i=iStart, iStop do
			if (i%2)==1 then
				sDisplayName = sDisplayName .. string.sub(caLetters, tonumber(string.sub(sInstanceID, i, i))+6, tonumber(string.sub(sInstanceID, i, i))+6);
			else
				sDisplayName = sDisplayName .. string.sub(caLetters, math.ceil((tonumber(string.sub(sInstanceID, i, i))+1)/2), math.ceil((tonumber(string.sub(sInstanceID, i, i))+1)/2));
			end;
		end;
		-- handle missing name
		if sDisplayName=='' then
			sDisplayName=sInstanceID;
		else
			sDisplayName=string.upper(string.sub(sDisplayName, 1, 1))..string.sub(sDisplayName, 2);
		end;
		-- all done
		return sDisplayName;
	end
