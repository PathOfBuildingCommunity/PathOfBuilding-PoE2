-- Path of Building
--
-- Module: Style
-- Styles of Fonts and Colors used by various Classes.
--

---@alias Style
---| "'text'"
---| "'text_disabled'"
---| "'text_positive'"
---| "'text_negative'"
---| "'text_protected'"
---| "'text_label'"
---| "'text_label_disabled'"
---| "'text_heading'"
---| "'text_toast'"
---| "'text_toast_heading'"
---| "'text_popup_title'"
---| "'text_section_title'"
---| "'text_current_build'"
---| "'text_button'"
---| "'text_button_disabled'"
---| "'text_dropdown'"
---| "'text_dropdown_disabled'"
---| "'text_dropdown_lowered'"
---| "'text_list'"
---| "'text_list_placeholder'"
---| "'text_list_column_label'"
---| "'text_textlist'"
---| "'text_textbox'"
---| "'text_textbox_disabled'"
---| "'text_textbox_placeholder'"
---| "'text_textbox_selection'"
---| "'search_text_highlight_overlay'"
---| "'selection_text_highlight_background'"
---| "'list_background'"
---| "'list_background_selected'"
---| "'list_background_drag_targeted'"
---| "'list_border'"
---| "'list_border_selected'"
---| "'list_border_drag_targeted'"
---| "'list_dragindex'"
---| "'list_dragindex_center'"
---| "'list_entry_background'"
---| "'list_entry_background_even'"
---| "'list_entry_background_selected'"
---| "'list_entry_background_focused'"
---| "'list_entry_background_hover'"
---| "'list_entry_border'"
---| "'list_entry_border_selected'"
---| "'list_entry_border_focused'"
---| "'list_entry_border_hover'"
---| "'list_column_label_background'"
---| "'list_column_label_background_hover'"
---| "'list_column_label_border'"
---| "'list_column_label_border_hover'"
---| "'textlist_background'"
---| "'textlist_border'"
---| "'textbox_background'"
---| "'textbox_background_disabled'"
---| "'textbox_background_selected'"
---| "'textbox_background_hover'"
---| "'textbox_border'"
---| "'textbox_border_disabled'"
---| "'textbox_border_selected'"
---| "'textbox_border_hover'"
---| "'dropdown_background'"
---| "'dropdown_background_disabled'"
---| "'dropdown_background_toggled'"
---| "'dropdown_background_clicked'"
---| "'dropdown_background_hover'"
---| "'dropdown_border'"
---| "'dropdown_border_disabled'"
---| "'dropdown_border_toggled'"
---| "'dropdown_border_clicked'"
---| "'dropdown_border_hover'"
---| "'dropdown_arrow'"
---| "'dropdown_arrow_disabled'"
---| "'dropdown_arrow_hover'"
---| "'checkbox_background'"
---| "'checkbox_background_disabled'"
---| "'checkbox_background_toggled'"
---| "'checkbox_background_clicked'"
---| "'checkbox_background_hover'"
---| "'checkbox_border'"
---| "'checkbox_border_disabled'"
---| "'checkbox_border_toggled'"
---| "'checkbox_border_clicked'"
---| "'checkbox_border_hover'"
---| "'checkbox_checkmark'"
---| "'checkbox_checkmark_disabled'"
---| "'checkbox_checkmark_hover'"
---| "'checkbox_checkimage'"
---| "'checkbox_checkimage_disabled'"
---| "'checkbox_checkimage_toggled'"
---| "'checkbox_checkimage_hover'"
---| "'slider_background'"
---| "'slider_background_disabled'"
---| "'slider_background_selected'"
---| "'slider_background_hover'"
---| "'slider_border'"
---| "'slider_border_disabled'"
---| "'slider_border_selected'"
---| "'slider_border_hover'"
---| "'slider_knob'"
---| "'slider_knob_disabled'"
---| "'slider_knob_selected'"
---| "'slider_knob_hover'"
---| "'slider_section_separator'"
---| "'scrollbar_background'"
---| "'scrollbar_background_disabled'"
---| "'scrollbar_background_selected'"
---| "'scrollbar_background_hover'"
---| "'scrollbar_border'"
---| "'scrollbar_border_disabled'"
---| "'scrollbar_border_selected'"
---| "'scrollbar_border_hover'"
---| "'scrollbar_knob'"
---| "'scrollbar_knob_disabled'"
---| "'scrollbar_knob_selected'"
---| "'scrollbar_knob_hover'"
---| "'scrollbar_arrow'"
---| "'scrollbar_arrow_disabled'"
---| "'scrollbar_arrow_selected'"
---| "'scrollbar_arrow_hover'"
---| "'scrollbar_arrow_background'"
---| "'scrollbar_arrow_background_disabled'"
---| "'scrollbar_arrow_background_selected'"
---| "'scrollbar_arrow_background_hover'"
---| "'scrollbar_arrow_border'"
---| "'scrollbar_arrow_border_disabled'"
---| "'scrollbar_arrow_border_selected'"
---| "'scrollbar_arrow_border_hover'"
---| "'button_background'"
---| "'button_background_disabled'"
---| "'button_background_toggled'"
---| "'button_background_clicked'"
---| "'button_background_hover'"
---| "'button_border'"
---| "'button_border_disabled'"
---| "'button_border_toggled'"
---| "'button_border_clicked'"
---| "'button_border_hover'"
---| "'button_raised_background'"
---| "'button_raised_background_disabled'"
---| "'button_raised_background_toggled'"
---| "'button_raised_background_clicked'"
---| "'button_raised_background_hover'"
---| "'button_raised_border'"
---| "'button_raised_border_disabled'"
---| "'button_raised_border_toggled'"
---| "'button_raised_border_clicked'"
---| "'button_raised_border_hover'"
---| "'button_image'"
---| "'button_image_disabled'"
---| "'button_image_overlay_clicked'"
---| "'dragger_background'"
---| "'dragger_background_disabled'"
---| "'dragger_background_dragged'"
---| "'dragger_background_hover'"
---| "'dragger_border'"
---| "'dragger_border_disabled'"
---| "'dragger_border_dragged'"
---| "'dragger_border_hover'"
---| "'dragger_knob'"
---| "'dragger_knob_disabled'"
---| "'dragger_knob_dragged'"
---| "'dragger_knob_hover'"
---| "'dragger_knobimage'"
---| "'dragger_knobimage_disabled'"
---| "'dragger_knobimage_overlay_dragged'"
---| "'rectangle_outline_border'"
---| "'popup_background'"
---| "'popup_background_title'"
---| "'popup_border'"
---| "'popup_border_title'"
---| "'section_background'"
---| "'section_background_title'"
---| "'section_border'"
---| "'section_border_title'"
---| "'tooltip_border'"
---| "'tooltip_background'"
---| "'toast_border'"
---| "'toast_background'"
---| "'main_control_border'"
---| "'main_control_background'"
---| "'top_bar_border'"
---| "'top_bar_background'"
---| "'side_bar_border'"
---| "'side_bar_background'"
---| "'bottom_bar_border'"
---| "'bottom_bar_background'"
---| "'current_build_box_border'"
---| "'current_build_box_background'"
---| "'points_box_border'"
---| "'points_box_background'"

local alignments = {
	LEFT = "LEFT",
	CENTER = "CENTER",
	RIGHT = "RIGHT",
	CENTER_X = "CENTER_X",
	RIGHT_X = "RIGHT_X"
}
local fonts = {
	FIXED = "FIXED",
	VAR = "VAR",
	VAR_BOLD = "VAR BOLD",
	FONTIN_SC = "FONTIN SC",
	FONTIN_SC_ITALIC = "FONTIN SC ITALIC",
	FONTIN = "FONTIN",
	FONTIN_ITALIC = "FONTIN ITALIC"
}

-- local base_colors = {
local colors = {
	transparent = "#00000000",
	black = "#000000",         	-- 0% brightness
	light_black = "#0D0D0D",		-- 5% brightness
	dark = "#1A1A1A",          	-- 10% brightness
	darkest_grey = "#262626",  	-- 15% brightness
	darker_grey = "#343434",   	-- 20% brightness
	dark_grey = "#545454",     	-- 33% brightness
	grey = "#808080",          	-- 50% brightness
	grey_alternative = "#999999", 	-- 66% brightness
	light_grey = "#C8C8C8",    	-- ~80% brightness -- identical to normal rarity
	lighter_grey = "#D9D9D9",		-- ~85% brightness
	light = "#E2E2E2",         	-- ~90% brightness
	white = "#FFFFFF",				-- 100% brightness
	black_50 = "#00000080",		 	 -- 0% brightness, 50% opacity
	black_85 = "#000000D9",			 -- 0% brightness, 85% opacity
	white_50 = "#FFFFFF80",			 -- 100% brightness, 50% opacity
	yellow_overlay = "#FFFF0033",
	blue_highlight = "#7393B3",
	red_highlight = "#C08080",
	brownish = "#804D00",
	green_black = "#000D00",
	dark_green = "#349934",
}

-- poe2trade uses font FontinSmallcaps everywhere
local poe2trade_colors = {
	button_raised_disabled = "#533e22",
	button_raised_enabled = "#5a3806",
	button_raised_hover = "#e9cf9f", -- navigation
	button_raised_active = "#24211e80",
	clickable_background_disabled = "#1e2124c0",
	clickable_enabled = "#1e2124",
	clickable_background_hover = "#2d3136",
	clickable_active = "#646e77",
	row_background = "#0e0f10",
	row_background_transparency = "#2d31364d",
	white_warm = "#fff8e1", -- label
	brown = "#634928",   -- accent / separator/border
	brown_transparancy = "#63492899",
	tooltip_border = "#6f6959",
}

local themes = {
	classic = {
		-- text
		text = {color = colors.white, font = fonts.VAR},
		text_disabled = {color = colors.dark_grey, font = fonts.VAR},
		text_dropdown_lowered = {color = colors.grey_alternative, font = fonts.VAR},
		text_positive = {color = colorCodes.POSITIVE, font = fonts.VAR},
		text_negative = {color = colorCodes.NEGATIVE, font = fonts.VAR},
		text_protected = {color = colors.white, font = fonts.FIXED},
		text_label = {color = colors.white, font = fonts.VAR},
		text_label_disabled = {color = colors.dark_grey, font = fonts.VAR},
		text_heading = {color = colors.white, font = fonts.VAR},
		text_toast = {color = colors.white, font = fonts.VAR},
		text_toast_heading = {color = colors.white, font = fonts.VAR},
		text_popup_title = {color = colors.white, font = fonts.VAR},
		text_section_title = {color = colors.white, font = fonts.VAR},
		text_current_build = {color = colors.white, font = fonts.VAR},
		text_button = {color = colors.white, font = fonts.VAR},
		text_button_disabled = {color = colors.dark_grey, font = fonts.VAR},
		text_dropdown = {color = colors.white, font = fonts.VAR},
		text_dropdown_disabled = {color = colors.dark_grey, font = fonts.VAR},
		text_list = {color = colors.white, font = fonts.VAR},
		text_list_placeholder = {color = colors.grey, font = fonts.VAR},
		text_list_column_label = {color = colors.white, font = fonts.VAR},
		text_textlist = {color = colors.white, font = fonts.VAR},
		text_textbox = {color = colors.white, font = fonts.VAR},
		text_textbox_disabled = {color = colors.dark_grey, font = fonts.VAR},
		text_textbox_placeholder = {color = colors.dark_grey, font = fonts.VAR},
		text_textbox_selection = {color = colors.black, font = fonts.VAR},
		search_text_highlight_overlay = colors.yellow_overlay,
		selection_text_highlight_background = colors.light_grey,
		-- list background
		list_background = colors.black,
		list_background_selected = colors.black,
		list_background_drag_targeted = colors.green_black,
		-- list border
		list_border = colors.grey,
		list_border_selected = colors.white,
		list_border_drag_targeted = colors.dark_green,
		-- list dragindex
		list_dragindex = colors.white,
		list_dragindex_center = colors.black,
		-- list entry background
		list_entry_background = colors.black,
		list_entry_background_even = colors.light_black,
		list_entry_background_selected = colors.darkest_grey,
		list_entry_background_focused = colors.dark_grey,
		list_entry_background_hover = colors.darkest_grey,
		-- list entry border
		list_entry_border = colors.white, -- not used yet
		list_entry_border_selected = colors.grey,
		list_entry_border_focused = colors.white,
		list_entry_border_hover = colors.light_grey,
		-- list column label background
		list_column_label_background = colors.darkest_grey,
		list_column_label_background_hover = colors.dark_grey,
		-- list column label border
		list_column_label_border = colors.grey,
		list_column_label_border_hover = colors.white,
		-- textlist background
		textlist_background = colors.light_black,
		-- textlist border
		textlist_border = colors.grey_alternative,
		-- textbox background
		textbox_background = colors.black,
		textbox_background_disabled = colors.black,
		textbox_background_selected = colors.dark,
		textbox_background_hover = colors.dark,
		-- textbox border
		textbox_border = colors.grey,
		textbox_border_disabled = colors.dark_grey,
		textbox_border_selected = colors.white,
		textbox_border_hover = colors.white,
		textbox_border_highlight = colors.blue_highlight,
		textbox_border_highlight_negative = colors.red_highlight,
		-- dropdown background
		dropdown_background = colors.black,
		dropdown_background_disabled = colors.black,
		dropdown_background_toggled = colors.dark_grey,
		dropdown_background_clicked = colors.grey,
		dropdown_background_hover = colors.dark_grey,
		-- dropdown border
		dropdown_border = colors.grey,
		dropdown_border_disabled = colors.dark_grey,
		dropdown_border_toggled = colors.white,
		dropdown_border_clicked = colors.grey,
		dropdown_border_hover = colors.white,
		dropdown_border_highlight = colors.blue_highlight,
		dropdown_border_highlight_negative = colors.red_highlight,
		-- dropdown arrow
		dropdown_arrow = colors.light_grey,
		dropdown_arrow_disabled = colors.dark_grey,
		dropdown_arrow_hover = colors.white,
		-- checkbox background
		checkbox_background = colors.black,
		checkbox_background_disabled = colors.black,
		checkbox_background_toggled = colors.dark_grey,
		checkbox_background_clicked = colors.grey,
		checkbox_background_hover = colors.dark_grey,
		-- checkbox border
		checkbox_border = colors.grey,
		checkbox_border_disabled = colors.dark_grey,
		checkbox_border_toggled = colors.light_grey,
		checkbox_border_clicked = colors.grey,
		checkbox_border_hover = colors.white,
		checkbox_border_highlight = colors.blue_highlight,
		checkbox_border_highlight_negative = colors.red_highlight,
		-- checkbox checkmark
		checkbox_checkmark = colors.light_grey,
		checkbox_checkmark_disabled = colors.dark_grey,
		checkbox_checkmark_hover = colors.white,
		-- checkbox checkimage
		checkbox_checkimage = colors.grey,
		checkbox_checkimage_disabled = colors.dark_grey,
		checkbox_checkimage_toggled = colors.white,
		checkbox_checkimage_hover = colors.white,
		-- slider background
		slider_background = colors.black,
		slider_background_disabled = colors.black,
		slider_background_selected = colors.black,
		slider_background_hover = colors.black,
		-- slider border
		slider_border = colors.grey,
		slider_border_disabled = colors.dark_grey,
		slider_border_selected = colors.white,
		slider_border_hover = colors.white,
		-- slider knob
		slider_knob = colors.grey,
		slider_knob_disabled = colors.dark_grey,
		slider_knob_selected = colors.white,
		slider_knob_hover = colors.white,
		slider_section_separator = colors.dark_grey,
		-- scrollbar background
		scrollbar_background = colors.black,
		scrollbar_background_disabled = colors.black,
		scrollbar_background_selected = colors.black,
		scrollbar_background_hover = colors.black,
		-- scrollbar border
		scrollbar_border = colors.grey,
		scrollbar_border_disabled = colors.dark_grey,
		scrollbar_border_selected = colors.white,
		scrollbar_border_hover = colors.white,
		-- scrollbar knob
		scrollbar_knob = colors.grey,
		scrollbar_knob_disabled = colors.dark_grey,
		scrollbar_knob_selected = colors.white,
		scrollbar_knob_hover = colors.white,
		-- scrollbar arrow
		scrollbar_arrow = colors.grey,
		scrollbar_arrow_disabled = colors.dark_grey,
		scrollbar_arrow_selected = colors.white,
		scrollbar_arrow_hover = colors.white,
		-- scrollbar arrow background
		scrollbar_arrow_background = colors.black,
		scrollbar_arrow_background_disabled = colors.black,
		scrollbar_arrow_background_selected = colors.dark_grey,
		scrollbar_arrow_background_hover = colors.dark_grey,
		-- scrollbar arrow border
		scrollbar_arrow_border = colors.grey,
		scrollbar_arrow_border_disabled = colors.dark_grey,
		scrollbar_arrow_border_selected = colors.white,
		scrollbar_arrow_border_hover = colors.white,
		-- button background
		button_background = colors.black,
		button_background_disabled = colors.black,
		button_background_toggled = colors.dark_grey,
		button_background_clicked = colors.grey,
		button_background_hover = colors.dark_grey,
		-- button border
		button_border = colors.grey,
		button_border_disabled = colors.dark_grey,
		button_border_toggled = colors.white,
		button_border_clicked = colors.grey,
		button_border_hover = colors.white,
		-- button raised background
		button_raised = colors.white,
		button_raised_disabled = colors.dark_grey,
		button_raised_toggled = colors.dark_grey,
		button_raised_clicked = "#FFFFFF80",
		button_raised_hover = colors.dark_grey,
		-- button raised border
		button_raised_border = colors.white,
		button_raised_border_disabled = colors.dark_grey,
		button_raised_border_toggled = colors.dark_grey,
		button_raised_border_clicked = "#FFFFFF80",
		button_raised_border_hover = colors.dark_grey,
		-- button image
		button_image = colors.white,
		button_image_disabled = colors.dark_grey,
		button_image_overlay_clicked = colors.white_50,
		-- dragger background
		dragger_background = colors.black,
		dragger_background_disabled = colors.black,
		dragger_background_dragged = colors.grey,
		dragger_background_hover = colors.dark_grey,
		-- dragger border
		dragger_border = colors.grey,
		dragger_border_disabled = colors.dark_grey,
		dragger_border_dragged = colors.white,
		dragger_border_hover = colors.white,
		-- dragger knob
		dragger_knob = colors.grey,
		dragger_knob_disabled = colors.dark_grey,
		dragger_knob_dragged = colors.white,
		dragger_knob_hover = colors.white,
		-- dragger knobimage
		dragger_knobimage = colors.white,
		dragger_knobimage_disabled = colors.dark_grey,
		dragger_knobimage_overlay_dragged = colors.white_50,
		-- rectangle outline
		rectangle_outline_border = colors.white,
		-- popup background
		popup_background = colors.dark,
		popup_background_title = colors.black,
		-- popup border
		popup_border = colors.light_grey,
		popup_border_title = colors.white,
		-- section background
		section_background = colors.dark,
		section_background_title = colors.black,
		-- section border
		section_border = colors.grey_alternative,
		section_border_title = colors.grey_alternative,
		-- tooltip
		tooltip_background = colors.black_85,
		tooltip_border = colors.brownish,
		-- toast (popups in the bottom left corner)
		toast_background = colors.dark,
		toast_border = colors.lighter_grey,
		-- main control (bottom left corner)
		main_control_background = colors.dark,
		main_control_border = colors.lighter_grey,
		-- top bar
		top_bar_background = colors.darker_grey,
		top_bar_border = colors.lighter_grey,
		-- side bar
		side_bar_background = colors.dark,
		side_bar_border = colors.lighter_grey,
		-- bottom bar
		bottom_bar_background = colors.light_black,
		bottom_bar_border = colors.lighter_grey,
		-- current build (box behind build name)
		current_build_box_background = colors.black,
		current_build_box_border = colors.grey,
		-- points (box behind skill points at the top)
		points_box_background = colors.black,
		points_box_border = colors.grey,
	},
	dark = {
		-- text
		text = {color = colors.light, font = fonts.FONTIN_SC},
		text_disabled = {color = colors.grey, font = fonts.FONTIN_SC},
		text_dropdown_lowered = {color = colors.grey_alternative, font = fonts.FONTIN_SC},
		text_positive = {color = colorCodes.POSITIVE, font = fonts.FONTIN_SC},
		text_negative = {color = colorCodes.NEGATIVE, font = fonts.FONTIN_SC},
		text_protected = {color = colors.light, font = fonts.FIXED},
		text_label = {color = poe2trade_colors.white_warm, font = fonts.FONTIN_SC},
		text_label_disabled = {color = colors.grey, font = fonts.FONTIN_SC},
		text_heading = {color = poe2trade_colors.button_raised_hover, font = fonts.FONTIN_SC},
		text_toast = {color = colors.light, font = fonts.FONTIN},
		text_toast_heading = {color = colors.white, font = fonts.FONTIN},
		text_popup_title = {color = poe2trade_colors.button_raised_hover, font = fonts.FONTIN_SC},
		text_section_title = {color = poe2trade_colors.button_raised_hover, font = fonts.FONTIN_SC},
		text_current_build = {color = colors.light, font = fonts.FONTIN},
		text_button = {color = colors.light, font = fonts.FONTIN_SC},
		text_button_disabled = {color = colors.grey, font = fonts.FONTIN_SC},
		text_dropdown = {color = colors.light, font = fonts.FONTIN_SC},
		text_dropdown_disabled = {color = colors.grey, font = fonts.FONTIN_SC},
		text_list = {color = colors.light, font = fonts.FONTIN_SC},
		text_list_placeholder = {color = colors.grey, font = fonts.FONTIN},
		text_list_column_label = {color = colors.light, font = fonts.FONTIN_SC},
		text_textlist = {color = colors.light, font = fonts.FONTIN},
		text_textbox = {color = colors.light, font = fonts.FONTIN},
		text_textbox_disabled = {color = colors.grey, font = fonts.FONTIN},
		text_textbox_placeholder = {color = colors.grey, font = fonts.FONTIN},
		text_textbox_selection = {color = colors.black, font = fonts.FONTIN},
		search_text_highlight_overlay = colors.yellow_overlay,
		selection_text_highlight_background = colors.light_grey,
		-- list background
		list_background = poe2trade_colors.row_background,
		list_background_selected = poe2trade_colors.row_background,
		list_background_drag_targeted = colors.green_black,
		-- list border
		list_border = poe2trade_colors.clickable_background_hover,
		list_border_selected = poe2trade_colors.clickable_active,
		list_border_drag_targeted = colors.dark_green,
		-- list dragindex
		list_dragindex = colors.light,
		list_dragindex_center = poe2trade_colors.white_warm,
		-- list entry background
		list_entry_background = poe2trade_colors.row_background,
		list_entry_background_even = colors.light_black,
		list_entry_background_selected = colors.dark,
		list_entry_background_focused = colors.darker_grey,
		list_entry_background_hover = colors.darkest_grey,
		-- list entry border
		list_entry_border = colors.white, -- not used yet
		list_entry_border_selected = poe2trade_colors.clickable_background_hover,
		list_entry_border_focused = colors.grey,
		list_entry_border_hover = poe2trade_colors.clickable_active,
		-- list column label background
		list_column_label_background = poe2trade_colors.clickable_enabled,
		list_column_label_background_hover = poe2trade_colors.clickable_background_hover,
		-- list column label border
		list_column_label_border = poe2trade_colors.clickable_background_hover,
		list_column_label_border_hover = poe2trade_colors.clickable_active,
		-- textlist background
		textlist_background = poe2trade_colors.row_background,
		-- textlist border
		textlist_border = poe2trade_colors.clickable_background_hover,
		-- textbox background
		textbox_background = colors.dark,
		textbox_background_disabled = poe2trade_colors.clickable_enabled,
		textbox_background_selected = colors.dark,
		textbox_background_hover = colors.dark,
		-- textbox border
		textbox_border = poe2trade_colors.clickable_background_hover,
		textbox_border_disabled = colors.transparent,
		textbox_border_selected = poe2trade_colors.clickable_active,
		textbox_border_hover = poe2trade_colors.clickable_background_hover,
		textbox_border_highlight = colors.blue_highlight,
		textbox_border_highlight_negative = colors.red_highlight,
		-- dropdown background
		dropdown_background = poe2trade_colors.clickable_enabled,
		dropdown_background_disabled = poe2trade_colors.clickable_background_disabled,
		dropdown_background_toggled = poe2trade_colors.clickable_active,
		dropdown_background_clicked = poe2trade_colors.clickable_active,
		dropdown_background_hover = poe2trade_colors.clickable_background_hover,
		-- dropdown border
		dropdown_border = poe2trade_colors.clickable_background_hover,
		dropdown_border_disabled = colors.transparent,
		dropdown_border_toggled = poe2trade_colors.clickable_active,
		dropdown_border_clicked = poe2trade_colors.clickable_active,
		dropdown_border_hover = poe2trade_colors.clickable_background_hover,
		dropdown_border_highlight = colors.blue_highlight,
		dropdown_border_highlight_negative = colors.red_highlight,
		-- dropdown arrow
		dropdown_arrow = colors.light_grey,
		dropdown_arrow_disabled = colors.dark_grey,
		dropdown_arrow_hover = colors.white,
		-- checkbox background
		checkbox_background = poe2trade_colors.clickable_enabled,
		checkbox_background_disabled = poe2trade_colors.clickable_background_disabled,
		checkbox_background_toggled = poe2trade_colors.clickable_active,
		checkbox_background_clicked = poe2trade_colors.clickable_active,
		checkbox_background_hover = poe2trade_colors.clickable_background_hover,
		-- checkbox border
		checkbox_border = poe2trade_colors.clickable_background_hover,
		checkbox_border_disabled = colors.transparent,
		checkbox_border_toggled = poe2trade_colors.clickable_active,
		checkbox_border_clicked = poe2trade_colors.clickable_active,
		checkbox_border_hover = poe2trade_colors.clickable_background_hover,
		-- checkbox checkmark
		checkbox_checkmark = colors.light_grey,
		checkbox_checkmark_disabled = colors.dark_grey,
		checkbox_checkmark_hover = colors.white,
		-- checkbox checkimage
		checkbox_checkimage = colors.grey,
		checkbox_checkimage_disabled = colors.dark_grey,
		checkbox_checkimage_toggled = colors.white,
		checkbox_checkimage_hover = colors.white,
		checkbox_border_highlight = colors.blue_highlight,
		checkbox_border_highlight_negative = colors.red_highlight,
		-- slider background
		slider_background = colors.dark,
		slider_background_disabled = poe2trade_colors.clickable_enabled,
		slider_background_selected = colors.dark,
		slider_background_hover = colors.dark,
		-- slider border
		slider_border = poe2trade_colors.clickable_background_hover,
		slider_border_disabled = poe2trade_colors.clickable_enabled,
		slider_border_selected = colors.grey,
		slider_border_hover = poe2trade_colors.clickable_active,
		-- slider knob
		slider_knob = poe2trade_colors.clickable_active,
		slider_knob_disabled = poe2trade_colors.clickable_background_hover,
		slider_knob_selected = colors.light,
		slider_knob_hover = colors.light_grey,
		slider_section_separator = poe2trade_colors.clickable_background_hover,
		-- scrollbar background
		scrollbar_background = colors.dark,
		scrollbar_background_disabled = colors.dark,
		scrollbar_background_selected = colors.dark,
		scrollbar_background_hover = colors.dark,
		-- scrollbar border
		scrollbar_border = poe2trade_colors.clickable_background_hover,
		scrollbar_border_disabled = poe2trade_colors.clickable_enabled,
		scrollbar_border_selected = colors.grey,
		scrollbar_border_hover = poe2trade_colors.clickable_active,
		-- scrollbar knob
		scrollbar_knob = poe2trade_colors.clickable_active,
		scrollbar_knob_disabled = poe2trade_colors.clickable_background_hover,
		scrollbar_knob_selected = colors.light,
		scrollbar_knob_hover = colors.light_grey,
		-- scrollbar arrow
		scrollbar_arrow = poe2trade_colors.clickable_active,
		scrollbar_arrow_disabled = poe2trade_colors.clickable_background_hover,
		scrollbar_arrow_selected = colors.light,
		scrollbar_arrow_hover = colors.light_grey,
		-- scrollbar arrow background
		scrollbar_arrow_background = colors.dark,
		scrollbar_arrow_background_disabled = colors.dark,
		scrollbar_arrow_background_selected = colors.dark,
		scrollbar_arrow_background_hover = poe2trade_colors.clickable_background_hover,
		-- scrollbar arrow border
		scrollbar_arrow_border = poe2trade_colors.clickable_background_hover,
		scrollbar_arrow_border_disabled = poe2trade_colors.clickable_enabled,
		scrollbar_arrow_border_selected = colors.grey,
		scrollbar_arrow_border_hover = poe2trade_colors.clickable_active,
		-- button background
		button_background = poe2trade_colors.clickable_enabled,
		button_background_disabled = poe2trade_colors.clickable_background_disabled,
		button_background_toggled = poe2trade_colors.clickable_active,
		button_background_clicked = poe2trade_colors.clickable_active,
		button_background_hover = poe2trade_colors.clickable_background_hover,
		-- button border
		button_border = poe2trade_colors.clickable_background_hover,
		button_border_disabled = colors.transparent,
		button_border_toggled = poe2trade_colors.clickable_active,
		button_border_clicked = poe2trade_colors.clickable_active,
		button_border_hover = poe2trade_colors.clickable_background_hover,
		-- button raised background
		button_raised = poe2trade_colors.button_raised_enabled,
		button_raised_disabled = poe2trade_colors.button_raised_disabled,
		button_raised_toggled = poe2trade_colors.button_raised_active,
		button_raised_clicked = poe2trade_colors.button_raised_active,
		button_raised_hover = poe2trade_colors.button_raised_hover,
		-- button raised border
		button_raised_border = poe2trade_colors.button_raised_hover,
		button_raised_border_disabled = colors.transparent,
		button_raised_border_toggled = poe2trade_colors.button_raised_active,
		button_raised_border_clicked = poe2trade_colors.button_raised_active,
		button_raised_border_hover = poe2trade_colors.button_raised_hover,
		-- button image
		button_image = colors.white,
		button_image_disabled = colors.dark_grey,
		button_image_overlay_clicked = colors.white_50,
		-- dragger background
		dragger_background = colors.dark,
		dragger_background_disabled = poe2trade_colors.clickable_enabled,
		dragger_background_dragged = colors.dark,
		dragger_background_hover = colors.dark,
		-- dragger border
		dragger_border = poe2trade_colors.clickable_background_hover,
		dragger_border_disabled = colors.transparent,
		dragger_border_dragged = colors.grey,
		dragger_border_hover = poe2trade_colors.clickable_active,
		-- dragger knob
		dragger_knob = poe2trade_colors.clickable_active,
		dragger_knob_disabled = poe2trade_colors.clickable_background_hover,
		dragger_knob_dragged = colors.light,
		dragger_knob_hover = colors.light_grey,
		-- dragger knobimage
		dragger_knobimage = colors.white,
		dragger_knobimage_disabled = colors.dark_grey,
		dragger_knobimage_overlay_dragged = colors.white_50,
		-- rectangle outline
		rectangle_outline_border = poe2trade_colors.brown_transparancy,
		-- popup background
		popup_background = poe2trade_colors.row_background,
		popup_background_title = colors.black,
		-- popup border
		popup_border = poe2trade_colors.brown,
		popup_border_title = poe2trade_colors.brown,
		-- section background
		section_background = poe2trade_colors.row_background,
		section_background_title = colors.black,
		-- section border
		-- section_border = poe2trade_colors.brown,
		section_border = poe2trade_colors.brown_transparancy,
		section_border_title = poe2trade_colors.brown,
		-- tooltip
		tooltip_background = colors.black_85,
		tooltip_border = poe2trade_colors.tooltip_border,
		-- toast (popups in the bottom left corner)
		toast_background = colors.dark,
		toast_border = poe2trade_colors.brown,
		-- main control (bottom left corner)
		main_control_background = colors.dark,
		main_control_border = poe2trade_colors.brown,
		-- top bar
		-- top_bar_background = colors.darker_grey,
		top_bar_background = colors.dark,
		top_bar_border = poe2trade_colors.brown,
		-- side bar
		-- side_bar_background = colors.dark,
		side_bar_background = poe2trade_colors.row_background,
		side_bar_border = poe2trade_colors.brown,
		-- bottom bar
		bottom_bar_background = poe2trade_colors.row_background,
		bottom_bar_border = poe2trade_colors.brown,
		-- current build (box behind build name)
		current_build_box_background = poe2trade_colors.row_background,
		current_build_box_border = poe2trade_colors.clickable_background_hover,
		-- points (box behind skill points at the top)
		points_box_background = poe2trade_colors.row_background,
		points_box_border = poe2trade_colors.clickable_background_hover,
	}
}


local activeTheme = "classic"
function SetActiveTheme(name)
	activeTheme = name
end

local function isHex(s)
	return string.sub(s, 1, 1) == "#" or string.sub(s, 1, 2):lower() == "0x" or string.sub(s, 1, 2):lower() == "^x"
end

local function colorNameToHex(colorName)
	if isHex(colorName) then
		return colorName
	end
	return colorNameToHex(colors[colorName])
end

-- extends hexToRGB() from Data/Global.lua to also allow for opacity
local function hexaToRGBA(hex)
	if isHex(hex) == false then
		ConPrintf('Error: Trying to convert non-hex number to RGBA: '..hex)
	end
	hex = hex:gsub("0x", "") -- Remove "0x" prefix
	hex = hex:gsub("%^x", "") -- Remove "^x" prefix
	hex = hex:gsub("#", "") -- Remove '#' if present
	if #hex ~= 8 and #hex ~= 6 then
		ConPrintf('Error: Trying to convert non-hex number to RGBA: '..hex)
		return nil
	end
	local r = (tonumber(hex:sub(1, 2), 16)) / 255
	local g = (tonumber(hex:sub(3, 4), 16)) / 255
	local b = (tonumber(hex:sub(5, 6), 16)) / 255
	local a = 1
	if #hex == 8 then
		a = (tonumber(hex:sub(7, 8), 16)) / 255
	end
	return r, g, b, a
end

--- Gets the style structure for the given styleName
---@param styleName Style The name of the style to use. Always use values from Style alias, e.g. `'text_button'`
local function getStyleFromTheme(styleName)
	if styleName == nil then
		ConPrintf('Error: Trying to access style with empty name.')
	end
	local style = themes[activeTheme][styleName]
	if style == nil then
		ConPrintf('Error: No style found for "'..styleName..'" with theme "'..activeTheme..'". Falling back to classic theme...')
		style = themes.classic[styleName]
	end
	return style
end

--- Gets the color code (e.g. ^xFFFFFF) for the given style
---@param styleName Style The name of the style to use. Always use values from Style alias, e.g. `'text_button'`
function GetStyleColor(styleName)
	local colorName = getStyleFromTheme(styleName)
	if type(colorName) == "table" then
		colorName = colorName.color
	end
	local hex = colorNameToHex(colorName)
	hex = hex:gsub("0x", "^x") -- turn "0x" prefix into "^x" prefix
	hex = hex:gsub("#", "^x") -- turn "#" prefix into "^x" prefix
	return hex
end

--- Sets the draw color to a color defined by a style.
--- Meant to replace SetDrawColor() when drawing UI.
--- This internally calls SetDrawColor()
---@param colorStyle Style The name of the style to use. Always use values from Style alias, e.g. `'text_button'`
function SetDrawStyle(colorStyle)
	local hex = GetStyleColor(colorStyle)
	local r, g, b, a =  hexaToRGBA(hex)
	SetDrawColor(r, g, b, a)
end

--- Gets the font name (e.g. VAR) for the given style. Note: not all styles have a font! Only those starting with text_
---@param fontStyle Style The name of the style to use. Always use values from Style alias, e.g. `'text_button'`
function GetStyleFont(fontStyle)
	return getStyleFromTheme(fontStyle).font
end

--- Wrapper for DrawString(left, top, align, height, font, text) to use a Style definition instead of a static font 
---@param fontStyle Style The name of the style to use. Always use values from Style alias, e.g. `'text_button'`
function StyledDrawString(left, top, align, height, fontStyle, text)
	local font = GetStyleFont(fontStyle)
	DrawString(left, top, align, height, font, text)
end

--- Wrapper for DrawStringWidth(height, font, text) to use a Style definition instead of a static font 
---@param fontStyle Style The name of the style to use. Always use values from Style alias, e.g. `'text_button'`
function StyledDrawStringWidth(height, fontStyle, text)
	local font = GetStyleFont(fontStyle)
	return DrawStringWidth(height, font, text)
end

--- Wrapper for DrawStringCursorIndex(height, font, text, cursorX, cursorY) to use a Style definition instead of a static font 
---@param fontStyle Style The name of the style to use. Always use values from Style alias, e.g. `'text_button'`
function StyledDrawStringCursorIndex(height, fontStyle, text, cursorX, cursorY)
	local font = GetStyleFont(fontStyle)
	return DrawStringCursorIndex(height, font, text, cursorX, cursorY)
end