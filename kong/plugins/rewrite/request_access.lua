local cjson = require "cjson.safe"
local helpers = require "kong.plugins.rewrite.helpers"

local mapTo = helpers.mapTo
local isempty = helpers.isempty
local log = helpers.log

local req_set_uri = ngx.req.set_uri
local req_set_uri_args = ngx.req.set_uri_args
local req_set_header = ngx.req.set_header
local req_read_body = ngx.req.read_body
local req_set_body_data = ngx.req.set_body_data
local req_clear_header = ngx.req.clear_header
local req_set_method = ngx.req.set_method
local encode_args = ngx.encode_args
local string_find = string.find

local _M = {}

local function req_set_headers(oldHeaders, newHeaders)
  if not isempty(oldHeaders) then
    for name, value in pairs(oldHeaders) do
      log.info('Clearing old header '..name)
      req_clear_header(name)
    end
  end
  if not isempty(newHeaders) then
    for name, value in pairs(newHeaders) do
      log.info('Setting new header '..name, value)
      req_set_header(name, value)
    end
  end
end

local function transform_querystrings(conf, scope)
  if isempty(conf.request.querystring) then
    return
  end
  req_set_uri_args(mapTo(scope, conf.request.querystring))
end

local function transform_headers(conf, scope)
  if isempty(conf.request.headers) then
    return
  end
  req_set_headers(scope.req.headers, mapTo(scope, conf.request.headers))
end

local function transform_body_text(conf, scope)
  if isempty(conf.request.text) then
    return
  end

  local body = mapTo(scope, conf.request.json)
  req_set_body_data(body)
  req_set_header('content-type', 'plain/text')
  req_set_header('content-length', #body)
end

local function transform_body_json(conf, scope)
  if isempty(conf.request.json) then
    return
  end

  local json = mapTo(scope, conf.request.json)
  local body = cjson.encode(json)
  req_set_body_data(body)
  req_set_header('content-type', 'application/json')
  req_set_header('content-length', #body)
end

local function transform_method(conf, scope)
  if isempty(conf.request.method) then
    return
  end
  local newMethod = (mapTo(scope, conf.request.method) or scope.req.method):upper()
  req_set_method(ngx["HTTP_"..newMethod])
  if newMethod == "GET" or newMethod == "HEAD" or newMethod == "TRACE" then
    if type(scope.req.payload) == 'table' then
      local parameters = scope.req.payload
      local querystring = scope.req.query
      for name, value in pairs(parameters) do
        querystring[name] = value
      end
      req_set_uri_args(querystring)
    end
  end
end

local function transform_path(conf, scope)
  if isempty(conf.request.path) then
    return
  end
  local uri = mapTo(scope, conf.request.path)
  if uri then
    -- if kong development kit exists use it to set the path
    if kong then
      kong.service.request.set_path(uri)
    else
      req_set_uri(uri)
    end
  end
end

function _M.access(conf, scope)
  transform_method(conf, scope)
  transform_path(conf, scope)
  transform_body_text(conf, scope)
  transform_body_json(conf, scope)
  transform_headers(conf, scope)
  transform_querystrings(conf, scope)
end

return _M
