
module(..., package.seeall)
local sorttable = require"sputnik.javascript.sorttable"
local wiki = require"sputnik.actions.wiki"

actions = {}

actions.list = function(node, request, sputnik)
   local tickets = {}
   for id, ticket in pairs(sputnik.saci:get_nodes_by_prefix(node.id.."/")) do
      if ticket.status~="closed" or request.params.show_closed then
         table.insert(tickets, ticket)
      end
   end
   table.sort(tickets, function(x,y) return x.id > y.id end)

   local function do_tickets()
      for i, ticket in ipairs(tickets) do
         cosmo.yield{
            ticket_link = sputnik:make_link(ticket.id),
            edit_link   = sputnik:make_link(ticket.id, "edit"),
            edit_icon   = sputnik:make_url("icons/edit-faded", "png"),
            ticket_id   = ticket.id:sub(node.id:len()+2),
            status      = ticket.status,
            num_status  = node.config.status_to_number[ticket.status],
            priority    = node.config.priority_to_number[ticket.priority],
            milestone   = ticket.milestone or "undef",
            title       = ticket.title,
            color       = node.config.status_colors[ticket.status] or "white",
         }
      end
   end

   local new_ticket_link = sputnik:make_link(node.id.."/new", "edit", 
                                             {reported_by = request.user}, nil, nil, 
                                             {mark_missing=false} )

   node.inner_html = cosmo.f(node.templates.LIST){
                        sorttable_script  = sorttable.script,
                        if_showing_all  = cosmo.c(request.params.show_closed){
                                             link=node.links:show()
                                          },
                        if_showing_open = cosmo.c(not request.params.show_closed){
                                             link=node.links:show{show_closed="1"}
                                          },
                        do_tickets = do_tickets,
                        new_ticket_link = new_ticket_link
                     }
   return node.wrappers.default(node, request, sputnik)
end

--local wiki = require("sputnik.actions.wiki")

PARENT_PATTERN = "(.+)%/[^%/]+$" -- everything up to the last slash

actions.save_new = function(node, request, sputnik)
   local parent_id = node.id:match(PARENT_PATTERN)
   local new_id = string.format("%s/%06d", parent_id, sputnik:get_uid(parent_id))
   local new_node = sputnik:get_node(new_id)
   sputnik:update_node_with_params(new_node, {prototype = "@Ticket"})
   new_node = sputnik:activate_node(new_node)
   new_node.inner_html = "Created a new ticket: <a "..sputnik:make_link(new_id)..">"
                         ..new_id.."</a><br/>"
                         .."List <a "..sputnik:make_link(parent_id)..">tickets</a>"
   return wiki.actions.save(new_node, request, sputnik)
end

actions.show = function(node, request, sputnik)
   local parent_id = node.id:match(PARENT_PATTERN)
   local index_node = sputnik:get_node(parent_id)
   local ticket_info = {
      if_resolved = cosmo.c(node.status=="closed" or node.status=="resolved"){
                       resolution = node.resolution,
                       resolution_details = node.markup.transform(node.resolution_details or " ")
                    },
      ticket_status_color = index_node.config.status_colors[node.status] or "white",
      ticket_priority_color = index_node.config.priority_colors[node.priority] or "white",
      priority_stars = index_node.config.priority_to_number[node.priority],
      index_link = sputnik:make_link(parent_id),
      ticket_id = node.id:gsub(parent_id.."/", ""):gsub("^(0*)", "<span style='color:gray'>%1</span>"),
      assigned_to = node.assigned_to or "",
      priority = node.priority or "",
   }
   if ticket_info.assigned_to == "" then 
      ticket_info.assigned_to = "<span style='color:red'>NOBODY</span>"
   end
   if node.priority=="unassigned" then
      ticket_info.priority = ""
      ticket_info.priority_stars = "???"
   end
   local mt = {__index = node}
   node.inner_html = cosmo.fill(node.templates.SHOW, setmetatable(ticket_info, mt))
   return node.wrappers.default(node, request, sputnik)
end
