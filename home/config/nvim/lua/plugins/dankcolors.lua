return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '#100F0F',
				base01 = '#100F0F',
				base02 = '#797882',
				base03 = '#797882',
				base04 = '#c7c5d2',
				base05 = '#f9f8ff',
				base06 = '#f9f8ff',
				base07 = '#f9f8ff',
				base08 = '#ff9fb4',
				base09 = '#ff9fb4',
				base0A = '#a296dc',
				base0B = '#9cf0ac',
				base0C = '#dcd4ff',
				base0D = '#a296dc',
				base0E = '#c8bcff',
				base0F = '#c8bcff',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '#797882',
				fg = '#f9f8ff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '#a296dc',
				fg = '#100F0F',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '#797882' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#dcd4ff', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '#c8bcff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '#a296dc',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '#a296dc',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '#dcd4ff',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '#9cf0ac',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '#c7c5d2' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '#c7c5d2' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '#797882',
				italic = true
			})

			local current_file_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"
			if not _G._matugen_theme_watcher then
				local uv = vim.uv or vim.loop
				_G._matugen_theme_watcher = uv.new_fs_event()
				_G._matugen_theme_watcher:start(current_file_path, {}, vim.schedule_wrap(function()
					local new_spec = dofile(current_file_path)
					if new_spec and new_spec[1] and new_spec[1].config then
						new_spec[1].config()
						print("Theme reload")
					end
				end))
			end
		end
	}
}
