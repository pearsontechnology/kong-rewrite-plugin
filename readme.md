# Kong Rewrite Plugin

This plugin lets you rewrite and completely redefine both the request and response as they pass through Kong.  Rewrite is achieved using Lua scripts to allow for flexibility.

## Properties

**NOTE** This will change in the future.

### Route

The route object's key will be used as the path to the resource to rewrite.

#### method

The method of the request to rewrite.  If no value is provided then all methods will be handled.

#### request_method

A script to set the method that is sent to the backend, if you want to always send a method to the backend then just use a string like 'post'.

#### request_path

A script to set the path on the backend, if you want to always send to a specific backend path then just use a string like '/post'.

#### request_querystring

A script to rewrite the query string values before they are sent to the backend.

#### request_headers

A script to rewrite the header values before they are sent to the backend.

#### request_text

A script to rewrite the textual body before it is sent to the backend.

#### request_json

A script to rewrite the JSON body before it is sent to the backend.

#### response_headers

A script to rewrite the header values sent from the backend before they are returned to the client.

#### response_text

A script to rewrite the text body sent from the backend before it is returned to the client.

#### response_json

A script to rewrite the JSON body sent from the backend before it is returned to the client.

## Scope

### req

Available in request and response rewrite scripts.

#### content_type_value

Value of the raw Content-Type header as sent by the client to the proxy.

#### content_type

Decoded version of the Content-Type, useful for quick checks but doesn't catch many content types.

**Map**

 * text/html - html
 * text/plain - text
 * application/json - json
 * multipart/form-data - multi-part
 * application/x-www-form-urlencoded - form-encoded
 * Anything else - unknown

#### method

The requested HTTP method type.

#### path

The requested resource path.

#### headers

The headers from the request.

#### body

The raw body of the request, no transformation applied.

#### payload

The transformed request body.  If content_type is one of the following then this will contain a table of key value pairs representing the payload, otherwise this will be a string that matches body:

 * json
 * multi-part
 * form-encoded

#### query

Table of the key value sets from the search portion of the requested resource.

#### params

Table of the key value pairs defined in the request path.

### res

Available only in response rewrite scripts.

#### content_type_value

Value of the raw Content-Type header as sent by the backing service.

#### content_type

Decoded version of the Content-Type, useful for quick checks but doesn't catch many content types.

**Map**

 * text/html - html
 * text/plain - text
 * application/json - json
 * multipart/form-data - multi-part
 * application/x-www-form-urlencoded - form-encoded
 * Anything else - unknown

#### headers

The headers from the response.

#### body

The raw body of the response, no transformation applied.

#### payload

The transformed response body.  If content_type is one of the following then this will contain a table of key value pairs representing the payload, otherwise this will be a string that matches body:

 * json
 * multi-part
 * form-encoded

#### eof

Flag stating that the end of file flag was found and thus all of the content has been parsed and is available.

## Examples:

### request:

#### method:

Simple rewrite from any request method to a post method to the backend:

```lua
'post'
```

#### path:

Simple rewrite from any request path to a backend resource path of /post:

```lua
'/post'
```

#### querystring:

Append a new value to the existing query string values:

```lua
table.extend(req.query, {req = "added to request querystring"})
```

#### headers:

Append a new header to the existing request headers:

```lua
local newHeaders = {}
newHeaders['x-response-header'] = "added to request headers"
return table.extend(req.headers, newHeaders)
```

#### text:

Completely rewrite the request body to a string value:

```lua
'Some new text to send to the upstream endpoint'
```

#### json:

Rewrite the entire request payload to whatever parameters were defined in the request path:

```lua
req.params
```

### response:

#### headers:

Append a new header to the response headers:

```lua
local newHeaders = {}
newHeaders['x-response-header'] = "added to response headers"
return table.extend(res.headers, newHeaders)
```

#### text:

If the response was HTML then use some hackery to append an H1 to the body:

```lua
if res.content_type == 'html' then
  tostring(string.gsub(src, '<body(.-)>', '<body%1><h1>Not JSON</h1>', 1))
end
```

#### json:

Rewrite the response JSON payload so that it has a root of "response":

```lua
{response= res.payload}
```
