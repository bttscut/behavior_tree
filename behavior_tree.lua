require('LuaXml')

function split(str, pat)
    local t = {}  -- NOTE: use {n = 0} in Lua-5.0
    local fpat = '(.-)' .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= '' then
            table.insert(t, cap)
        end
        last_end = e + 1
        s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end
    return t
end

function parse_child_nodes(node)
    local funcs = {}
    for i, child in ipairs(node[1]) do
        funcs[i] = parse_node(child)
    end
    return funcs
end

function make_selector(node)
    local funcs = parse_child_nodes(node)
    function selector(robot)
        for func in funcs do
            result = func(robot)
            if result then
                return true
            end
        end
        return false
    end
    return selector
end

function make_sequence(node)
    local funcs = parse_child_nodes(node)
    function sequence(robot)
        for func in funcs do
            result = func(robot)
            if not result then
                return false
            end
        end
        return true
    end
    return sequence
end

function make_parallel(node)
    local funcs = parse_child_nodes(node)
    local function parallel(robot)
        local results = {}
        for i, func in ipairs(funcs) do
            results[i] = func(robot)
        end
        for i, result in ipairs(results) do
            if not result then
                return false
            end
            return true
        end
    end
    return parallel
end

function make_alternate(node)
    local funcs = parse_child_nodes(node)
    local function alternate(robot)
        robot._alternate_i = robot._alternate_i or 1
        local i = robot._alternate_i
        local func = funcs[i]
        i = i + 1
        if i > #funcs then
            i = 1
        end
        robot._alternate_i = i
        return func(robot)
    end
    return alternate
end

function parse_composites(node, name)
    if name == 'Selector' then
        return make_selector(node)
    elseif name == 'Sequence' then
        return make_sequence(node)
    elseif name == 'Parallel' then
        return make_parallel(node)
    elseif name == 'Alternate' then
        return make_alternate(node)
    end
    error('Unknown Composite Node' .. name)
end

function make_loop(node)
    local child = node[1][1]
    local func = parse_node(child)
    local count = tonumber(node.Count)
    local function loop(robot)
        for i=1,count do
            if not func(rebot) then
                return false
            end
        end
        return true
    end
    return loop
end

function parse_decorators(node, name)
    if name == 'Loop' then
        return make_loop(node)
    end
    error('Unknown Decorator Node' .. name)
end

function extract_keywords(node)
    local keywords = {}
    return keywords
end

function make_condition(node, name)
    local keywords = extract_keywords(node)
    local function condition(robot)
        local method = robot[name]
        return method(keywords)
    end
    return condition
end

function make_action(node, name)
    local keywords = extract_keywords(node)
    local function action(robot)
        local method = getattr(robot, name)
        local result = pcall(method, keywords)
        if result[1] then
            return true
        else
            io.stderr:write(result[2])
            return false
        end
    end
    return action
end

function parse_node(node)
    print(node.Class)
    local _, node_type, node_name = unpack(split(node.Class, '%.'))
    if node_type == 'Composites' then
        return parse_composites(node, node_name)
    elseif node_type == 'Decorators' then
        return parse_decorators(node, node_name)
    elseif node_type == 'Conditions' then
        return make_condition(node, node_name)
    elseif node_type == 'Actions' then
        return make_action(node, node_name)
    end
    error('Unknown Type Node' .. node_type)
end

local function main()
    local root = xml.load("test.xml")
    local node = root[1][1][1]
    parse_node(node)
end

main()


