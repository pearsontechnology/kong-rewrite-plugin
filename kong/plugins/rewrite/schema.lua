local Errors = require "kong.dao.errors"
local helpers = require "kong.plugins.rewrite.helpers"

local create_routes_tree = helpers.create_routes_tree

local function validate_routes(schema, config, dao, is_updating)
  local routes = config.routes and config.routes or {}
  local tree, hasError = create_routes_tree(routes)
  if(hasError) then
    helpers.log_error(tree.error)
    return false, Errors.schema(tree.error)
  end
  return true
end

return {
  -- no_consumer = true,
  self_check = validate_routes,
  --[[
  fields = {
    routes = {
      type = "table",
      schema = {
        flexible = true,
        fields = {
          method = { type = "string", default = "", multiline = true },
          request_method = { type = "string", default = "", multiline = true },
          request_path = { type = "string", default = "", multiline = true },
          request_querystring = { type = "string", default = "", multiline = true },
          request_headers = { type = "string", default = "", multiline = true },
          request_text = { type = "string", default = "", multiline = true },
          request_json = { type = "string", default = "", multiline = true },
          response_headers = { type = "string", default = "", multiline = true },
          response_text = { type = "string", default = "", multiline = true },
          response_json = { type = "string", default = "", multiline = true },
        }
      }
    }
  --]]
  -- [[
  fields = {
    routes = {
      type = "array",
      --schema = {
        --flexible = true,
        fields = {
          route = { type = "string", required = true },
          method = { type = "string", default = "" },
          request = {
            type = "table",
            schema = {
              fields = {
                method = { type = "string", default = "", multiline = true },
                path = { type = "string", default = "", multiline = true },
                querystring = { type = "string", default = "", multiline = true },
                text = { type = "string", default = "", multiline = true },
                json = { type = "string", default = "", multiline = true },
                headers = { type = "string", default = "", multiline = true },
              }
            }
          },
          response = {
            type = "table",
            schema = {
              fields = {
                text = { type = "string", default = "", multiline = true },
                json = { type = "string", default = "", multiline = true },
                headers = { type = "string", default = "", multiline = true },
              }
            }
          }
        }
      --}
    }
    --]]
  }
}
