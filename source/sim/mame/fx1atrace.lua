-- Taito FX-1A (Z80 + YM2610B + TC0140SYT) bus trace, MAME 0.289
-- Env: TR_OUT (output dir, trailing /), TR_SECS, TR_COIN, TR_START (seconds, -1 = never)
-- Writes events.txt (PSX<->TC0140SYT, Z80 bank/pan/misc), ym_writes.txt (every YM2610B
-- register write as "time port reg data"), summary.txt (RAM/ROM/ADPCM ranges).
local m=manager.machine
local out=os.getenv('TR_OUT') or './'
local secs=tonumber(os.getenv('TR_SECS') or '60')
local coin_t=tonumber(os.getenv('TR_COIN') or '-1')
local start_t=tonumber(os.getenv('TR_START') or '-1')

local main=m.devices[':maincpu']
local ms=main.spaces['program']
local snd=m.devices[':audiocpu']
local ss=snd.spaces['program']
local ym=m.devices[':ym2610b']

local ev=assert(io.open(out..'events.txt','w'))
local yw=assert(io.open(out..'ym_writes.txt','w'))
local function t() return m.time:as_double() end
local function pc() return snd.state['PC'].value end

local cnt={psx_w=0,psx_r=0,ym_w=0,ym_r=0,syt_w=0,syt_r=0,bank=0,pan=0,misc=0}
local ram_min,ram_max,rom_max=0xffff,0,0
local bank_rom_max=0
local cur_bank=1
local adr={[0]=0,[1]=0}
local amin,amax={},{}
local last_snap=-100

tp1=ms:install_write_tap(0x1fb80000,0x1fb80003,'a_psxw',function(off,data,mask)
  cnt.psx_w=cnt.psx_w+1
  ev:write(string.format('%.7f PSXW %08X d=%08X m=%08X\n',t(),off,data,mask))
end)
tp2=ms:install_read_tap(0x1fb80000,0x1fb80003,'a_psxr',function(off,data,mask)
  cnt.psx_r=cnt.psx_r+1
  if cnt.psx_r<100000 then ev:write(string.format('%.7f PSXR %08X d=%08X m=%08X\n',t(),off,data,mask)) end
end)
tp3=ss:install_write_tap(0xe000,0xe003,'a_ymw',function(off,data,mask)
  cnt.ym_w=cnt.ym_w+1
  local p=(off>>1)&1
  if (off&1)==0 then adr[p]=data&0xff
  else yw:write(string.format('%.7f %d %02X %02X\n',t(),p,adr[p],data&0xff)) end
end)
tp4=ss:install_read_tap(0xe000,0xe003,'a_ymr',function(off,data,mask)
  cnt.ym_r=cnt.ym_r+1
end)
tp5=ss:install_write_tap(0xe200,0xe201,'a_sytw',function(off,data,mask)
  cnt.syt_w=cnt.syt_w+1
  ev:write(string.format('%.7f Z80W %04X d=%02X pc=%04X\n',t(),off,data&0xff,pc()))
end)
tp6=ss:install_read_tap(0xe201,0xe201,'a_sytr',function(off,data,mask)
  cnt.syt_r=cnt.syt_r+1
  ev:write(string.format('%.7f Z80R %04X d=%02X pc=%04X\n',t(),off,data&0xff,pc()))
end)
tp7=ss:install_write_tap(0xe400,0xf2ff,'a_misc',function(off,data,mask)
  if off==0xf200 then cnt.bank=cnt.bank+1; cur_bank=data&7
  elseif off>=0xe400 and off<=0xe403 then cnt.pan=cnt.pan+1
  else cnt.misc=cnt.misc+1 end
  if cnt.bank+cnt.pan+cnt.misc<5000 then
    ev:write(string.format('%.7f Z80W %04X d=%02X pc=%04X\n',t(),off,data&0xff,pc()))
  end
end)
tp8=ss:install_write_tap(0xc000,0xdfff,'a_ramw',function(off,data,mask)
  if off<ram_min then ram_min=off end
  if off>ram_max then ram_max=off end
end)
tp9=ss:install_read_tap(0x0000,0x7fff,'a_rom',function(off,data,mask)
  if off<0x4000 then if off>rom_max then rom_max=off end
  else local a=cur_bank*0x4000+(off-0x4000); if a>bank_rom_max then bank_rom_max=a end end
end)
local ytaps={}
for _,sp in ipairs({'adpcm_a','adpcm_b'}) do
  local s=ym.spaces[sp]
  if s then
    amin[sp]=0xffffffff; amax[sp]=0
    ytaps[#ytaps+1]=s:install_read_tap(0,0xffffff,'a_'..sp,function(off,data,mask)
      if off<amin[sp] then amin[sp]=off end
      if off>amax[sp] then amax[sp]=off end
    end)
  else ev:write('no space '..sp..'\n') end
end

local coined,started=false,false
local coinrel,startrel=nil,nil
local sys=m.ioport.ports[':SYSTEM']
local last_rep=0
frame=emu.add_machine_frame_notifier(function()
  local now=t()
  if coin_t>=0 and not coined and now>=coin_t then
    coined=true; sys.fields['Coin 1']:set_value(1); coinrel=now+0.15
    ev:write(string.format('%.6f INPUT coin\n',now))
  end
  if coinrel and now>=coinrel then sys.fields['Coin 1']:set_value(0); coinrel=nil end
  if start_t>=0 and not started and now>=start_t then
    started=true; sys.fields['1 Player Start']:set_value(1); startrel=now+0.15
    ev:write(string.format('%.6f INPUT start\n',now))
  end
  if startrel and now>=startrel then sys.fields['1 Player Start']:set_value(0); startrel=nil end
  if now-last_snap>=5 then
    last_snap=now
    m.screens[':screen']:snapshot(string.format('snap_%04d.png',math.floor(now)))
  end
  if now-last_rep>=10 then
    last_rep=now
    print(string.format('T=%.1f psxW=%d ymW=%d sytW=%d sytR=%d bank=%d',now,cnt.psx_w,cnt.ym_w,cnt.syt_w,cnt.syt_r,cnt.bank))
  end
  if now>=secs then
    local s=assert(io.open(out..'summary.txt','w'))
    s:write(string.format('time=%.3f\n',now))
    for k,v in pairs(cnt) do s:write(string.format('%s=%d\n',k,v)) end
    s:write(string.format('ram_write %04X-%04X\nrom_read_max %04X\nbank_rom_max %05X\n',ram_min,ram_max,rom_max,bank_rom_max))
    for k,_ in pairs(amin) do s:write(string.format('%s %06X-%06X\n',k,amin[k],amax[k])) end
    s:close(); ev:close(); yw:close()
    m:exit()
  end
end)
m.video.throttled=false
print('FX1A_TRACE_READY')
