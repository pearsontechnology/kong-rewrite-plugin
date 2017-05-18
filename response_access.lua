local cjson = require "cjson.safe"
local helpers = require "kong.plugins.rewrite.helpers"

local mapTo = helpers.mapTo
local isempty = helpers.isempty
local get_content_type = helpers.get_content_type

local _M = {}

local function clear_length(scope)
  local ngx_headers = scope.res.headers
  ngx_headers["content-length"] = nil
end

function _M.header_filter(conf, scope)
  if not isempty(conf.response.text) or not isempty(conf.response.json) then
    clear_length(scope)
  end
  if isempty(conf.response.headers) then
    return
  end
  clear_length(scope)
  ngx_headers = mapTo(scope, conf.response.headers)
end

function _M.body_filter(conf, scope)
  if isempty(conf.response.text) and isempty(conf.response.json) then
    ngx.arg[1] = scope.res.body
    return
  end
  if scope.res.eof then
    local body = scope.res.body
    local content_type = scope.res.content_type
    if content_type == 'text' and not isempty(conf.response.text) then
      ngx.arg[1] = mapTo(scope, conf.response.text)
      return
    end
    if content_type == 'html' and not isempty(conf.response.text) then
      ngx.arg[1] = mapTo(scope, conf.response.text)
      return
    end
    if content_type == 'json' and not isempty(conf.response.json) then
      local rawRes = mapTo(scope, conf.response.json)
      local newRes, err = cjson.encode(rawRes)
      if(err) then
        helpers.log.error('JSON Handler:ERROR ', conf.response.json, ' raw('..type(rawRes)..'): ', helpers.dump(rawRes), ' json: ', helpers.dump(newRes), ' error: ', err)
        ngx.arg[1] = err
        return
      end
      ngx.arg[1] = newRes
      return
    end
    ngx.arg[1] = scope.res.body
  end
end

return _M
