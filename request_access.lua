local cjson = require "cjson.safe"
local helpers = require "kong.plugins.rewrite.helpers"

local mapTo = helpers.mapTo
local isempty = helpers.isempty
local get_content_type = helpers.get_content_type
local log = helpers.log

local req_set_uri_args = ngx.req.set_uri_args
local req_get_uri_args = ngx.req.get_uri_args
local req_set_header = ngx.req.set_header
local req_get_headers = ngx.req.get_headers
local req_read_body = ngx.req.read_body
local req_set_body_data = ngx.req.set_body_data
local req_get_body_data = ngx.req.get_body_data
local req_clear_header = ngx.req.clear_header
local req_set_method = ngx.req.set_method
local encode_args = ngx.encode_args
local ngx_decode_args = ngx.decode_args
local string_find = string.find

local function decode_args(body)
  if body then
    return ngx_decode_args(body)
  end
  return {}
end

local _M = {}

local function req_set_headers(oldHeaders, newHeaders)
  for name, value in pairs(oldHeaders) do
    req_clear_header(name)
  end
  for name, value in pairs(newHeaders) do
    req_set_header(name, value)
  end
end

local function transform_querystrings(conf)
  if isempty(conf.request_querystring) then
    return
  end
  local querystring = req_get_uri_args()
  req_set_uri_args(mapTo(querystring, conf.request_querystring))
end

local function transform_headers(conf)
  if isempty(conf.request_headers) then
    return
  end
  local headers = req_get_headers()
  req_set_headers(headers, mapTo(headers, conf.request_headers))
end

local function transform_url_encoded_body(conf, body, content_length)
  local parameters = decode_args(body)
  return true, cjson.encode(mapTo(parameters, conf.request_json))
end

local function transform_multipart_body(conf, body, content_length, content_type_value)
  local parameters = multipart(body and body or "", content_type_value)
  return true, cjson.encode(mapTo(parameters, conf.request_json))
end

local function transform_text_body(conf, body, content_length)
  return true, mapTo(json, conf.request_text)
end

local function transform_json_body(conf, body, content_length)
  local json, err = cjson.decode(body)
  if err then
    return false, body
  end
  return true, cjson.encode(mapTo(json, conf.request_json))
end

local function transform_body_text(conf)
  if isempty(conf.request_text) then
    return
  end
  local content_type_value = req_get_headers()['content-type']
  local content_type = get_content_type(content_type_value)

  -- Call req_read_body to read the request body first
  req_read_body()
  local body = req_get_body_data()
  local is_body_transformed = false
  local content_length = (body and #body) or 0

  if not content_type then
    is_body_transformed, body = transform_text_body(conf, "{}", content_length)
  elseif content_type == 'form-encoded' then
    is_body_transformed, body = transform_url_encoded_body(conf, body, content_length)
  elseif content_type == 'multi-part' then
    is_body_transformed, body = transform_multipart_body(conf, body, content_length, content_type_value)
  elseif content_type == 'text' then
      is_body_transformed, body = transform_text_body(conf, cjson.encode(body), content_length)
  elseif content_type == 'html' then
      is_body_transformed, body = transform_text_body(conf, cjson.encode(body), content_length)
  elseif content_type == 'json' then
    is_body_transformed, body = transform_text_body(conf, body, content_length)
  end

  if is_body_transformed then
    req_set_body_data(body)
    req_set_header('content-type', 'plain/text')
    req_set_header('content-length', #body)
  end
end

local function transform_body_json(conf)
  if isempty(conf.request_json) then
    return
  end

  local content_type_value = req_get_headers()['content-type']
  local content_type = get_content_type(content_type_value)

  -- Call req_read_body to read the request body first
  req_read_body()
  local body = req_get_body_data()
  local is_body_transformed = false
  local content_length = (body and #body) or 0

  if not content_type then
    is_body_transformed, body = transform_json_body(conf, "{}", content_length)
  elseif content_type == 'form-encoded' then
    is_body_transformed, body = transform_url_encoded_body(conf, body, content_length)
  elseif content_type == 'multi-part' then
    is_body_transformed, body = transform_multipart_body(conf, body, content_length, content_type_value)
  elseif content_type == 'text' then
      is_body_transformed, body = transform_json_body(conf, cjson.encode(body), content_length)
  elseif content_type == 'html' then
      is_body_transformed, body = transform_json_body(conf, cjson.encode(body), content_length)
  elseif content_type == 'json' then
    is_body_transformed, body = transform_json_body(conf, body, content_length)
  end

  if is_body_transformed then
    req_set_body_data(body)
    req_set_header('content-type', 'application/json')
    req_set_header('content-length', #body)
  end
end

local function transform_method(conf)
  if isempty(conf.request_method) then
    return
  end
  local newMethod = conf.request_method:upper()
  req_set_method(ngx["HTTP_"..newMethod])
  if conf.http_method == "GET" or conf.http_method == "HEAD" or conf.http_method == "TRACE" then
    local content_type_value = req_get_headers()["content-type"]
    local content_type = get_content_type(content_type_value)
    if content_type == 'form-encoded' then
      req_read_body()
      local body = req_get_body_data()
      local parameters = decode_args(body)

      -- Append to querystring
      local querystring = req_get_uri_args()
      for name, value in pairs(parameters) do
        querystring[name] = value
      end
      req_set_uri_args(querystring)
    end
  end
end

function _M.access(conf)
  transform_method(conf)
  transform_body_text(conf)
  transform_body_json(conf)
  transform_headers(conf)
  transform_querystrings(conf)
end

return _M
