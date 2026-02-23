-- Reads luacov.stats.out and writes a simple CSV that stats_to_sonar.py can parse reliably.
-- Format:
--   FILE:<path>
--   <linenum>,<hits>
--   ...
--   END
--
-- Usage: lua tests/dump_stats.lua luacov.stats.out

local stats_path = arg and arg[1] or "luacov.stats.out"
local stats = dofile(stats_path)

for file_path, data in pairs(stats) do
    io.write("FILE:" .. file_path .. "\n")
    for k, v in pairs(data) do
        if type(k) == "number" then
            io.write(k .. "," .. v .. "\n")
        end
    end
    io.write("END\n")
end
