local reportPath = "coverage/sonar-generic-coverage.xml"
local sourceSuffix = "MapAchiever/MapAchiever.lua"
local report = assert(io.open(reportPath, "r"))
local contents = report:read("*a")
report:close()

local sourceCount = 0
local sourceCoverage
for path, body in contents:gmatch('<file path="([^"]+)">(.-)</file>') do
	if path:gsub("\\", "/"):sub(-#sourceSuffix) == sourceSuffix then
		sourceCount = sourceCount + 1
		sourceCoverage = body
	end
end

if sourceCount ~= 1 then
	error(string.format("Expected one coverage entry for %s; found %d", sourceSuffix, sourceCount), 0)
end

local lineCount = 0
local missedLines = {}
for lineNumber, covered in sourceCoverage:gmatch('<lineToCover lineNumber="(%d+)" covered="([^"]+)"') do
	lineCount = lineCount + 1
	if covered ~= "true" then
		missedLines[#missedLines + 1] = lineNumber
	end
end

if lineCount == 0 then
	error("No executable lines reported for " .. sourceSuffix, 0)
end

if #missedLines > 0 then
	error("Uncovered executable lines in " .. sourceSuffix .. ": " .. table.concat(missedLines, ", "), 0)
end

print(string.format("100%% line coverage: %d executable lines in %s", lineCount, sourceSuffix))
