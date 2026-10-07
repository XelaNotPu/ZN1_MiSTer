local m=manager.machine
for _,n in ipairs({':audiocpu',':ymf'}) do
  local r=m.memory.regions[n]
  local f=io.open('region'..n:gsub(':','_')..'.bin','wb')
  local t={}
  for a=0,r.size-1,4096 do
    local chunk={}
    for b=0,4095 do chunk[#chunk+1]=string.char(r:read_u8(a+b)) end
    f:write(table.concat(chunk))
  end
  f:close()
  print('REGION',n,r.size)
end
m:exit()
