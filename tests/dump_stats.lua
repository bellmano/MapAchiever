-- Reads luacov.stats.out and writes a simple CSV that stats_to_sonar.py reads.
-- Actual luacov.stats.out format (two lines per file):
--   <max_line_count>:<filepath>
--   <hit1> <hit2> ... <hitN>   (N = max_line_count, space-separated on one line)
--
-- Output CSV (FILE / linenum,hits / END blocks).
-- Usage: lua tests/dump_stats.lua luacov.stats.out

local stats_path = (arg and arg[1]) or "luacov.stats.out"
local fh = assert(io.open(stats_path, "r"), "Cannot open " .. stats_path)

local function readline()
    return fh:read("*l")
end

local function emit_file(filename, hits_line)
    if not filename:match("%.lua$") then
        filename = filename .. ".lua"
    end
    io.write("FILE:" .. filename .. "\n")
    local i = 1
    for hits in hits_line:gmatch("%S+") do
        local n = tonumber(hits) or 0
        if n > 0 then
            io.write(i .. "," .. n .. "\n")
        end
        i = i + 1
    end
    io.write("END\n")
end

while true do
    local header = readline()
    if not header then break end
    -- format: "163:/path/to/file.lua"
    local count_str, filepath = header:match("^(%d+):(.+)$")
    if not count_str then break end
    local hits_line = readline()
    if not hits_line then break end
    emit_file(filepath, hits_line)
end

fh:close()
