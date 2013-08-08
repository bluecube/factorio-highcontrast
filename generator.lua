#!/usr/bin/lua

require("gd")
require("math")
require("io")

data_dir = arg[1]
unit_px = 32

building_bg_color = "5e5e62"
building_line_color = "000000"
light_on_color = "00ff00"
light_off_color = "3f523f"
icon_offset = 4
light_offset = 3
light_width = 8
light_height = 5

function load_data()
    local old_package_path = package.path
    package.path = data_dir .. "/core/lualib/?.lua;" .. package.path
    package.path = data_dir .. "/base/?.lua;" .. package.path
    require("dataloader")
    dofile(data_dir .. "/base/data.lua")
    package.path = old_package_path
end

function replace_path(path)
    return path:gsub("__base__", data_dir .. "/base/")
end

function color(image, hex)
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)

    return image:colorResolve(r, g, b)
end

function make_image_base(width, height, icon_path)
    local image = gd.createTrueColor(width, height)

    image:filledRectangle(0, 0, width, height, color(image, building_bg_color))
    image:rectangle(0, 0, width - 1, height - 1, color(image, building_line_color))

    local icon = gd.createFromPng(icon_path)
    local icon_width, icon_height = icon:sizeXY()

    local icon_allowed_width = width - 2 - 2 * icon_offset
    local icon_allowed_height = height - 2 - 2 * icon_offset
    icon_scale = math.max(icon_width / icon_allowed_width,
                          icon_height / icon_allowed_height,
                          1)

    icon_resized_width = math.floor(icon_width / icon_scale)
    icon_resized_height = math.floor(icon_height / icon_scale)

    image:copyResized(icon,
                      width - icon_resized_width - icon_offset - 1, icon_offset + 1,
                      0, 0,
                      icon_resized_width, icon_resized_height,
                      icon_width, icon_height)

    return image
end

function add_light(image, light_color)
    local x = light_offset
    local y = image:sizeY() - 1 - light_offset - light_height
    image:filledRectangle(x, y, x + light_width, y + light_height, color(image, light_color))
    image:rectangle(x, y, x + light_width, y + light_height, color(image, building_line_color))
end

function building_image(entity_data, light)
    local width = entity_data.selection_box[2][1] - entity_data.selection_box[1][1]
    local height = entity_data.selection_box[2][2] - entity_data.selection_box[1][2]

    width = math.floor(width * unit_px)
    height = math.floor(height * unit_px)

    local base = make_image_base(width, height, replace_path(entity_data.icon))

    local image
    if light then
        image = gd.createTrueColor(2 * width, height);

        add_light(base, light_off_color)
        image:copy(base, 0, 0, 0, 0, width, height)

        add_light(base, light_on_color)
        image:copy(base, width, 0, 0, 0, width, height)
    else
        image = base
    end

    local filename = "/generated/" .. entity_data.name .. ".png"

    image:png(script_dir .. filename)
    return filename, width, height
end

function process_all_of_type(entity_type, light, handler)
    for k, v in pairs(data.raw[entity_type]) do
        print("Generating graphics overrides for " .. k .. " (" .. entity_type .. ")")
        local filename, width, height = building_image(v, light)
        local id = "data.raw['" .. entity_type .. "']['" .. k .. "']"

        handler(id, filename, width, height, f)
    end
end

script_dir = arg[0]:match("(.*/)")
load_data()
f = assert(io.open(script_dir .. "/generated/data.lua", "w"))

process_all_of_type("furnace", true, function(id, image_filename, image_width, image_height, file)
    file:write(id .. [[.on_animation = {
        filename = "__highcontrast__]] .. image_filename .. [[",
        priority = "extra-high",
        frame_width = ]] .. image_width .. [[,
        frame_height = ]] .. image_height .. [[,
        frame_count = 2,
        shift = {0, 0}
        }]])
    file:write("\n")
    file:write(id .. [[.off_animation = {
        filename = "__highcontrast__]] .. image_filename .. [[",
        priority = "extra-high",
        frame_width = ]] .. image_width .. [[,
        frame_height = ]] .. image_height .. [[,
        frame_count = 1,
        shift = {0, 0}
        }]])
    file:write("\n")
    file:write(id .. [[.fire_animation = {
        filename = "__highcontrast__/empty.png",
        priority = "extra-high",
        frame_width = 1,
        frame_height = 1,
        frame_count = 1,
        shift = {0, 0}
        }]])
    file:write("\n")
end)

process_all_of_type("container", false, function(id, image_filename, image_width, image_height, file)
    file:write(id .. [[.picture = {
        filename = "__highcontrast__]] .. image_filename .. [[",
        priority = "extra-high",
        width = ]] .. image_width .. [[,
        height = ]] .. image_height .. [[,
        shift = {0, 0}
        }]])
    file:write("\n")
end)

-- this causes factorio to crash; to be investigated :-)
--[=[process_all_of_type("assembling-machine", true, function(id, image_filename, image_width, image_height, file)
    file:write(id .. [[.animation = {
        filename = "__highcontrast__]] .. image_filename .. [[",
        priority = "medium",
        frame_width = ]] .. image_width .. [[,
        frame_height = ]] .. image_height .. [[,
        frame_count = 1,
        line_length = 2,
        shift = {0, 0}
        }]])
    file:write("\n")
end)]=]
