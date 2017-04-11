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
          request_querystring = { type = "string", default = "" },
          request_text = { type = "string", default = "" },
          request_json = { type = "string", default = "" },
          request_headers = { type = "string", default = "" },
          response_text = { type = "string", default = "" },
          response_json = { type = "string", default = "" },
          response_headers = { type = "string", default = "" },
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
  --[[
  fields = {
    uri = {
      type = "table",
      schema = {
        fields = {
          route = { type = "string", default = "" },
          method = { type = "string", default = "" },
        }
      }
    },
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
    },
    --[[
    rewrite_request_method = { type = "string", default = "" },
    rewrite_request_querystring = { type = "string", default = "" },
    rewrite_request_text = { type = "string", default = "" },
    rewrite_request_json = { type = "string", default = "" },
    rewrite_request_headers = { type = "string", default = "" },
    rewrite_response_text = { type = "string", default = "" },
    rewrite_response_json = { type = "string", default = "" },
    rewrite_response_headers = { type = "string", default = "" },
    ]]
  }
}
