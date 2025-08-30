pico-8 cartridge // http://www.pico-8.com
ver 4
__lua__
-- dollhouse leak fixer
gs="playing"
sc,t,fm,ft=0,0,"",0
p={x=64,y=64,w=8,h=8,s=1,r=1,i=nil}
rs={{i=1,n="kitchen",x=0,y=48,w=32,h=24,f=0,l=false},
{i=2,n="bedroom",x=32,y=48,w=32,h=24,f=0,l=false},
{i=3,n="bathroom",x=64,y=48,w=32,h=24,f=0,l=false},
{i=4,n="living",x=96,y=48,w=32,h=24,f=0,l=false},
{i=5,n="attic",x=32,y=24,w=64,h=24,f=0,l=false,c=true}}
ts={"pot","putty","wrench","rag","plank"}
ct,tct,lt=1,0,0
tci,li,am=180,300,1
fr,mf=0.1,20

function _init()
 sl()
end

function _update60()
 if gs=="playing" then ug()
 elseif gs=="gameover" then ugo() end
end

function ug()
 t+=1
 sc=flr(t/60)
 tct+=1
 lt+=1
 if ft>0 then ft-=1 end
 
 if tct>=tci then
  ct=(ct%#ts)+1
  tct=0
 end
 
 if lt>=li then
  sl()
  lt=0
  li=max(120,li-5)
 end
 
 up()
 uf()
 cgo()
end

function up()
 if btn(0) then p.x-=1 end
 if btn(1) then p.x+=1 end
 if btn(2) then p.y-=1 end
 if btn(3) then p.y+=1 end
 
 p.x=mid(0,p.x,120)
 p.y=mid(0,p.y,120)
 
 upr()
 
 if btnp(4) then int() end
end

function upr()
 for i,r in pairs(rs) do
  if p.x>=r.x and p.x<r.x+r.w and p.y>=r.y and p.y<r.y+r.h then
   p.r=r.i
   break
  end
 end
end

function int()
 local r=rs[p.r]
 
 if r.n=="kitchen" and not p.i then
  p.i=ts[ct]
  fm="picked up "..p.i
  ft=120
  sfx(0)
 elseif r.l and p.i then
  if cfl(r,p.i) then
   fl(r,p.i)
   fm="leak fixed!"
   ft=120
   p.i=nil
   sfx(1)
  else
   fm="wrong tool! need: "..gct(r)
   ft=180
   sfx(2)
  end
 end
end

function cfl(r,t)
 if r.n=="bedroom" then return t=="pot" or t=="rag"
 elseif r.n=="bathroom" then return t=="wrench" or t=="putty"
 elseif r.n=="living" then return t=="plank" or t=="putty"
 elseif r.n=="attic" then return t=="wrench" or t=="putty" end
 return false
end

function gct(r)
 if r.n=="bedroom" then return "pot/rag"
 elseif r.n=="bathroom" then return "wrench/putty"
 elseif r.n=="living" then return "plank/putty"
 elseif r.n=="attic" then return "wrench/putty" end
 return "unknown"
end

function fl(r,t)
 r.l=false
 r.f=max(0,r.f-5)
 if r.n=="attic" then am=1 end
 sc+=10
end

function sl()
 local ar={}
 for i,r in pairs(rs) do
  if not r.l and r.f<mf then add(ar,r) end
 end
 
 if #ar>0 then
  local r=ar[flr(rnd(#ar))+1]
  r.l=true
  if r.n=="attic" then am=2 end
 end
end

function uf()
 for i,r in pairs(rs) do
  if r.l then
   r.f+=fr*am
   r.f=min(r.f,mf)
  end
 end
end

function cgo()
 local fc=0
 for i,r in pairs(rs) do
  if r.n!="attic" and r.f>=mf then fc+=1 end
 end
 if fc>=4 then gs="gameover" end
end

function ugo()
 if btnp(4) then
  _init()
  gs="playing"
 end
end

function _draw()
 cls()
 if gs=="playing" then dg()
 elseif gs=="gameover" then dgo() end
end

function dg()
 dh()
 dl()
 df()
 spr(p.s,p.x,p.y)
 dhud()
end

function dh()
 rect(0,24,127,95,7)
 line(32,24,32,95,7)
 line(64,24,64,95,7)
 line(96,24,96,95,7)
 line(0,48,127,48,7)
 line(32,24,96,24,7)
 
 print("kit",4,50,6)
 print("bed",36,50,6)
 print("bath",66,50,6)
 print("live",100,50,6)
 print("attic",48,28,6)
 
 print("tool:",4,76,7)
 print(ts[ct],4,82,11)
end

function dl()
 for i,r in pairs(rs) do
  if r.l then
   circfill(r.x+r.w/2,r.y+4,2,12)
   if r.n=="attic" and t%30<15 then
    print("!",r.x+r.w/2-2,r.y+10,8)
   end
  end
 end
end

function df()
 for i,r in pairs(rs) do
  if r.f>0 then
   local fh=flr(r.f)
   rectfill(r.x,r.y+r.h-fh,r.x+r.w,r.y+r.h,1)
  end
 end
end

function dhud()
 print("score: "..sc,2,2,7)
 
 if p.i then
  print("item: "..p.i,2,8,11)
 end
 
 if ft>0 then
  local c=11
  if sub(fm,1,5)=="wrong" then c=8
  elseif sub(fm,1,4)=="leak" then c=11 end
  print(fm,2,14,c)
 end
 
 if rs[5].l then
  print("attic leak!",80,2,8)
 end
 
 for i,r in pairs(rs) do
  if r.n!="attic" then
   local bx=2+(i-1)*20
   local by=120
   rect(bx,by,bx+16,by+4,7)
   if r.f>0 then
    local fw=flr((r.f/mf)*16)
    rectfill(bx,by,bx+fw,by+4,8)
   end
  end
 end
end

function dgo()
 print("game over!",40,50,8)
 print("final score: "..sc,35,60,7)
 print("press x to restart",25,70,6)
end

__gfx__
00000000777777777000000070000000700000007000000070000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777777700007077000700770007007700070077000700000000000000000000000000000000000000000000000000000000000000000000000000
00700700777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000
00077000777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000
00077000777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000
00700700777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
001000000c0500e0500f0501005012050140501505016050180501a0501b0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c050
001000001005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005
00100000060500a0500e0501105013050140501505016050170501805019050190501905019050190501905019050190501905019050190501905019050190501905019050190501905019050190501905