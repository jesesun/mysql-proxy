---
-- a first implementation of the a script test-suite
--
-- it is inspired by all the different unit-testsuites our there and
-- provides 
-- * a set of assert functions
-- * a fake proxy implementation
--
-- @todo the local script scope isn't managed yet


-- the fake script scope
proxy = {
	global = {
		config = {}
	},
	queries = {
		append = function (id, query) 
			queries[#queries + 1] = { 
				id = id, 
				query = query
			}
		end
	},
	connection = {
		server = {
			thread_id = 1,
		},
		client = {
		}
	},
	PROXY_SEND_RESULT = 1,
	PROXY_SEND_QUERY = 2,

	COM_QUERY = 3
}

-- file under test
require("active-queries")
local tests = require("proxy.test")

---
-- overwrite the scripts dump_global_state
-- to get rid of the printout
--
function print_stats(stats)
end

TestScript = tests.BaseTest:new({ 
	active_qs = proxy.global.active_queries
})

function TestScript:setUp()
	-- reset the query queue
	queries = { }
	proxy.global.max_active_trx = 0
	proxy.global.active_queries = { }
end

function TestScript:testInit()
	assertEquals(type(self.active_qs), "table")
end

function TestScript:testCleanStats()
	local stats = collect_stats()

	assertEquals(stats.max_active_trx, 0)
	assertEquals(stats.num_conns, 0)
end

function TestScript:testQueryQueuing()
	-- send a query in
	assertNotEquals(read_query(string.char(proxy.COM_QUERY) .. "SELECT 1"), nil)
	
	local stats = collect_stats()
	assertEquals(stats.max_active_trx, 1)
	assertEquals(stats.num_conns, 1)
	assertEquals(stats.active_conns, 1)
	
	-- and here is the result
	assertEquals(#queries, 1)
end	

function TestScript:testQueryTracking()
	inj = { 
		id = 1, 
		query = string.char(proxy.COM_QUERY) .. "SELECT 1"
	}

	-- setup the query queue
	assertNotEquals(read_query(inj.query), nil)

	local stats = collect_stats()
	assertEquals(stats.num_conns, 1)
	assertEquals(stats.active_conns, 1)
	
	-- check if the stats are updated
	assertEquals(read_query_result(inj), nil)

	local stats = collect_stats()
	assertEquals(stats.num_conns, 1)
	assertEquals(stats.active_conns, 0)
	assertEquals(stats.max_active_trx, 1)
end
	
function TestScript:testDisconnect()
	inj = { 
		id = 1, 
		query = string.char(proxy.COM_QUERY) .. "SELECT 1"
	}

	-- exec some queries
	assertNotEquals(read_query(inj.query), nil)
	assertEquals(read_query_result(inj), nil)

	local stats = collect_stats()
	assertEquals(stats.num_conns, 1)

	-- the disconnect should set the num_conns to 0 again
	assertEquals(disconnect_client(), nil)
	
	local stats = collect_stats()
	assertEquals(stats.num_conns, 0)
	assertEquals(stats.active_conns, 0)
	assertEquals(stats.max_active_trx, 1)
end

---
-- the test suite runner

local suite = proxy.test.Suite:new({ result = proxy.test.Result:new()})

suite:run()
suite.result:print()
suite:exit()
