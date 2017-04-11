local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson.safe"
local public_utils = require "kong.tools.public"
local request_access = require "kong.plugins.rewrite.request_access"
local response_access = require "kong.plugins.rewrite.response_access"
local helpers = require "kong.plugins.rewrite.helpers"

local isempty = helpers.isempty
local log = helpers.log
local dump = helpers.dump
local keys = helpers.keys

local req_get_method = ngx.req.get_method

local RewriteHandler = BasePlugin:extend()

RewriteHandler.PRIORITY = 800

log.warn("Loading handler.lua")

local function findRouteConf(conf, requestedRoute)
  local routeConf = conf.routes[requestedRoute]
  if routeConf then
    return routeConf
  end
  return false
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

function RewriteHandler:access(conf)
  RewriteHandler.super.access(self)
  local requestedRoute = ngx.var.request_uri
  local routeConf = findRouteConf(conf, requestedRoute)
  if not routeConf then
    return
  end
  request_access.access(routeConf)
end

function RewriteHandler:header_filter(conf)
  RewriteHandler.super.header_filter(self)
  local requestedRoute = ngx.var.request_uri
  local routeConf = findRouteConf(conf, requestedRoute)
  if not routeConf then
    return
  end
  response_access.header_filter(routeConf)
end

function RewriteHandler:body_filter(conf)
  RewriteHandler.super.body_filter(self)
  local requestedRoute = ngx.var.request_uri
  local routeConf = findRouteConf(conf, requestedRoute)
  if not routeConf then
    return
  end
  response_access.body_filter(routeConf)
end

return RewriteHandler
