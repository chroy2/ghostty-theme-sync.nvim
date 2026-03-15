local M = {}
local config = require("ghostty-theme-sync.config")

--- Change nvim colorscheme
--- @param colorscheme string: The colorscheme to set in Neovim
local function set_nvim_colorscheme(colorscheme)
	local success, err = pcall(function()
		vim.cmd("colorscheme " .. colorscheme)
	end)
	if not success then
		error("Failed to set nvim colorscheme: ", err)
	end
end

--- Change nvim colorscheme permanently
--- @param colorscheme string: The colorscheme to set in Neovim
local function persist_nvim_colorscheme(colorscheme)
	if not config.options.persist_nvim_theme or not config.options.nvim_config_path then
		error("Please set the nvim config path")
	end

	local path = vim.fn.expand(config.options.nvim_config_path)

	-- Read in config and update colorscheme line
	local lines = {}
	for line in io.lines(path) do
		local leading_whitespace = line:match("^(%s*)vim.cmd.colorscheme")
		if leading_whitespace then
			table.insert(lines, leading_whitespace .. "vim.cmd.colorscheme('" .. colorscheme .. "')")
		else
			table.insert(lines, line)
		end
	end

	-- Write the new config
	local file = io.open(path, "w")
	if not file then
		error("Failed to open nvim config to write")
	end

	for _, line in ipairs(lines) do
		file:write(line .. "\n")
	end
	file:close()
end

--- Change Ghostty config file with new theme
--- @param colorscheme string: The colorscheme to set in the ghostty config
local function set_ghostty_colorscheme(colorscheme)
	local config_path = vim.fn.expand(config.options.ghostty_config_path)

	-- Read in config and update theme line
	local lines = {}
	for line in io.lines(config_path) do
		if line:match("^theme%s*=%s*") then
			table.insert(lines, "theme = " .. colorscheme)
		else
			table.insert(lines, line)
		end
	end

	-- Write the new config
	local file = io.open(config_path, "w")
	if not file then
		error("Failed to open ghostty config to write")
	end

	for _, line in ipairs(lines) do
		file:write(line .. "\n")
	end
	file:close()
end

--- Gets the available colorschemes in Neovim
--- @return table List of colorschemes
local function get_nvim_colorschemes()
	local colorschemes = {}
	local output = vim.fn.getcompletion("", "color")

	for _, scheme in ipairs(output) do
		table.insert(colorschemes, scheme)
	end

	return colorschemes
end

--- Gets the available colorschemes in Neovim
---@return table List of colorschemes
local function get_ghostty_colorschemes()
	local colorschemes = {}
	if not config.options.ghostty_themes_path then
		error("Please set ghostty themes folder path")
	end

	-- get theme path set by user
	local themes_path = vim.fn.expand(config.options.ghostty_themes_path)
	local files = vim.fn.readdir(themes_path)

	for _, file in ipairs(files) do
		table.insert(colorschemes, file)
	end

	return colorschemes
end

--- Get the colorschemes that exist in both Neovim and Ghostty
--- builds an alphanumeric mapping table off of ghostty themes
--- i.e:
--- { githubdarkdefault = {
---         ghostty = "GitHub Dark Default",
---         nvim = "github_dark_default"
--- }
--- @return table List of colorschemes that are available in both Neovim and Ghostty
function M.get_overlap()
	local nvim_colorschemes = get_nvim_colorschemes()
	local ghostty_colorschemes = get_ghostty_colorschemes()

	local alphanumeric_mappings = {}
	for _, ghostty_value in ipairs(ghostty_colorschemes) do
		local normalized = ghostty_value:lower():gsub("[^%w]", "")
		alphanumeric_mappings[normalized] = { ghostty = ghostty_value }
	end

	for _, nvim_value in ipairs(nvim_colorschemes) do
		local normalized = nvim_value:lower():gsub("[^%w]", "")
		if alphanumeric_mappings[normalized] then
			alphanumeric_mappings[normalized].nvim = nvim_value
		end
	end

	-- get those those without both nvim and ghostty
	local overlap = {}
	for _, mapping in pairs(alphanumeric_mappings) do
		if mapping.nvim and mapping.ghostty then
			table.insert(overlap, mapping)
		end
	end
	return overlap
end

--- Set the colorscheme in Neovim and Ghostty
--- @param colorschemes table: The colorscheme to set in Neovim and Ghostty
function M.set_colorscheme(colorschemes)
	set_nvim_colorscheme(colorschemes.nvim)
	if config.options.persist_nvim_theme then
		persist_nvim_colorscheme(colorschemes.nvim)
	end
	set_ghostty_colorscheme(colorschemes.ghostty)
end

--- Opens a select menu to pick a theme to sync out of the valid options
function M.pick_theme()
	local themes = M.get_overlap()
	vim.ui.select(themes, {
		prompt = "Select a theme to sync:",
		format_item = function(item)
			return item.ghostty
		end,
	}, function(selected)
		if selected then
			M.set_colorscheme(selected)
		end
	end)
end

return M
