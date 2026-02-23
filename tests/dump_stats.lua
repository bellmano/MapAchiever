-- Reads luacov.stats.out (plain text, NOT Lua source) and writes a simple CSV.
-- luacov plain-text format (one entry per file):
--   <filename>
--   <max_line_number>
--   <hit_count_line_1>
--   <hit_count_line_2>
--   ... (max_line_number values total)
--   <next_filename> ...
-- Some builds prepend a bare integer (file count) as a header line.
--
-- Usage: lua tests/dump_stats.lua luacov.stats.out

local stats_path = (arg and arg[1]) or "luacov.stats.out"
local fh = assert(io.open(stats_path, "r"), "Cannot open " .. stats_path)

local function readline()
    return fh:read("*l")
end

local function emit_file(filename, max_line)
    if not filename:match("\.lua$") then
        filename = filename .. ".lua"
    end
    io.write("FILE:" .. filename .. "\n")
    for i = 1, max_line do
        local hits = tonumber(readline()) or 0
        if hits > 0 then
            io.write(i .. "," .. hits .. "\n")
        end
    end
    io.write("END\n")
end

-- Handle optional integer header (file-count prefix used by some versions)
local first = readline()
if first and not first:match("^%d+$") then
    -- First line is already a filename; process it now
    local max_line = tonumber(readline())
    if max_line then emit_file(first, max_line) end
end
-- else: first line was a count – just skip it and continue with normal loop

while true do
    local filename = readline()
    if not filename then break end
    local max_line = tonumber(readline())
    if not max_line then break end
    emit_file(filename, max_line)
end

fh:close()
