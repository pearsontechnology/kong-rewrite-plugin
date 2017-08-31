local cjson = require "cjson"
local url = require "socket.url"

local string_find = string.find

function table.clone (t) -- deep-copy a table
  if type(t) ~= "table" then
    return t
  end
  local meta = getmetatable(t)
  local target = {}
  for k, v in pairs(t) do
    target[k] = type(v) == "table" and table.clone(v) or v
  end
  setmetatable(target, meta)
  return target
end

function table.extend (src, ext) -- deep-copy a table
  local h = table.clone(src)
  for k, v in pairs(ext) do
    h[k]=v
  end
  return h
end

function table.filter (t, iter)
  local out = {}
  local nk=1

  for k, v in pairs(t) do
    if iter(v, k, t) then
      out[nk] = v
      nk = nk + 1
    end
  end

  return out
end

function table.map (t, iter)
  local out = {}

  for k, v in pairs(t) do
    out[k] = iter(v, k, t)
  end

  return out
end

--[[
ngx.STDERR
ngx.EMERG
ngx.ALERT
ngx.CRIT
ngx.ERR
ngx.WARN
ngx.NOTICE
ngx.INFO
ngx.DEBUG
]]

local function log_write(level, ...)
end

local function log_error(...)
  ngx.log(ngx.ERR, ...)
end

local function log_warn(...)
  ngx.log(ngx.WARN, ...)
end

local function log_info(...)
  ngx.log(ngx.INFO, ...)
end

local function log_debug(...)
  ngx.log(ngx.DEBUG, ...)
end

local log = {
  write = log_write,
  error = log_error,
  warn  = log_warn,
  info  = log_info,
  debug = log_debug,
}

local function dump(t, indent)
  if indent == nil then
    indent = ''
  end
  if type(t)=="table" then
    local s = '{\n'
    for k, v in pairs(t) do
      s = s..indent..'  '..k..": "..dump(v, indent.."  "):gsub("^%s*(.-)%s*$", "%1").."\n"
    end
    return s..indent..'}\n'
  end
  return indent..tostring(t)
end

local function decode_args(body)
  if body then
    return ngx_decode_args(body)
  end
  return {}
end

local function get_content_type(content_type)
  if content_type == nil then
    return
  end
  local contentType = content_type:lower()
  if string_find(contentType, "text/html", nil, true) then
    return 'html'
  end
  if string_find(contentType, "text/plain", nil, true) then
    return 'text'
  end
  if string_find(contentType, "application/json", nil, true) then
    return 'json'
  end
  if string_find(contentType, "multipart/form-data", nil, true) then
    return 'multi-part'
  end
  if string_find(contentType, "application/x-www-form-urlencoded", nil, true) then
    return 'form-encoded'
  end
  return 'unknown'
end

local function parse_json(body)
  if body then
    local status, res = pcall(cjson.decode, body)
    if status then
      return res
    end
  end
end

local function parse_token(str)
  local isToken = str:match("^{[^}]*}$")
  if not isToken then
    return
  end
  local token = str:sub(2, #str-1)
  local multi = token:sub(#token)=="*"
  local name = multi and token:sub(1, #token-1) or token
  return {
    token = token,
    name = name,
    multi = multi
  }
end

local function parse_path(path, sep)
  local sep = sep or "/"
  local parts = {}
  local fields = {}
  local token
  local pattern = string.format("([^%s]+)", sep)
  path:gsub(pattern, function(c) parts[#parts+1] = c end)
  for i, v in pairs(parts) do
    token = parse_token(v)
    fields[#fields+1] = token and token or {symbol = v}
  end
  return fields
end

local function parse_url(host_url)
  local parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == "http" then
      parsed_url.port = 80
     elseif parsed_url.scheme == HTTPS then
      parsed_url.port = 443
     end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end
  parsed_url.path_parts = parse_path(parsed_url.path)
  return parsed_url
end

local function mapTo(scope, map)
  local mtype = type(map)
  if mtype == "table" then
    local res = {}
    for k, v in pairs(map) do
      res[k] = mapTo(scope, v)
    end
    return res
  end
  if mtype == "function" then
    return map(src)
  end
  if mtype == "string" then
    local f, m = (string.find(map, 'return ') ~= nil) and loadstring("return function(src)\n  "..map.."\nend") or loadstring("return function(src)\n  return "..map.."\nend")
    --local f, m = loadstring("return function(src)\n  "..map.."\nend")
    --log.info('mapTo::string ', f, m)
    if not f then
      log.error('ERROR in ', map, ' - ', f, m)
      return nil, m
    end
    local env = getfenv(2)
    env.log = log
    env.dump = dump
    for k, v in pairs(scope) do
      env[k] = v
    end
    setfenv(f, env)
    local ok, worker, err = pcall(f)
    if err then
      log_error('ERROR with map function ', err, ' in ', map)
      return err
    end
    return mapTo(src, worker)
  end
end

local function isempty(s)
  return s == nil or s == ''
end

local function keys(t)
  local keyset={}
  local n=0
  for k, v in pairs(t) do
    n=n+1
    keyset[n]=k
  end
  return keyset
end

local function create_routes_tree_array(routes)
  local tree = {}
  local parts, root, symbol
  local params = {}
  local tail
  for k, v in pairs(routes) do
    if type(v) == 'table' then
      local routePath = v.route
      params = {}
      parts = parse_path(routePath)
      root = tree
      for p, info in pairs(parts) do
        if info.name then
          params[info.name] = table.extend(info, {index = p})
        end
        symbol = info.symbol and info.symbol or '{*}'
        if not root[symbol] then
          root[symbol] = {}
        end
        root = root[symbol]
        tail = info
      end
      if root['{e}'] then
        local errorMsg = "Route " .. routePath .. " already defined as " .. root['{e}'].path .. ""
        local err = {error = errorMsg, existing = root['{e}'], collision = {path = routePath, config = v}}
        return err, true
      end
      root['{e}'] = {path = routePath, config = v, params = params, info = tail}
    end
  end
  return tree, false
end

local function create_routes_tree_dict(routes)
  local tree = {}
  local parts, root, symbol
  local params = {}
  local tail
  for k, v in pairs(routes) do
    if type(v) == 'table' then
      params = {}
      parts = parse_path(k)
      root = tree
      for p, info in pairs(parts) do
        if info.name then
          params[info.name] = table.extend(info, {index = p})
        end
        symbol = info.symbol and info.symbol or '{*}'
        if not root[symbol] then
          root[symbol] = {}
        end
        root = root[symbol]
        tail = info
      end
      if root['{e}'] then
        local errorMsg = "Route " .. k .. " already defined as " .. root['{e}'].path .. ""
        local err = {error = errorMsg, existing = root['{e}'], collision = {path = k, config = v}}
        return err, true
      end
      root['{e}'] = {path = k, config = v, params = params, info = tail}
    end
  end
  return tree, false
end

local function find_routes_tree_entity(route, tree)
  local segments = parse_path(route)
  local segmentValues = {}
  local leaf = tree
  local tail = false
  local segment
  for k, v in pairs(segments) do
    segmentValues[#segmentValues+1] = v.symbol
  end
  for i, v in pairs(segments) do
    segment = v.symbol
    leaf = leaf[segment] or leaf['{*}']
    if not leaf then
      return tail and table.extend(tail['{e}'], {segments = segmentValues})
    end
    if leaf['{e}'] and leaf['{e}'].info.multi then
      tail = leaf
    end
  end
  if leaf['{e}'] then
    return table.extend(leaf['{e}'], {segments = segmentValues})
  end
  return tail and table.extend(tail, {segments = segmentValues}) or false
end

local function subrange(t, first, last)
  local sub = {}
  local last = last and last or #t
  for i=first,last do
    sub[#sub + 1] = t[i]
  end
  return sub
end

return {
  mapTo = mapTo,
  parse_json = parse_json,
  parse_path = parse_path,
  parse_url = parse_url,
  get_content_type = get_content_type,
  isempty = isempty,
  log = log,
  dump = dump,
  keys = keys,
  create_routes_tree = create_routes_tree_array,
  find_routes_tree_entity = find_routes_tree_entity,
  subrange = subrange,
}
