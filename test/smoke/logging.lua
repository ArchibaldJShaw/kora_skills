-- Migrated diagnostics: a schema setup failure must reach Kora.logging, not print.
local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local resourceRoot = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path

local harness = require('harness')
local calls = {}
local function spy(level)
    return function(event, message, fields)
        calls[#calls + 1] = { level = level, event = event, message = message, fields = fields }
        return true
    end
end

_G.Kora = {
    logging = { error = spy('error'), warn = spy('warn'), info = spy('info'), debug = spy('debug') },
    sql = {
        ready = function() return true end,
        ensureTables = function() return nil, 'boom' end,
    },
}
_G.exports = setmetatable({}, { __call = function() end })
_G.GetCurrentResourceName = function() return 'kora_skills' end
_G.TriggerEvent = function() end
_G.CreateThread = function(fn) fn() end
local realPrint = print

dofile(resourceRoot .. 'config.lua')
dofile(resourceRoot .. 'shared/curve.lua')
dofile(resourceRoot .. 'server/schema.lua')

harness.test('a schema setup failure is logged as an error with the error in fields', function()
    _G.print = function() error('kora_skills must log through Kora.logging, not print') end
    dofile(resourceRoot .. 'server/database.lua')
    _G.print = realPrint
    local call = calls[1]
    harness.truthy(call ~= nil, 'a logger call was made')
    harness.equal(call.level, 'error', 'severity')
    harness.equal(call.event, 'schema.setup_failed', 'event name')
    harness.equal(call.fields.error, 'boom', 'error travels in fields')
end)

if harness.failures > 0 then os.exit(1) end
