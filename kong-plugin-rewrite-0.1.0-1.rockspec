package = "kong-plugin-rewrite"  
version = "0.1.0-1" 

local pluginName = package:match("^kong%-plugin%-(.+)$")

supported_platforms = {"linux", "macosx"}
source = {
  url = "http://github.com/Kong/kong-plugin.git",
  tag = "0.1.0"
}

description = {
  summary = "Kong is a scalable and customizable API Management Layer built on top of Nginx.",
  homepage = "http://getkong.org",
  license = "Apache 2.0"
}

dependencies = {
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins."..pluginName..".handler"] = "kong/plugins/"..pluginName.."/handler.lua",
    ["kong.plugins."..pluginName..".schema"] = "kong/plugins/"..pluginName.."/schema.lua",
    ["kong.plugins."..pluginName..".helpers"] = "kong/plugins/"..pluginName.."/helpers.lua",
    ["kong.plugins."..pluginName..".request_access"] = "kong/plugins/"..pluginName.."/request_access.lua",
    ["kong.plugins."..pluginName..".response_access"] = "kong/plugins/"..pluginName.."/response_access.lua",
  }
}