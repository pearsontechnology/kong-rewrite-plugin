local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson.safe"
local public_utils = require "kong.tools.public"
local request_access = require "kong.plugins.rewrite.request_access"
local response_access = require "kong.plugins.rewrite.response_access"
local helpers = require "kong.plugins.rewrite.helpers"
local multipart = require "multipart"

local isempty = helpers.isempty
local log = helpers.log
local dump = helpers.dump
local keys = helpers.keys
local parse_url = helpers.parse_url
local parse_path = helpers.parse_path
local create_routes_tree = helpers.create_routes_tree
local find_routes_tree_entity = helpers.find_routes_tree_entity
local get_content_type = helpers.get_content_type
local subrange = helpers.subrange

local ngx_decode_args = ngx.decode_args
local req_read_body = ngx.req.read_body
local req_get_method = ngx.req.get_method
local req_get_body_data = ngx.req.get_body_data
local req_get_headers = ngx.req.get_headers
local req_get_uri_args = ngx.req.get_uri_args

local RewriteHandler = BasePlugin:extend()

local routesCacheSource, routesCacheTree = {}

local function decode_args(body)
  if body then
    return ngx_decode_args(body)
  end
  return {}
end

RewriteHandler.PRIORITY = 800

local function findRouteEntity(conf, requestedRoute)
  local config = find_routes_tree_entity(requestedRoute, routesCacheTree)
  return config
end

local function findRouteConf(conf, requestedRoute)
  local config = find_routes_tree_entity(requestedRoute, routesCacheTree)
  return config and config.config or config
end

local function isRoute(conf, requestedRoute)
  local forRoute = conf.uri.route
  local method = conf.uri.method
  if not isempty(method) then
    local forMethod = method:upper()
    local requestedMethod = (req_get_method() or "GET"):upper()
    if forMethod ~= requestedMethod then
      return false
    end
  end
  if isempty(forRoute) then
    return true
  end
  if #requestedRoute < #forRoute then
    return false
  end
  if forRoute:lower() == string.sub(requestedRoute:lower(), 1, #forRoute) then
    return true
  end
  return false
end

function RewriteHandler:new()
  RewriteHandler.super.new(self, "rewrite")
end

function RewriteHandler:init_worker(conf)
  conf = conf and conf or {}
end

local function checkRefreshRoutesCache(conf)
  if routesCacheSource == conf.routes then
    return
  end
  routesCacheSource = conf.routes
  local tree, err = create_routes_tree(routesCacheSource)
  if not err then
    routesCacheTree = tree
  else
    log.error('checkRefreshRoutesCache (create_routes_tree): ', dump(err))
  end
end

local function decode_body(content_type, body, content_type_value)
  local is_body_transformed = false
  local content_length = (body and #body) or 0

  if not content_type then
    return ''
  elseif content_type == 'form-encoded' then
    return decode_args(body)
  elseif content_type == 'multi-part' then
    return multipart(body and body or "", content_type_value)
  elseif content_type == 'text' then
    return body
  elseif content_type == 'html' then
    return body
  elseif content_type == 'json' then
    local json, err = cjson.decode(body)
    if err then
      return body
    end
    return json
  end
  return body
end

local function get_req(get_body)
  if get_body then
    req_read_body()
  end
  local body = (get_body) and req_get_body_data() or ''
  local method = (req_get_method() or "GET"):upper()
  local headers = req_get_headers()
  local content_type_value = headers['content-type']
  local content_type = get_content_type(content_type_value)
  local query = req_get_uri_args()
  local payload = decode_body(content_type, body, content_type_value)
  local path = ngx.var.request_uri
  return {
    content_type_value = content_type_value,
    content_type = content_type,
    method = method,
    path = path,
    headers = headers,
    body = body,
    payload = payload,
    query = query,
  }
end

local function get_res(res, options)
  if options.header_filter then
    res.headers = ngx.header
    res.content_type_value = res.headers["content-type"]
    res.content_type = get_content_type(res.content_type_value)
    return res
  end
  if options.body_filter then
    local chunk, eof = ngx.arg[1], ngx.arg[2]
    res.body = (res.body or "")..chunk
    res.eof = eof
    if eof then
      local content_type = res.content_type
      local body = res.body
      if content_type == 'json' and not isempty(conf.response_json) then
        local json, err = cjson.decode(body)
        res.payload = err and body or json
      else
        res.payload = body
      end
      return res
    end
    ngx.arg[1] = nil
  end
  return res
end

local function get_scope(conf, options)
  local scope = ngx.ctx.scope or {}
  scope.req = scope.req or get_req(options.access)
  scope.res = get_res(scope.res or {}, options)
  return scope
end

function RewriteHandler:access(conf)
  RewriteHandler.super.access(self)
  checkRefreshRoutesCache(conf)
  local scope = get_scope(conf, {access = true})
  local requestedRoute = scope.req.path
  local routeEntity = findRouteEntity(conf, requestedRoute)
  if not routeEntity then
    return
  end
  scope.req.params = {}
  for k, i in pairs(routeEntity.params) do
    scope.req.params[k] = i.multi and subrange(routeEntity.segments, i.index) or routeEntity.segments[i.index]
  end
  request_access.access(routeEntity.config, scope)
end

function RewriteHandler:header_filter(conf)
  RewriteHandler.super.header_filter(self)
  local scope = get_scope(conf, {header_filter = true})
  local requestedRoute = scope.req.path
  local routeConf = findRouteConf(conf, requestedRoute)
  if not routeConf then
    return
  end
  response_access.header_filter(routeConf, scope)
end

function RewriteHandler:body_filter(conf)
  RewriteHandler.super.body_filter(self)
  local scope = get_scope(conf, {body_filter = true})
  local requestedRoute = scope.req.path
  local routeConf = findRouteConf(conf, requestedRoute)
  if not routeConf then
    ngx.arg[1] = scope.res.body
    return
  end
  response_access.body_filter(routeConf, scope)
end

return RewriteHandler
