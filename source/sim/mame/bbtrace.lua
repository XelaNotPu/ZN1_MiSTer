-- Brave Blade Raizing sound-board bus trace (MAME 0.289)
-- Env: BB_OUT (output dir), BB_SECS (seconds to run), BB_COIN (time to insert coin), BB_START
local m=manager.machine
local out=os.getenv('BB_OUT') or './'
local secs=tonumber(os.getenv('BB_SECS') or '60')
local coin_t=tonumber(os.getenv('BB_COIN') or '-1')
local start_t=tonumber(os.getenv('BB_START') or '-1')
local ymf_log_all=(os.getenv('BB_YMFALL') or '1')=='1'

local main=m.devices[':maincpu']
local ms=main.spaces['program']
local snd=m.devices[':audiocpu']
local ss=snd.spaces['program']
local ymf=m.devices[':ymf']
local ys=ymf.spaces['rom']

local ev=assert(io.open(out..'events.txt','w'))
local ymfw=assert(io.open(out..'ymf_writes.txt','w'))
local function t() return m.time:as_double() end

local cnt={latch_w=0,irq_w=0,latch_r=0,ymf_w=0,ymf_r={},vec2=0,other_w=0}
local ram_min,ram_max=0xffffff,0
local ramr_min,ramr_max=0xffffff,0
local rom_max=0
local smp_min,smp_max=0xffffffff,0
local last_snap=-100

-- PSX side (wide tap: narrow taps on the 8-bit latch handler do not fire)
tap1=ms:install_write_tap(0x1f000000,0x1fffffff,'bb_psxw',function(off,data,mask)
  if off>=0x1fb00000 and off<=0x1fb00007 then
    local pc=0
    if off==0x1fb00000 then cnt.latch_w=cnt.latch_w+1 else cnt.irq_w=cnt.irq_w+1 end
    ev:write(string.format('%.6f PSXW %08X data=%08X mask=%08X pc=%08X\n',t(),off,data,mask,pc))
  elseif off==0x1fa10300 then
    ev:write(string.format('%.6f SECSEL data=%02X\n',t(),data&0xff))
  elseif off>=0x1fb00008 then
    cnt.other_w=cnt.other_w+1
    if cnt.other_w<50 then ev:write(string.format('%.6f PSXW-OTHER %08X data=%08X mask=%08X\n',t(),off,data,mask)) end
  end
end)

-- 68000 side
tap2=ss:install_read_tap(0x180008,0x180009,'bb_latchr',function(off,data,mask)
  cnt.latch_r=cnt.latch_r+1
  ev:write(string.format('%.6f 68KR latch off=%06X data=%04X mask=%04X pc=%06X\n',t(),off,data,mask,snd.state['PC'].value))
end)
tap3=ss:install_read_tap(0x000068,0x00006b,'bb_vec2',function(off,data,mask)
  cnt.vec2=cnt.vec2+1
  ev:write(string.format('%.6f 68K-VEC2 off=%06X data=%04X\n',t(),off,data))
end)
tap4=ss:install_write_tap(0x100000,0x10001f,'bb_ymfw',function(off,data,mask)
  cnt.ymf_w=cnt.ymf_w+1
  if ymf_log_all then
    ymfw:write(string.format('%.7f W %02X %02X %04X\n',t(),(off-0x100000)>>1,data&0xff,mask))
  end
end)
tap5=ss:install_read_tap(0x100000,0x10001f,'bb_ymfr',function(off,data,mask)
  local r=(off-0x100000)>>1
  cnt.ymf_r[r]=(cnt.ymf_r[r] or 0)+1
  if cnt.ymf_r[r]<=200 or (data&0x7f)~=0 then
    ymfw:write(string.format('%.7f R %02X %02X %04X pc=%06X\n',t(),r,data&0xff,mask,snd.state['PC'].value))
  end
end)
tap6=ss:install_write_tap(0x080000,0x0fffff,'bb_ramw',function(off,data,mask)
  if off<ram_min then ram_min=off end
  if off>ram_max then ram_max=off end
end)
tap7=ss:install_read_tap(0x080000,0x0fffff,'bb_ramr',function(off,data,mask)
  if off<ramr_min then ramr_min=off end
  if off>ramr_max then ramr_max=off end
end)
tap8=ss:install_read_tap(0x000000,0x07ffff,'bb_rom',function(off,data,mask)
  if off>rom_max then rom_max=off end
end)
tap9=ss:install_read_tap(0x100020,0x180007,'bb_unm1',function(off,data,mask)
  ev:write(string.format('%.6f 68KR-UNMAPPED %06X pc=%06X\n',t(),off,snd.state['PC'].value))
end)
tap11=ss:install_read_tap(0x18000a,0xffffff,'bb_unm3',function(off,data,mask)
  ev:write(string.format('%.6f 68KR-UNMAPPED %06X pc=%06X\n',t(),off,snd.state['PC'].value))
end)
tap12=ys:install_read_tap(0x000000,0x7fffff,'bb_smp',function(off,data,mask)
  if off<smp_min then smp_min=off end
  if off>smp_max then smp_max=off end
end)

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
  if now-last_snap>=2 then
    last_snap=now
    m.screens[':screen']:snapshot(string.format('snap_%04d.png',math.floor(now)))
  end
  if now-last_rep>=10 then
    last_rep=now
    print(string.format('T=%.1f latchW=%d irqW=%d latchR=%d vec2=%d ymfW=%d', now,cnt.latch_w,cnt.irq_w,cnt.latch_r,cnt.vec2,cnt.ymf_w))
  end
  if now>=secs then
    local s=assert(io.open(out..'summary.txt','w'))
    s:write(string.format('time=%.3f\nlatch_w=%d irq_w=%d latch_r=%d vec2_reads=%d ymf_w=%d other_w=%d\n',now,cnt.latch_w,cnt.irq_w,cnt.latch_r,cnt.vec2,cnt.ymf_w,cnt.other_w))
    for r,c in pairs(cnt.ymf_r) do s:write(string.format('ymf_read reg %02X: %d\n',r,c)) end
    s:write(string.format('ram_write %06X-%06X\nram_read %06X-%06X\nrom_read_max %06X\nsample %06X-%06X\n',ram_min,ram_max,ramr_min,ramr_max,rom_max,smp_min,smp_max))
    s:close(); ev:close(); ymfw:close()
    m:exit()
  end
end)
m.video.throttled=false
print('BB_TRACE_READY')
