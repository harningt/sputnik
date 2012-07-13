module(..., package.seeall)

NODE = {
   title="Sitemap",
   category="_special_pages",
   actions=[[ show="wiki.list_nodes"; xml="wiki.show_sitemap_xml" ]],
   permissions=[[ allow(all_users, "xml") ]],
}
NODE.content=[=====[
The content of this page will be ignored.
]=====]

