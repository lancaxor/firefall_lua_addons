

function LIB_TEST(val)
	log("creating a new libtest");
	local test = {};
	test.vv = val;
	test.Hop = LibTest_Hop;
	return test;
end

function LibTest_Hop(self, param2)
	log("we hopped with "..self.vv.." and "..param2);
end
