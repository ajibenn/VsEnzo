--[[
    TaskManager (ModuleScript)
    Path: ReplicatedStorage → Moon2Cutscene
    Parent: Moon2Cutscene
    ⚠️  NESTED SCRIPT: This script is inside another script
    Exported: 2026-01-28 16:22:14
]]
local module = {}
module.__index = module

type remove = ()->nil

export type manager = {
	register:(self, frame:number|boolean, fn:()->nil) -> remove,
	onEnd:(self, fn:()->nil) -> remove,
}

function module.new() : manager
	return setmetatable({tasks = {}}, module)
end

function module:clone()
	self.cloned = {}
	for i,v in self.tasks do
		self.cloned[i] = v
	end
	
	return self.cloned
end

function module:register(frame:number|boolean, fn:()->nil, cloneOnly:boolean)
	if not cloneOnly then
		self.tasks[frame] = self.tasks[frame] or {}
		table.insert(self.tasks[frame], fn)
	end
	
	if self.cloned then
		self.cloned[frame] = self.cloned[frame] or {}
		table.insert(self.cloned[frame], fn)
	end

	return function()
		if not cloneOnly then
			table.remove(self.tasks, table.find(self.tasks, fn))
		end
		
		if self.cloned then
			table.remove(self.cloned[frame], table.find(self.cloned[frame], fn))
		end
	end
end

function module:onEnd(...)
	return self:register(true, ...)
end

function module.run(tasks)
	for _, fn:()->nil in tasks or {} do
		task.spawn(fn)
	end
end

return module