describe("Common", function()
	describe("Class creation and use", function()
		it("produces error when parent constructors are not called", function()
			local ParentClass = newClass("ConstructorTestParentClass")
			function ParentClass:ConstructorTestParentClass()
				return self
			end
			local ChildClass = newClass("ConstructorTestProblemChild", "ConstructorTestParentClass")
			function ChildClass:ConstructorTestProblemChild()
				-- Intentionally does not call self:ConstructorTestParentClass()
				return self
			end
			common.classes.ConstructorTestParent = ParentClass
			common.classes.ConstructorTestProblemChild = ChildClass

			assert.has_error(function()
				new("ConstructorTestProblemChild"):ConstructorTestProblemChild()
			end, "Parent class 'ConstructorTestParentClass' of class 'ConstructorTestProblemChild' must be initialised")
			common.classes.ConstructorTestParent = nil
			common.classes.ConstructorTestProblemChild = nil
		end)
		it("produces an error if additional arguments are passed", function()
			local StupidClass = newClass("NewAbuse")
			function StupidClass:NewAbuse(someParam)
				return self
			end

			common.classes.NewAbuse = StupidClass

			assert.has_no.errors(function()
				local newObj = new("NewAbuse"):NewAbuse("fish")
			end)
			assert.has_error(function()
				local newObj = new("NewAbuse", "look I'm using the old syntax")
			end)
		end)
		it("produces an error if it calls a parent class without giving it self", function()
			local ParentClass = newClass("ConstructorTestParentClass")
			function ParentClass:ConstructorTestParentClass()
				return self
			end

			local ChildClass = newClass("ConstructorTestProblemChild", "ConstructorTestParentClass")
			function ChildClass:ConstructorTestProblemChild()
				self.ConstructorTestParentClass()
				return self
			end

			common.classes.ConstructorTestParent = ParentClass
			common.classes.ConstructorTestProblemChild = ChildClass

			assert.has_error(function()
				new("ConstructorTestProblemChild"):ConstructorTestProblemChild()
			end)
			common.classes.ConstructorTestParent = nil
			common.classes.ConstructorTestProblemChild = nil
		end)
		it("produces an error if its constructor doesn't return the object", function()
			local StupidClass = newClass("StupidClass")
			function StupidClass:StupidClass()
			end

			common.classes.StupidClass = StupidClass

			assert.has_error(function()
				new("StupidClass"):StupidClass()
			end, "Class StupidClass constructor did not return a value")
		end)
		-- disabled for performance reasons for now
		-- it("produces an error if its constructor has not been called", function()
		-- 	local StupidClass = newClass("StupidClass")
		-- 	function StupidClass:StupidClass()
		-- 		return self
		-- 	end

		-- 	function StupidClass:Clear()
		-- 	end

		-- 	common.classes.StupidClass = StupidClass

		-- 	assert.has_error(function()
		-- 		local object = new("StupidClass")
		-- 		return object.lines
		-- 	end)
		-- 	assert.has_error(function()
		-- 		local object = new("StupidClass")
		-- 		object:Clear()
		-- 	end)
		-- 	assert.has_no.errors(function()
		-- 		local object = new("StupidClass"):StupidClass()
		-- 		local x = object.lines
		-- 		object:Clear()
		-- 	end)
		-- 	common.classes.StupidClass = nil
		-- end)
	end)
	describe("Deflate and Inflate", function()
		it("round-trips a simple string", function()
			local text = "Hello my name is ????!"
			local compressed = Deflate(text)
			assert.is_not_nil(compressed)
			assert.are.equal(text, Inflate(compressed))
		end)
		it("produces a zlib header", function()
			local compressed = Deflate("some data to compress")
			assert.are.equal(0x78, compressed:byte(1))
		end)
		it("round-trips an empty string", function()
			local compressed = Deflate("")
			assert.is_not_nil(compressed)
			assert.are.equal("", Inflate(compressed))
		end)
		it("round-trips data larger than the 16k buffer", function()
			local text = string.rep("The quick brown fox jumps over the lazy dog. ", 5000)
			local compressed = Deflate(text)
			assert.is_true(#compressed < #text)
			assert.are.equal(text, Inflate(compressed))
		end)
		it("round-trips binary data", function()
			local bytes = {}
			for i = 0, 255 do
				bytes[i + 1] = string.char(i)
			end
			local text = table.concat(bytes)
			assert.are.equal(text, Inflate(Deflate(text)))
		end)
	end)
end)