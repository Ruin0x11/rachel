local fs = require("lib.fs")

local configs = {}

function configs.get_configs()
	local configs = {}
	local n = 0
	for _, file in fs.iter_directory_items("resources/configs") do
		file = fs.normalize(file)
		if file:match("%.rachel$") then
			local atlas_config = assert(loadfile(file))()
			n = n + 1
			configs[n] = {
				file = file,
				config = atlas_config,
			}
		end
	end
	return configs
end

return configs
