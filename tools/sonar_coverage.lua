local reporter = require("luacov.reporter")
local ReporterBase = reporter.ReporterBase

local SonarReporter = setmetatable({}, ReporterBase)
SonarReporter.__index = SonarReporter

local function escapeXml(value)
	return value:gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function normalizedPath(path)
	return (path:gsub("\\", "/"):gsub("^%./", ""))
end

function SonarReporter:on_start()
	self._out = assert(io.open(self:config().reportfile, "w"))
	self:write('<?xml version="1.0" encoding="UTF-8"?>\n<coverage version="1">\n')
end

function SonarReporter:on_new_file(filename)
	self:write('  <file path="', escapeXml(normalizedPath(filename)), '">\n')
end

function SonarReporter:on_hit_line(_, lineNumber)
	self:write('    <lineToCover lineNumber="', lineNumber, '" covered="true"/>\n')
end

function SonarReporter:on_mis_line(_, lineNumber)
	self:write('    <lineToCover lineNumber="', lineNumber, '" covered="false"/>\n')
end

function SonarReporter:on_file_error(filename, errorType, message)
	error(string.format("Could not %s %s: %s", errorType, filename, message), 0)
end

function SonarReporter:on_end_file()
	self:write("  </file>\n")
end

function SonarReporter:on_end()
	self:write("</coverage>\n")
end

reporter.report(SonarReporter)
