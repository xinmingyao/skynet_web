local build ={}
function build.gen_sql(name,tbl)
   local i,v
   local fields,types,values = {},{},{}
   local typs = {
      string = 
	 function(value)
	   return  "'" .. value .."'"
	 end
   }
   for k,v in pairs(tbl) do      
      table.insert(fields,k)
      local value = v
      local typ = type(value)
      if typ and typs[typ] then
	 value = typs[typ](value)
      end
      table.insert(values,value)
   end
   local sql = string.format("insert into %s (%s) values (%s)",
			     name,
			     table.concat(fields,","),
			     table.concat(values,","))
   return sql
end

return build