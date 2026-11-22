-- zmbots HUD: shows the text that zm_bots_hud.gsc writes to dvar zb_hudtxt, one line per "|" piece, top-left.
-- GSC hud elems do not show in BO7, so this uses the same native LUI technique as FuzMenu's zm_splitter_post.lua
-- (dvar read by Dvar.GetDvarString, UIStyledText labels, a hidden element with Wait(16) as timer).
local LINES=8
local X,Y,W,ROWH,SIZE=24,470,1000,22,17

local C=rawget(_G,"CLUA")
local H=rawget(_G,"xhash") or rawget(_G,"PushXHash") or (type(C)=="table" and C.PushXHash)
local HD=rawget(_G,"xhashdvar") or rawget(_G,"PushXHashDvar") or (type(C)=="table" and C.PushXHashDvar)
if type(H)~="function" or type(HD)~="function" then return end
local old=rawget(_G,"ZmBotsHud")
if old then old.enabled=false;if old.clear then pcall(old.clear) end end
local S={enabled=true,text={}}
rawset(_G,"ZmBotsHud",S)

local function get(object,key)
    if object==nil then return nil end
    local plain,value=pcall(function()return object[key]end)
    if plain and value~=nil then return value end
    local ok,hashed=pcall(function()return object[H(key)]end)
    if ok then return hashed end
end
local function invoke(object,key,...)
    local f=get(object,key)
    if type(f)=="function" then return f(...) end
end
local function call(object,key,...)
    local f=get(object,key)
    if type(f)=="function" then return f(object,...) end
end
local function read(name)
    local v=invoke(rawget(_G,"Dvar"),"GetDvarString",HD(name))
    if v~=nil then return tostring(v) end
end
local function inMatch() return invoke(rawget(_G,"Engine"),"InFrontend")==false end
local function newElement(kind) return get(get(rawget(_G,"LUI"),kind),"new")() end
local function passive(e) call(e,"SetHandleMouse",false);call(e,"setFocusable",false) end

local function displayParent()
    local root=invoke(get(rawget(_G,"LUI"),"UIRoot"),"GetRootForControllerIndex",0)
    if type(get(root,"addElement"))~="function" then return nil end
    for _=1,16 do
        local p=call(root,"getParent")
        if not p or p==root then break end
        root=p
    end
    return root
end

local function label(parent,i,rgb,dx)
    local e=newElement("UIStyledText")
    call(e,"SetAnchorsAndPosition",0,1,0,1,X+dx,X+W+dx,Y+i*ROWH+dx,Y+(i+1)*ROWH+dx)
    local fonts=rawget(_G,"FONT_HANDLE")
    local font=get(fonts,"PrimaryBold") or get(fonts,"PrimaryRegular")
    if font then call(e,"SetFont",font) end
    call(e,"SetFontSize",SIZE*(tonumber(rawget(_G,"_PT")) or 1))
    call(e,"SetRGB",rgb);call(e,"SetAlignment",0)
    passive(e);call(parent,"addElement",e)
    return e
end

local function clear()
    if S.frame then pcall(call,S.frame,"closeTree") end
    S.frame=nil;S.parent=nil;S.rows=nil;S.text={}
end
S.clear=clear

local function build(parent)
    clear()
    local frame=newElement("UIElement")
    call(frame,"setPriority",1000);passive(frame);call(parent,"addElement",frame)
    call(frame,"SetAnchorsAndPosition",0,0,0,0,0,0,0,0)
    S.frame=frame;S.parent=parent;S.rows={}
    for i=0,LINES-1 do
        local shadow=label(frame,i,0x000000,1.5)
        S.rows[i+1]={shadow,label(frame,i,i==0 and 0x99d9ff or 0xffffff,0)}
    end
end

local function tick()
    local txt=read("zb_hudtxt") or ""
    local parent=displayParent()
    if txt=="" or not parent then
        if S.frame then clear() end
        return
    end
    if not S.frame or S.parent~=parent then build(parent) end
    local i=0
    for piece in (txt.."|"):gmatch("([^|]*)|") do
        i=i+1
        if i>LINES then break end
        if S.text[i]~=piece then
            for _,e in ipairs(S.rows[i]) do call(e,"setText",piece) end
            S.text[i]=piece
        end
    end
    for j=i+1,LINES do
        if S.text[j]~="" then
            for _,e in ipairs(S.rows[j]) do call(e,"setText","") end
            S.text[j]=""
        end
    end
end

-- same timer as zm_splitter_post.lua: hidden element, Wait(16), re-armed on complete
local function timerRoot()
    local L=rawget(_G,"LUI")
    local ok,cur=pcall(invoke,L,"GetRoot")
    if ok and cur then return cur end
    return get(L,"primaryRoot")
end
local function ensureTimer()
    if not S.enabled then return end
    if not inMatch() then
        if S.host then pcall(call,S.host,"closeTree");S.host=nil end
        clear()
        return
    end
    local root=timerRoot()
    if not root then return end
    local okP,p=pcall(call,S.host,"getParent")
    if okP and p==root then return end
    if S.host then pcall(call,S.host,"closeTree") end
    S.host=nil
    pcall(function()
        local host=newElement("UIElement")
        passive(host);call(root,"addElement",host);S.host=host
        local count=0
        local function schedule()
            if not S.enabled or S.host~=host then return end
            local anim=call(host,"Wait",16)
            if not anim then S.host=nil;return end
            anim.onComplete=function()
                if not S.enabled or S.host~=host then return end
                count=count+1
                -- the dvar changes at most every 0.5 s on the GSC side; reading it every 6th frame is enough
                if count%6==0 and not pcall(tick) then clear() end
                if not inMatch() then
                    pcall(call,host,"closeTree")
                    if S.host==host then S.host=nil end
                    clear()
                    return
                end
                pcall(schedule)
            end
        end
        schedule()
    end)
end

-- the timer starts on the first input in a match, like the splitter (the file loads in the main menu)
local installed=setmetatable({},{__mode="k"})
local function install()
    local input=get(rawget(_G,"LUI"),"UIRoot")
    local original=get(input,"QueueInput")
    if type(original)~="function" or installed[input] then return end
    local wrapped=function(...)
        if S.enabled then pcall(ensureTimer) end
        return original(...)
    end
    installed[input]=true
    input.QueueInput=wrapped;input[H("QueueInput")]=wrapped
end
pcall(ensureTimer)
pcall(install)
