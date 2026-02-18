--[[

Provides a unique identifier for a VM.

This currently cannot be tested unless there is some parallel system for jest.

]]

local SharedTableRegistry = game:GetService("SharedTableRegistry")

local shared_table = SharedTableRegistry:GetSharedTable("_gorp_common_vm_count")
shared_table.id = shared_table.id or 0

return SharedTable.increment(shared_table, "id", 1)