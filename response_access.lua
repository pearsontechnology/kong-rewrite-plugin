local cjson = require "cjson.safe"
local helpers = require "kong.plugins.rewrite.helpers"

local mapTo = helpers.mapTo
local isempty = helpers.isempty
local get_content_type = helpers.get_content_type

local _M = {}

function _M.header_filter(conf)
  local ngx_headers = ngx.header;
  ngx_headers["content-length"] = nil
  if not isempty(conf.response_headers) then
    ngx_headers = mapTo(ngx_headers, conf.response_headers)
  end
end

function _M.body_filter(conf)
  local chunk, eof = ngx.arg[1], ngx.arg[2]
  local runscope_data = ngx.ctx.runscope or {res_body = ""}
  runscope_data.res_body = (runscope_data.res_body or "")..chunk
  ngx.ctx.runscope = runscope_data
  if eof then
    local body = ngx.ctx.runscope.res_body
    local content_type = get_content_type(ngx.header["content-type"])
    if content_type == 'text' and not isempty(conf.response_text) then
      ngx.arg[1] = mapTo(body, conf.response_text)
      return
    end
    if content_type == 'html' and not isempty(conf.response_text) then
      ngx.arg[1] = mapTo(body, conf.response_text)
      return
    end
    if content_type == 'json' and not isempty(conf.response_json) then
      local json, err = cjson.decode(body)
      if not err then
        ngx.arg[1] = cjson.encode(mapTo(json, conf.response_json))
        return
      end
    end
    ngx.arg[1] = body
    return
  end
  ngx.arg[1] = nil
end

return _M
