
module(..., package.seeall)

require("md5")
require("cosmo")
require("versium.smart.repository")
require("versium.luaenv")
require("sputnik")
require("sputnik.actions.wiki")
require("sputnik.authentication.simple")
require("sputnik.i18n")
require("sputnik.util")

---------------------------------------------------------------------------------------------------
-- THE SPUTNIK CLASS  -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
---------------------------------------------------------------------------------------------------
Sputnik = {}

---------------------------------------------------------------------------------------------------
-- Creates a new instance of Sputnik.
---------------------------------------------------------------------------------------------------
function Sputnik:new(initial_config)
   local obj = {}
   setmetatable(obj, self)
   self.__index = self
   obj:init(initial_config)
   return obj
end

---------------------------------------------------------------------------------------------------
-- Initializes a the new Sputnik instance.
---------------------------------------------------------------------------------------------------
function Sputnik:init(initial_config)
   -- setup the logger -- do this before loading user configuration
   if initial_config.LOGGER then
      require("logging."..initial_config.LOGGER)
      self.logger = logging[initial_config.LOGGER](unpack(initial_config.LOGGER_PARAMS))
   else
      self.logger = {
         debug = function(self, level, message) end, -- do nothing
         info = function(self, level, message) end,
         error = function(self, level, message) end,
      }
   end
   versium.luaenv.logger = self.logger

   -- setup the repository -- do this before loading user configuration
   self.repo = versium.smart.repository.Repository:new(initial_config)
   self.repo.logger = self.logger 
   -- setup markup
   self.markup_module = require(initial_config.MARKUP_MODULE or "sputnik.markup.markdown")
   self.markup = self.markup_module.new(self)

   -- WARNING ------------------------------------------------------------------------
   -- Up to now we were using "initial_config" which is loaded from sputnik/config.lua
   -- We are now going to load values from the configuration node.  This means that
   -- the config values can no longer be trusted.
   
   self.config = initial_config
   initial_config = nil -- just to keep us honest    
   for k,v in pairs(self:get_node(self.config.CONFIG_PAGE_NAME).content) do
      self.config[k] = v
   end
      
   -- setup authentication
   self.auth = sputnik.authentication.simple.make_authenticator(self)
   
   -- setup wrappers
   self.wrappers = sputnik.actions.wiki.wrappers -- same for "wiki" wrappers      
end


--- Escapes a text for using in a textarea.
function Sputnik.escape(self, text) return sputnik.util.escape(text) end
--- Escapes a URL.
function Sputnik.escape_url (self, text) return sputnik.util.escape_url(text) end
--- Turns a string into something that can be used as a node name.
function Sputnik.dirify(self, text) return sputnik.util.dirify(text) end

---------------------------------------------------------------------------------------------------
--- Makes a URL from a table of parameters.
---------------------------------------------------------------------------------------------------
function Sputnik:make_url(node_name, action, params, anchor)
   node_name = self:dirify(node_name)
   if action and action~="show" then 
      node_name = node_name.."."..action
   end
   if anchor then
      anchor = "#"..anchor
   else
      anchor = ""
   end
   if params and next(params) then
      local link = self.config.BASE_URL.."?p="..node_name
      for k, v in pairs(params or {}) do
         link = link.."&"..k.."="..v
      end
      return self:escape(link..anchor)
   else
      return self:escape(self.config.NICE_URL..node_name..anchor)
   end   
end

---------------------------------------------------------------------------------------------------
--- Makes a link from a table of parameters.
---------------------------------------------------------------------------------------------------
function Sputnik:make_link(node_name, action, params, anchor)
   assert(node_name)
   if node_name:find("%.") then -- allow for the action to be passed attached to the node name
      node_name, action = node_name:match("(.+)%.(.+)")
   end
   local css_class = "local"
   local url = self:make_url(node_name, action, params, anchor)
   self.logger:debug("Creating a link to "..node_name)
   if not self.repo:node_exists(node_name) then
      css_class="no_such_node"
      url = self:make_url(node_name, action, params, achnor) --"edit", params, anchor)
      self.logger:debug("No such node, will link to .edit")
   end
   return string.format("href='%s' class='%s'", url, css_class)
end

---------------------------------------------------------------------------------------------------
--- Does a bit of extra activation beyond what versium's smart repository does.
---------------------------------------------------------------------------------------------------
function Sputnik:activate_node(node, params)

   -- setup the page-specific translator
   for i, translation_node in ipairs(node.translations) do
      local translations = self:get_node(translation_node).content
      assert(type(translations) == "table", "the translation node should load and evaluate into a table")
      for k, translation in pairs(translations) do
         node.translations[k] = translation
      end
    end
    node.translator = sputnik.i18n.make_translator(node.translations, self.config.INTERFACE_LANGUAGE)
    
   -- translate the templates
   for i, template_node in ipairs(node.templates) do
      local templates = self:get_node(template_node).content
      assert(type(templates) == "table", "the template node should load and evaluate into a table")
      for k, template in pairs(templates) do
         node.templates[k] = node.translator.translate(template)
      end
   end
   
   -- load the actions (turn them into callable functions)
   local function action_loader() 
      local mod_cache = {}
      return { 
         load = function(mod_name)
            if not mod_cache[mod_name] then
               mod_cache[mod_name] = require("sputnik.actions." .. mod_name)
            end
            return mod_cache[mod_name].actions
         end
      }
   end
   local action_loader = action_loader()
   
   for k, v in pairs(node.actions) do
      local mod_name, dot_action = sputnik.util.split(v, "%.")
      node.actions[k] = action_loader.load(mod_name)[dot_action]
   end
   
   -- create a function to check permissions ---------------------------
   node.check_permissions = function(user, action)
      local state = true
      local all = true -- just a constant          
      local function set(id, some_action, value)
         if (some_action == action) then
            if (type(id)=="string" and id==user) or id==true then 
               state = value
            end
         end
      end         
      local function allow(some_user, some_action) 
         set(some_user, some_action, true)
      end
      local function deny(some_user, some_action)
         set(some_user, some_action, false)
      end
      versium.luaenv.make_sandbox{all = all, allow = allow, deny = deny}.do_lua(node.permissions or "")
      return state
   end     
   
   -- set wrappers -----------------------------------------------------
   node.wrappers = self.wrappers
   
   return node
end

---------------------------------------------------------------------------------------------------
-- Returns the node with this name (without additional activation).
---------------------------------------------------------------------------------------------------
function Sputnik:get_node(node_name, version, mode)
   local node = self.repo:get_node(node_name, version, mode)
   node.name = node_name
   if not node.title then
      local temp_title = string.gsub(node.name, "_", " ")
      node.title = temp_title
      node._vnode.title = temp_title
   end
   if mode~="basic" then
      self:prime_node(node)
   end
   return node
end

---------------------------------------------------------------------------------------------------
-- Adds extra sputnik-specific fields to a node.
---------------------------------------------------------------------------------------------------
function Sputnik:prime_node(node)
   node.markup = self.markup
   self:add_urls(node)
   self:add_links(node)
   return node
end  

---------------------------------------------------------------------------------------------------
-- Makes node.urls:foo(params) equivalent to sputnik:make_url(node.name, "foo", 
-- params) for ANY foo.
---------------------------------------------------------------------------------------------------
function Sputnik:add_urls(node)
   node.urls = { __index = function(table, key)
                              return function(inner_self, params)
                                 return self:make_url(node.name, key, params)
                              end
                           end
               }
   setmetatable(node.urls, node.urls)
   return node
end

---------------------------------------------------------------------------------------------------
-- Makes node.links:foo(params) equivalent to sputnik:make_link(node.name, "foo", params) for ANY 
-- foo.
---------------------------------------------------------------------------------------------------
function Sputnik:add_links(node)
   node.links = { __index = function(table, key)
                               return function(inner_self, params)
                                  return self:make_link(node.name, key, params)
                               end
                            end
                }
   setmetatable(node.links, node.links)
   return node
end

---------------------------------------------------------------------------------------------------
-- Generates a node-like table to make urls.
---------------------------------------------------------------------------------------------------
function Sputnik.pseudo_node(self, node_name)
   local node = {name = node_name }
   self:add_urls(node)
   self:add_links(node)
   return node
end

---------------------------------------------------------------------------------------------------
--- Updates node with values from params table.
---------------------------------------------------------------------------------------------------
function Sputnik:update_node_with_params(node, params)
   node:update(params, node.fields)
   --new_node.name = node.name
   self:prime_node(node)
   return node
end

---------------------------------------------------------------------------------------------------
-- Returns node's history.
---------------------------------------------------------------------------------------------------
function Sputnik:get_history(node_name, limit, date)
   local edits = self.repo:get_node_history(node_name, date)  -- limit discarded for now
   if limit then 
      for i=limit, #edits do
         table.remove(edits, i)
      end
   end
   return edits
end

---------------------------------------------------------------------------------------------------
-- Returns history for all nodes.
---------------------------------------------------------------------------------------------------
function Sputnik:get_complete_history(limit, date)
   local edits = {}
   for i, id in ipairs(self:get_node_names()) do
      local node = Sputnik.pseudo_node(self, id)
      node.id = id
      for i, edit in ipairs(self:get_history(id, limit, date)) do
         edit.id = id
         edit.node = node
         table.insert(edits, edit)
      end
   end
   table.sort(edits, function(e1, e2) return e1.timestamp > e2.timestamp end)
   if limit then 
      for i=limit, #edits do
         table.remove(edits, i)
      end
   end   
   return edits
end

---------------------------------------------------------------------------------------------------
-- Returns a list of all node ids.
---------------------------------------------------------------------------------------------------
function Sputnik.get_node_names(self)
   local node_ids = self.repo.versium:get_node_ids() -- reaching deep
   return node_ids
end

---------------------------------------------------------------------------------------------------
-- Parses safely Lua code in a string and use it as table.
---------------------------------------------------------------------------------------------------
function Sputnik.make_sandbox(self, env)
   return versium.luaenv.make_sandbox(env)
end

---------------------------------------------------------------------------------------------------
-- Generates a hash for a POST field name.
---------------------------------------------------------------------------------------------------
function Sputnik:hash_field_name(field_name, token)
   return "field_"..md5.sumhexa(field_name..token..self.config.SECRET_CODE)
end

---------------------------------------------------------------------------------------------------
-- Pre-processes CGI parameters and does authentication.
---------------------------------------------------------------------------------------------------
function Sputnik:translate_request (request)
   if request.method=="POST" then
      request.params = request.POST or {}
   else
      request.params = request.GET or {}
   end

   -- For a post action we'll need to unhash the parameters first.  Note that we don't care if the 
   -- action was actually submitted via get or post: if an idempotent request was sent via POST,
   -- that's ok.  Instead, we divide actions into two types: those that were submitted with a post
   -- token and those that were submitted without.  Requests submitted with a post token are
   -- allowed to make changes to the state of the wiki.  They get their fields unhashed.  This
   -- means that if an action is submitted with a post token but its fields are not hashed, it will
   -- be processed as if submitted with no arguments.
   if request.params.post_token then
      assert(request.params.post_fields)
      self.logger:debug("handling post parameters")
      local new_params = {}
      for k,v in pairs(request.params) do
         if k:sub(0,7) == "action_" then
            new_params[k] = v
         end
      end
      for name in string.gmatch(request.params.post_fields, "[%a_]+") do 
         self.logger:debug(name)
         new_params[name] = request.params[self:hash_field_name(name, request.params.post_token)]
         --self.logger:debug(new_params[name])
      end
      new_params.p = request.params.p
      new_params.post_token = request.params.post_token
      new_params.post_timestamp = request.params.post_timestamp
      request.params = new_params
   end
   
   -- break "p" parameter into node name and the action
   if request.params.p then
      request.node_name, request.action = sputnik.util.split(request.params.p, "%.")
   else
      request.node_name = self.config.HOME_PAGE 
   end
   request.action = request.action or "show"

   -- now login/logout/register the user
   if request.params.logout then 
      request.user = nil
   elseif (request.params.user or ""):len() > 0 then
      local success, v1, v2 = self:mypcall(self.auth.check_password, request.params.user, request.params.password)
      if success then
         request.user = v1
         request.auth_token = v2
      else
         request.err, request.traceback = unpack(v1)
         return request -- give up, send the error message up
      end

      if not request.user then
         request.auth_message = "INCORRECT_PASSWORD"
      end
   else
      local cookie = request.cookies[self.cookie_name] or ""
      local user_from_cookie, auth_token = sputnik.util.split(cookie, "|")
      if user_from_cookie then
         request.user = self.auth.check_token(user_from_cookie, auth_token)
         if request.user then
            request.auth_token = auth_token
         end
      end
   end
   return request
end

---------------------------------------------------------------------------------------------------
-- Executes a function safely.
---------------------------------------------------------------------------------------------------
function Sputnik:mypcall(fn, ...)
   local params = {...}
   return xpcall(function()
                    return fn(unpack(params))
                 end,
                 function (e)
                      local debug = require"debug"
                      local t = debug.traceback()
                      return {e, t}
                 end)
end

---------------------------------------------------------------------------------------------------
-- Reports an error to the user.
---------------------------------------------------------------------------------------------------
function Sputnik:report_error(request)
    local response = wsapi.response.new()
    local message = "An unexpected error occurred" -- ::LOCALIZE::
    local dummy, path = string.match(request.err, "Versium storage error: (.*) Can't open file: (.*) in mode w") 
    if path and path:sub(1, self.config.VERSIUM_PARAMS.dir:len()) == self.config.VERSIUM_PARAMS.dir then
       message = "Versium's data directory ("..self.config.VERSIUM_PARAMS.dir
                  ..") is not writable.<br/> Please fix directory permissions." -- ::LOCALIZE::
    end
    response:write(string.format([[<br/>
       <span style="color:red; font-size: 19pt;">%s</span></br><br/><br/>
       Error details:
       <b><code>%s</code></b><br/>
       <pre><code>%s</code></pre>
    ]], message, request.err, request.traceback)) --, string.gsub(request.traceback, "\n", "<br/>\n")))
    return response:finish()
end

---------------------------------------------------------------------------------------------------
-- Executes a request.
---------------------------------------------------------------------------------------------------
function Sputnik:run(request)
   local response = wsapi.response.new()
   self.cookie_name = "Sputnik_"..md5.sumhexa(self.config.BASE_URL)
   local request_for_logger = request.params.p or "<default>"
   self.logger:info("=== "..request_for_logger.." ============")
   request = self:translate_request(request)
   if request.err then 
       return self:report_error(request, response)
   end

   local node = self:get_node(request.node_name, request.params.version)
   if request.params.prototype then 
      self:update_node_with_params(node, {prototype = request.params.prototype})
   end
   node = self:activate_node(node, request)

   local action_function = node.actions[request.action or "show"]
                           or sputnik.actions.wiki.actions.action_not_found

   local content, content_type = action_function(node, request, self)
   assert(content)

   response.headers["Content-type"] = content_type or "text/html"
   response:set_cookie(self.cookie_name, (request.user or "").."|"..(request.auth_token or ""), {path="/"})
   response:write(content)
   self.logger:info("--- end of "..request_for_logger.." -----")
   return response:finish()
end


--require("sputnik_config")
require("wsapi.request")
require("wsapi.response")


function unprotected_run(wsapi_env)
   SPUTNIK_CONFIG.ROOT_PROTOTYPE   = SPUTNIK_CONFIG.ROOT_PROTOTYPE   or "@Root"
   SPUTNIK_CONFIG.SECRET_CODE      = SPUTNIK_CONFIG.SECRET_CODE      or "23489701982370894172309847123"
   SPUTNIK_CONFIG.CONFIG_PAGE_NAME = SPUTNIK_CONFIG.CONFIG_PAGE_NAME or "_config"
   SPUTNIK_CONFIG.PASS_PAGE_NAME   = SPUTNIK_CONFIG.PASS_PAGE_NAME   or "_passwords"
   --SPUTNIK_CONFIG.LOGGER           = SPUTNIK_CONFIG.LOGGER           or "file"
   --SPUTNIK_CONFIG.LOGGER_PARAMS    = SPUTNIK_CONFIG.LOGGER_PARAMS    or {"/tmp/sputnik-log.log", "%Y-%m-%d"}

   local mySputnik = sputnik.Sputnik:new(SPUTNIK_CONFIG)
   return mySputnik:run(wsapi.request.new(wsapi_env))
end

function mypcall(fn, ...)
   local params = {...}
   return xpcall(function()
                    return fn(unpack(params))
                 end,
                 function (e)
                      local debug = require"debug"
                      local t = debug.traceback()
                      return {e, t}
                 end)
end

function show_error(err, traceback) 
    local response = wsapi.response.new()
    local message = "Sputnik ran but failed due to an unexpected error." -- ::LOCALIZE::
    local dummy, path = string.match(err, "Versium storage error: (.*) Can't open file: (.*) in mode w") 
    response:write(string.format([[<br/>
       <span style="color:red; font-size: 19pt;">%s</span></br><br/><br/>
       Error details: <b><code>%s</code></b><br/>
       <pre><code>%s</code></pre>
    ]], message, err, traceback))
    return response:finish()
end

function run(wsapi_env)
   success, status_code, headers, callback = mypcall(unprotected_run, wsapi_env)
   if success then 
      return status_code, headers, callback 
   else -- Huston, we have a problem
      local err, traceback = unpack(status_code) -- status_code is actually the output of the error function at this point
      return show_error(err, traceback)
   end
end
