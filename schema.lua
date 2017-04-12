return {
  -- no_consumer = true,
  fields = {
    routes = {
      type = "table",
      schema = {
        flexible = true,
        fields = {
          method = { type = "string", default = "" },
          request_method = { type = "string", default = "" },
          request_querystring = { type = "string", default = "", multiline = true },
          request_text = { type = "string", default = "", multiline = true },
          request_json = { type = "string", default = "", multiline = true },
          request_headers = { type = "string", default = "", multiline = true },
          response_text = { type = "string", default = "", multiline = true },
          response_json = { type = "string", default = "", multiline = true },
          response_headers = { type = "string", default = "", multiline = true },
        }
      }
    }
  --[[
  fields = {
    routes = {
      type = "table",
      schema = {
        flexible = true,
        fields = {
          method = { type = "string", default = "" },
          request = {
            type = "table",
            schema = {
              fields = {
                method = { type = "string", default = "" },
                querystring = { type = "string", default = "" },
                text = { type = "string", default = "" },
                json = { type = "string", default = "" },
                headers = { type = "string", default = "" },
              }
            }
          },
          response = {
            type = "table",
            schema = {
              fields = {
                text = { type = "string", default = "" },
                json = { type = "string", default = "" },
                headers = { type = "string", default = "" },
              }
            }
          }
        }
      }
    }
    ]]
  }
}
