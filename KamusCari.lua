--[[
	KamusCari.lua
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	Versi pencarian murni — tanpa auto jawab & delay
	Fitur:
	  ✦ Cari Awalan, Akhiran, Awalan+Akhiran, Pola wildcard
	  ✦ Filter kata panjang (6+ huruf)
	  ✦ UI bisa di-drag, di-resize, dan di-minimize
	  ✦ Hasil scroll panjang

	CARA PAKAI:
	loadstring(game:HttpGet("https://raw.githubusercontent.com/USERNAME/REPO/main/KamusCari.lua"))()
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

-- ═══════════════════════════════════════════════════
-- KONFIGURASI
-- ═══════════════════════════════════════════════════

local URL_JSON = "https://cdn.jsdelivr.net/gh/voixderen/kamus-roblox@main/kamus_kata.json"

-- Ukuran awal panel
local PANEL_W   = 420
local PANEL_H   = 560
local PANEL_MIN_W = 300
local PANEL_MIN_H = 300

-- ═══════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════

local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Mouse       = LocalPlayer:GetMouse()

-- ═══════════════════════════════════════════════════
-- STATE KAMUS
-- ═══════════════════════════════════════════════════

local _kata      = {}
local _indexKeys = {}
local filterPanjang = false
local PANJANG_MIN   = 6

-- ═══════════════════════════════════════════════════
-- HTTP — KOMPATIBEL EXECUTOR
-- ═══════════════════════════════════════════════════

local function ExecRequest(url)
	local headers = {
		["User-Agent"]    = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
		["Accept"]        = "application/octet-stream, text/plain, */*",
		["Cache-Control"] = "no-cache",
	}
	if type(request) == "function" then
		local ok, res = pcall(request, {Url=url, Method="GET", Headers=headers})
		if ok and res and res.StatusCode == 200 then return true, res.Body end
		return false, ok and ("HTTP "..tostring(res and res.StatusCode)) or tostring(res)
	elseif type(syn)=="table" and type(syn.request)=="function" then
		local ok, res = pcall(syn.request, {Url=url, Method="GET", Headers=headers})
		if ok and res and res.StatusCode==200 then return true, res.Body end
		return false, tostring(res)
	elseif type(http)=="table" and type(http.request)=="function" then
		local ok, res = pcall(http.request, {Url=url, Method="GET", Headers=headers})
		if ok and res and res.StatusCode==200 then return true, res.Body end
		return false, tostring(res)
	else
		local ok, res = pcall(function() return HttpService:GetAsync(url,true) end)
		return ok and true or false, ok and res or tostring(res)
	end
end

-- ═══════════════════════════════════════════════════
-- PARSE & MUAT KAMUS
-- ═══════════════════════════════════════════════════

local function MuatKata(tabel)
	_kata = {}; _indexKeys = {}
	for _, k in ipairs(tabel) do
		local w = tostring(k):lower():gsub("%s+","")
		if w ~= "" and not _kata[w] then
			_kata[w] = true
			table.insert(_indexKeys, w)
		end
	end
	table.sort(_indexKeys)
end

local function ParseDanMuat(jsonStr)
	local ok, data = pcall(function() return HttpService:JSONDecode(jsonStr) end)
	if not ok then return false, "Gagal parse JSON" end
	local tabel = {}
	if type(data)=="table" and data.dictionary then
		for _, item in ipairs(data.dictionary) do
			if item.word then table.insert(tabel, tostring(item.word):gsub("%s+$","")) end
		end
	elseif type(data)=="table" and type(data[1])=="string" then
		tabel = data
	elseif type(data)=="table" then
		for k in pairs(data) do table.insert(tabel, k) end
	end
	if #tabel==0 then return false, "Tidak ada kata ditemukan" end
	MuatKata(tabel)
	return true, #_indexKeys.." kata dimuat"
end

-- ═══════════════════════════════════════════════════
-- PENCARIAN
-- ═══════════════════════════════════════════════════

local WILD = {["-"]=true,["_"]=true,["?"]=true}

local function CocokPola(kata, pola)
	if #kata ~= #pola then return false end
	for i = 1, #pola do
		local cp = pola:sub(i,i)
		if not WILD[cp] and cp ~= kata:sub(i,i) then return false end
	end
	return true
end

local function filterKata(k)
	-- MATI  → tampilkan kata pendek saja (≤6 huruf)
	-- NYALA → tampilkan kata panjang saja (>6 huruf)
	if filterPanjang then
		return #k > PANJANG_MIN      -- nyala: hanya >6 huruf
	else
		return #k <= PANJANG_MIN     -- mati: hanya ≤6 huruf
	end
end

local function Cari(mode, q1, q2)
	q1 = (q1 or ""):lower():gsub("%s+","")
	q2 = (q2 or ""):lower():gsub("%s+","")
	local hasil = {}

	local MAKS = 300  -- batas pencarian, lebih dari pool untuk pagination
	if mode == "mengandung" then
		for _, k in ipairs(_indexKeys) do
			if filterKata(k) and k:find(q1, 1, true) then
				table.insert(hasil, k)
				if #hasil >= MAKS then break end
			end
		end
	elseif mode == "awalan" then
		for _, k in ipairs(_indexKeys) do
			if filterKata(k) and k:sub(1,#q1)==q1 then
				table.insert(hasil, k)
				if #hasil >= MAKS then break end
			end
		end
	elseif mode == "akhiran" then
		for _, k in ipairs(_indexKeys) do
			if filterKata(k) and #k>=#q1 and k:sub(-#q1)==q1 then
				table.insert(hasil, k)
				if #hasil >= MAKS then break end
			end
		end
	elseif mode == "kombinasi" then
		for _, k in ipairs(_indexKeys) do
			if filterKata(k) then
				local okA = q1=="" or k:sub(1,#q1)==q1
				local okB = q2=="" or (#k>=#q2 and k:sub(-#q2)==q2)
				if okA and okB then
					table.insert(hasil, k)
					if #hasil >= MAKS then break end
				end
			end
		end
	end

	return hasil
end

-- ═══════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════

local function BuatUI()
	if PlayerGui:FindFirstChild("KamusCariUI") then
		PlayerGui.KamusCariUI:Destroy()
	end

	-- ── ScreenGui ──
	local GUI = Instance.new("ScreenGui")
	GUI.Name           = "KamusCariUI"
	GUI.ResetOnSpawn   = false
	GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	GUI.Parent         = PlayerGui

	-- ── Panel utama ──
	local Panel = Instance.new("Frame")
	Panel.Name             = "Panel"
	Panel.Size             = UDim2.new(0, PANEL_W, 0, PANEL_H)
	Panel.Position         = UDim2.new(0, 20, 0.5, -(PANEL_H/2))
	Panel.BackgroundColor3 = Color3.fromRGB(15, 14, 12)
	Panel.BorderSizePixel  = 0
	Panel.ClipsDescendants = true
	Panel.Parent           = GUI
	Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 6)
	local PanelStroke = Instance.new("UIStroke", Panel)
	PanelStroke.Color = Color3.fromRGB(46, 43, 36); PanelStroke.Thickness = 1

	-- Garis emas atas
	local GarisEmas = Instance.new("Frame", Panel)
	GarisEmas.Size             = UDim2.new(1, 0, 0, 2)
	GarisEmas.BackgroundColor3 = Color3.fromRGB(201, 168, 76)
	GarisEmas.BorderSizePixel  = 0

	-- ── HEADER (drag area) ──
	local Header = Instance.new("Frame", Panel)
	Header.Name             = "Header"
	Header.Size             = UDim2.new(1, 0, 0, 38)
	Header.Position         = UDim2.new(0, 0, 0, 2)
	Header.BackgroundColor3 = Color3.fromRGB(22, 20, 17)
	Header.BorderSizePixel  = 0
	Header.Active           = true

	local Judul = Instance.new("TextLabel", Header)
	Judul.Size              = UDim2.new(1, -90, 1, 0)
	Judul.Position          = UDim2.new(0, 12, 0, 0)
	Judul.BackgroundTransparency = 1
	Judul.Text              = "⌕  KAMUS PENCARIAN"
	Judul.TextColor3        = Color3.fromRGB(201, 168, 76)
	Judul.Font              = Enum.Font.GothamBold
	Judul.TextSize          = 11
	Judul.TextXAlignment    = Enum.TextXAlignment.Left

	-- Tombol minimize
	local BtnMin = Instance.new("TextButton", Header)
	BtnMin.Size             = UDim2.new(0, 26, 0, 26)
	BtnMin.Position         = UDim2.new(1, -60, 0, 6)
	BtnMin.BackgroundColor3 = Color3.fromRGB(60, 55, 40)
	BtnMin.BorderSizePixel  = 0
	BtnMin.Text             = "─"
	BtnMin.TextColor3       = Color3.fromRGB(201, 168, 76)
	BtnMin.Font             = Enum.Font.GothamBold
	BtnMin.TextSize         = 12
	Instance.new("UICorner", BtnMin).CornerRadius = UDim.new(0, 3)

	-- Tombol tutup
	local BtnX = Instance.new("TextButton", Header)
	BtnX.Size             = UDim2.new(0, 26, 0, 26)
	BtnX.Position         = UDim2.new(1, -30, 0, 6)
	BtnX.BackgroundColor3 = Color3.fromRGB(120, 50, 50)
	BtnX.BorderSizePixel  = 0
	BtnX.Text             = "✕"
	BtnX.TextColor3       = Color3.fromRGB(255, 255, 255)
	BtnX.Font             = Enum.Font.GothamBold
	BtnX.TextSize         = 11
	Instance.new("UICorner", BtnX).CornerRadius = UDim.new(0, 3)

	-- ── BODY (konten) ──
	local Body = Instance.new("Frame", Panel)
	Body.Name             = "Body"
	Body.Size             = UDim2.new(1, 0, 1, -40)
	Body.Position         = UDim2.new(0, 0, 0, 40)
	Body.BackgroundTransparency = 1
	Body.ClipsDescendants = true

	local Pad = Instance.new("UIPadding", Body)
	Pad.PaddingLeft  = UDim.new(0, 10)
	Pad.PaddingRight = UDim.new(0, 10)
	Pad.PaddingTop   = UDim.new(0, 8)
	Pad.PaddingBottom = UDim.new(0, 8)

	local BodyList = Instance.new("UIListLayout", Body)
	BodyList.SortOrder = Enum.SortOrder.LayoutOrder
	BodyList.Padding   = UDim.new(0, 6)

	-- Helper
	local function Label(teks, order, parent)
		local l = Instance.new("TextLabel", parent or Body)
		l.Size              = UDim2.new(1, 0, 0, 13)
		l.BackgroundTransparency = 1
		l.Text              = teks
		l.TextColor3        = Color3.fromRGB(100, 95, 85)
		l.Font              = Enum.Font.Gotham
		l.TextSize          = 9
		l.TextXAlignment    = Enum.TextXAlignment.Left
		l.LayoutOrder       = order
		return l
	end

	local function Input(placeholder, order, parent)
		local box = Instance.new("TextBox", parent or Body)
		box.Size              = UDim2.new(1, 0, 0, 30)
		box.BackgroundColor3  = Color3.fromRGB(26, 24, 20)
		box.BorderSizePixel   = 0
		box.PlaceholderText   = placeholder
		box.PlaceholderColor3 = Color3.fromRGB(75, 70, 60)
		box.Text              = ""
		box.TextColor3        = Color3.fromRGB(232, 224, 208)
		box.Font              = Enum.Font.Gotham
		box.TextSize          = 12
		box.ClearTextOnFocus  = false
		box.LayoutOrder       = order
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
		local s = Instance.new("UIStroke", box); s.Color = Color3.fromRGB(46,43,36)
		local p = Instance.new("UIPadding", box); p.PaddingLeft = UDim.new(0,9)
		return box
	end

	local function Toggle(teks, order)
		local btn = Instance.new("TextButton", Body)
		btn.Size             = UDim2.new(1, 0, 0, 26)
		btn.BackgroundColor3 = Color3.fromRGB(26, 24, 20)
		btn.BorderSizePixel  = 0
		btn.Text             = "○  " .. teks .. " : MATI"
		btn.TextColor3       = Color3.fromRGB(100, 95, 85)
		btn.Font             = Enum.Font.Gotham
		btn.TextSize         = 10
		btn.LayoutOrder      = order
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
		local s = Instance.new("UIStroke", btn); s.Color = Color3.fromRGB(46,43,36)
		local aktif = false
		btn.MouseButton1Click:Connect(function()
			aktif = not aktif
			btn.Text      = (aktif and "●  " or "○  ") .. teks .. (aktif and " : NYALA" or " : MATI")
			btn.TextColor3 = aktif and Color3.fromRGB(201,168,76) or Color3.fromRGB(100,95,85)
			s.Color        = aktif and Color3.fromRGB(201,168,76) or Color3.fromRGB(46,43,36)
		end)
		return btn, function() return aktif end
	end

	-- ── STATUS KAMUS ──
	local StatusKamus = Instance.new("TextLabel", Body)
	StatusKamus.Size              = UDim2.new(1, 0, 0, 22)
	StatusKamus.BackgroundColor3  = Color3.fromRGB(22, 20, 17)
	StatusKamus.BorderSizePixel   = 0
	StatusKamus.Text              = "⟳  Memuat kamus..."
	StatusKamus.TextColor3        = Color3.fromRGB(201, 168, 76)
	StatusKamus.Font              = Enum.Font.Gotham
	StatusKamus.TextSize          = 10
	StatusKamus.LayoutOrder       = 0
	Instance.new("UICorner", StatusKamus).CornerRadius = UDim.new(0, 3)
	local PadSK = Instance.new("UIPadding", StatusKamus)
	PadSK.PaddingLeft = UDim.new(0, 8)

	-- ── MODE TABS ──
	-- 4 tab: Mengandung, Awalan, Akhiran, Awal+Akhiran
	-- Mengandung/Awalan/Akhiran → 1 input utama
	-- Awal+Akhiran → 2 input berdampingan (seperti HTML)

	local modeAktif = "mengandung"

	local TabFrame = Instance.new("Frame", Body)
	TabFrame.Size             = UDim2.new(1, 0, 0, 28)
	TabFrame.BackgroundTransparency = 1
	TabFrame.LayoutOrder      = 1
	local TabList = Instance.new("UIListLayout", TabFrame)
	TabList.FillDirection = Enum.FillDirection.Horizontal
	TabList.Padding       = UDim.new(0, 4)

	local tabs = {}

	local function BuatTab(label, mode, lebar)
		local btn = Instance.new("TextButton", TabFrame)
		btn.Size             = UDim2.new(lebar or 0.24, -3, 1, 0)
		btn.BackgroundColor3 = Color3.fromRGB(26, 24, 20)
		btn.BorderSizePixel  = 0
		btn.Text             = label
		btn.TextColor3       = Color3.fromRGB(100, 95, 85)
		btn.Font             = Enum.Font.Gotham
		btn.TextSize         = 9
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
		local s = Instance.new("UIStroke", btn); s.Color = Color3.fromRGB(46,43,36)
		tabs[mode] = {btn=btn, stroke=s}
		return btn
	end

	BuatTab("Mengandung",   "mengandung",  0.26)
	BuatTab("Awalan",       "awalan",      0.22)
	BuatTab("Akhiran",      "akhiran",     0.22)
	BuatTab("Awal+Akhir",  "kombinasi",   0.26)

	local function SetTabAktif(mode)
		modeAktif = mode
		for m, t in pairs(tabs) do
			local aktif = m == mode
			t.btn.BackgroundColor3 = aktif and Color3.fromRGB(40,36,24) or Color3.fromRGB(26,24,20)
			t.btn.TextColor3       = aktif and Color3.fromRGB(201,168,76) or Color3.fromRGB(100,95,85)
			t.stroke.Color         = aktif and Color3.fromRGB(201,168,76) or Color3.fromRGB(46,43,36)
		end
	end
	SetTabAktif("mengandung")

	-- ── INPUT AREA ──
	-- Input tunggal (Mengandung / Awalan / Akhiran)
	Label("KATA PENCARIAN", 2)
	local InQ1 = Input("Ketik kata yang mengandung huruf...", 3)

	-- Panel Awal+Akhir (2 kolom, hidden by default)
	local KomboFrame = Instance.new("Frame", Body)
	KomboFrame.Size             = UDim2.new(1, 0, 0, 30)
	KomboFrame.BackgroundTransparency = 1
	KomboFrame.LayoutOrder      = 4
	KomboFrame.Visible          = false
	local KomboList = Instance.new("UIListLayout", KomboFrame)
	KomboList.FillDirection = Enum.FillDirection.Horizontal
	KomboList.Padding       = UDim.new(0, 5)

	-- Input Awalan (kombo)
	local InKomboA = Instance.new("TextBox", KomboFrame)
	InKomboA.Size              = UDim2.new(0.46, 0, 1, 0)
	InKomboA.BackgroundColor3  = Color3.fromRGB(26, 24, 20)
	InKomboA.BorderSizePixel   = 0
	InKomboA.PlaceholderText   = "Awalan...  cth: me"
	InKomboA.PlaceholderColor3 = Color3.fromRGB(75, 70, 60)
	InKomboA.Text              = ""
	InKomboA.TextColor3        = Color3.fromRGB(232, 224, 208)
	InKomboA.Font              = Enum.Font.Gotham
	InKomboA.TextSize          = 11
	InKomboA.ClearTextOnFocus  = false
	Instance.new("UICorner", InKomboA).CornerRadius = UDim.new(0, 4)
	local sA = Instance.new("UIStroke", InKomboA); sA.Color = Color3.fromRGB(46,43,36)
	local pA = Instance.new("UIPadding", InKomboA); pA.PaddingLeft = UDim.new(0,8)

	-- Separator +
	local SepLabel = Instance.new("TextLabel", KomboFrame)
	SepLabel.Size              = UDim2.new(0, 14, 1, 0)
	SepLabel.BackgroundTransparency = 1
	SepLabel.Text              = "+"
	SepLabel.TextColor3        = Color3.fromRGB(201, 168, 76)
	SepLabel.Font              = Enum.Font.GothamBold
	SepLabel.TextSize          = 14

	-- Input Akhiran (kombo)
	local InKomboB = Instance.new("TextBox", KomboFrame)
	InKomboB.Size              = UDim2.new(0.46, 0, 1, 0)
	InKomboB.BackgroundColor3  = Color3.fromRGB(26, 24, 20)
	InKomboB.BorderSizePixel   = 0
	InKomboB.PlaceholderText   = "Akhiran...  cth: kan"
	InKomboB.PlaceholderColor3 = Color3.fromRGB(75, 70, 60)
	InKomboB.Text              = ""
	InKomboB.TextColor3        = Color3.fromRGB(232, 224, 208)
	InKomboB.Font              = Enum.Font.Gotham
	InKomboB.TextSize          = 11
	InKomboB.ClearTextOnFocus  = false
	Instance.new("UICorner", InKomboB).CornerRadius = UDim.new(0, 4)
	local sB = Instance.new("UIStroke", InKomboB); sB.Color = Color3.fromRGB(46,43,36)
	local pB = Instance.new("UIPadding", InKomboB); pB.PaddingLeft = UDim.new(0,8)

	-- Update tampilan & placeholder saat ganti tab
	local function UpdateInput()
		local isKombo = modeAktif == "kombinasi"
		InQ1.Visible    = not isKombo
		KomboFrame.Visible = isKombo
		if modeAktif == "mengandung" then
			InQ1.PlaceholderText = "Ketik huruf yang terkandung...  cth: am, exi"
		elseif modeAktif == "awalan" then
			InQ1.PlaceholderText = "Ketik awalan kata...  cth: me, ber, per"
		elseif modeAktif == "akhiran" then
			InQ1.PlaceholderText = "Ketik akhiran kata...  cth: kan, an, i"
		end
		-- reset hasil saat ganti tab
		RenderHasil({})
		LabelHasil.Text = "HASIL — ketik untuk mencari"
	end

	for mode, t in pairs(tabs) do
		t.btn.MouseButton1Click:Connect(function()
			SetTabAktif(mode)
			UpdateInput()
		end)
	end

	-- Forward declaration agar BtnPanjang bisa panggil DoSearch
	local debounce
	local DoSearch

	-- ── FILTER KATA PANJANG ──
	-- MATI  = kata ≤6 huruf saja
	-- NYALA = kata >6 huruf saja
	local BtnPanjang = Instance.new("TextButton", Body)
	BtnPanjang.Size             = UDim2.new(1, 0, 0, 26)
	BtnPanjang.BackgroundColor3 = Color3.fromRGB(26, 24, 20)
	BtnPanjang.BorderSizePixel  = 0
	BtnPanjang.Text             = "○  Kata Panjang (>6 huruf) : MATI — tampil ≤6 huruf"
	BtnPanjang.TextColor3       = Color3.fromRGB(100, 95, 85)
	BtnPanjang.Font             = Enum.Font.Gotham
	BtnPanjang.TextSize         = 9
	BtnPanjang.LayoutOrder      = 6
	Instance.new("UICorner", BtnPanjang).CornerRadius = UDim.new(0, 4)
	local BtnPanjangStroke = Instance.new("UIStroke", BtnPanjang)
	BtnPanjangStroke.Color = Color3.fromRGB(46, 43, 36)

	BtnPanjang.MouseButton1Click:Connect(function()
		filterPanjang = not filterPanjang
		if filterPanjang then
			BtnPanjang.Text        = "●  Kata Panjang (>6 huruf) : NYALA — tampil >6 huruf"
			BtnPanjang.TextColor3  = Color3.fromRGB(201, 168, 76)
			BtnPanjangStroke.Color = Color3.fromRGB(201, 168, 76)
		else
			BtnPanjang.Text        = "○  Kata Panjang (>6 huruf) : MATI — tampil ≤6 huruf"
			BtnPanjang.TextColor3  = Color3.fromRGB(100, 95, 85)
			BtnPanjangStroke.Color = Color3.fromRGB(46, 43, 36)
		end
		-- Langsung jalankan ulang pencarian dengan filter baru
		if debounce then task.cancel(debounce) end
		debounce = task.delay(0.05, DoSearch)
	end)

	-- ── JUMLAH HASIL ──
	local LabelHasil = Label("HASIL — 0 kata ditemukan", 7)
	LabelHasil.TextColor3 = Color3.fromRGB(120, 113, 100)

	-- ── SCROLL FRAME HASIL ──
	local ScrollFrame = Instance.new("ScrollingFrame", Body)
	ScrollFrame.Name              = "ScrollFrame"
	ScrollFrame.Size              = UDim2.new(1, 0, 1, -195)  -- sisanya untuk hasil
	ScrollFrame.BackgroundColor3  = Color3.fromRGB(20, 18, 15)
	ScrollFrame.BorderSizePixel   = 0
	ScrollFrame.ScrollBarThickness = 4
	ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(201, 168, 76)
	ScrollFrame.CanvasSize        = UDim2.new(0, 0, 0, 0)
	ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	ScrollFrame.LayoutOrder       = 8
	Instance.new("UICorner", ScrollFrame).CornerRadius = UDim.new(0, 4)

	local ScrollList = Instance.new("UIListLayout", ScrollFrame)
	ScrollList.SortOrder  = Enum.SortOrder.LayoutOrder
	ScrollList.Padding    = UDim.new(0, 1)

	local ScrollPad = Instance.new("UIPadding", ScrollFrame)
	ScrollPad.PaddingLeft   = UDim.new(0, 6)
	ScrollPad.PaddingRight  = UDim.new(0, 6)
	ScrollPad.PaddingTop    = UDim.new(0, 4)
	ScrollPad.PaddingBottom = UDim.new(0, 4)

	-- Fungsi render hasil
	-- ── OBJECT POOL + PAGINATION ──
	-- Tampil 50 kata dulu, +20 tiap klik "Tampilkan Lebih Banyak"
	local TAMPIL_AWAL  = 50    -- kata ditampilkan pertama kali
	local TAMPIL_LEBIH = 20    -- kata tambahan tiap klik
	local POOL_SIZE    = 150   -- pool = baris maksimal (150×2 = 300 slot)
	local pool         = {}
	local poolCells    = {}
	local _hasilAktif  = {}    -- simpan hasil pencarian terakhir
	local _tampilSampai = TAMPIL_AWAL  -- berapa kata yang sedang ditampilkan

	local function BuatPoolRow(i)
		local row = Instance.new("Frame", ScrollFrame)
		row.Size             = UDim2.new(1, -4, 0, 24)
		row.BackgroundTransparency = 1
		row.LayoutOrder      = i
		row.Visible          = false
		local rl = Instance.new("UIListLayout", row)
		rl.FillDirection = Enum.FillDirection.Horizontal
		rl.Padding       = UDim.new(0, 4)

		poolCells[i] = {}
		for col = 1, 2 do
			local cell = Instance.new("TextButton", row)
			cell.Size             = UDim2.new(0.5, -2, 1, 0)
			cell.BackgroundColor3 = Color3.fromRGB(28, 26, 22)
			cell.BorderSizePixel  = 0
			cell.Font             = Enum.Font.Gotham
			cell.TextSize         = 11
			cell.TextXAlignment   = Enum.TextXAlignment.Left
			cell.Text             = ""
			cell.TextColor3       = Color3.fromRGB(200, 192, 175)
			Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 3)
			local cp = Instance.new("UIPadding", cell)
			cp.PaddingLeft = UDim.new(0, 6)
			-- Hover pakai UIPadding warna — tidak pakai Connect per cell
			-- Gunakan satu highlight sederhana lewat property
			cell.MouseEnter:Connect(function()
				cell.BackgroundColor3 = Color3.fromRGB(38, 34, 26)
				cell.TextColor3       = Color3.fromRGB(201, 168, 76)
			end)
			cell.MouseLeave:Connect(function()
				cell.BackgroundColor3 = Color3.fromRGB(28, 26, 22)
				cell.TextColor3       = Color3.fromRGB(200, 192, 175)
			end)
			poolCells[i][col] = cell
		end
		pool[i] = row
	end

	-- Inisialisasi pool di awal (sekali saja)
	for i = 1, POOL_SIZE do
		BuatPoolRow(i)
	end

	-- Label kosong untuk state "tidak ditemukan"
	local EmptyLabel = Instance.new("TextLabel", ScrollFrame)
	EmptyLabel.Size              = UDim2.new(1, 0, 0, 30)
	EmptyLabel.BackgroundTransparency = 1
	EmptyLabel.Text              = "Tidak ditemukan."
	EmptyLabel.TextColor3        = Color3.fromRGB(120, 60, 60)
	EmptyLabel.Font              = Enum.Font.Gotham
	EmptyLabel.TextSize          = 11
	EmptyLabel.LayoutOrder       = 0
	EmptyLabel.Visible           = false

	-- Tombol "Tampilkan Lebih Banyak" (+20 kata)
	local BtnLebih = Instance.new("TextButton", Body)
	BtnLebih.Size             = UDim2.new(1, 0, 0, 26)
	BtnLebih.BackgroundColor3 = Color3.fromRGB(26, 24, 20)
	BtnLebih.BorderSizePixel  = 0
	BtnLebih.Text             = "+ Tampilkan 20 Kata Lagi"
	BtnLebih.TextColor3       = Color3.fromRGB(201, 168, 76)
	BtnLebih.Font             = Enum.Font.Gotham
	BtnLebih.TextSize         = 10
	BtnLebih.LayoutOrder      = 9
	BtnLebih.Visible          = false
	Instance.new("UICorner", BtnLebih).CornerRadius = UDim.new(0, 4)
	local BtnLebihStroke = Instance.new("UIStroke", BtnLebih)
	BtnLebihStroke.Color = Color3.fromRGB(201, 168, 76)

	BtnLebih.MouseButton1Click:Connect(function()
		_tampilSampai = _tampilSampai + TAMPIL_LEBIH
		RenderSampai(_tampilSampai)
	end)

	-- Render sejumlah 'sampai' kata dari _hasilAktif ke pool
	local function RenderSampai(sampai)
		EmptyLabel.Visible = false
		for i = 1, POOL_SIZE do pool[i].Visible = false end

		local jml    = #_hasilAktif
		local tampil = math.min(sampai, jml)
		local baris  = math.min(math.ceil(tampil / 2), POOL_SIZE)

		-- Update label
		if jml == 0 then
			LabelHasil.Text    = "HASIL — ketik untuk mencari"
			EmptyLabel.Visible = true
			BtnLebih.Visible   = false
			return
		end

		LabelHasil.Text = ("HASIL — %d kata  |  tampil %d"):format(jml, tampil)
		BtnLebih.Visible = tampil < jml   -- tampilkan tombol kalau masih ada sisa

		for i = 1, baris do
			pool[i].Visible = true
			for col = 1, 2 do
				local idx  = (i-1)*2 + col
				local cell = poolCells[i][col]
				if _hasilAktif[idx] then
					cell.Text                   = _hasilAktif[idx]
					cell.BackgroundColor3       = Color3.fromRGB(28, 26, 22)
					cell.TextColor3             = Color3.fromRGB(200, 192, 175)
					cell.BackgroundTransparency = 0
					cell.Active                 = true
				else
					cell.Text                   = ""
					cell.BackgroundTransparency = 1
					cell.Active                 = false
				end
			end
		end
	end

	-- Dipanggil setiap pencarian baru — reset ke 50 kata
	local function RenderHasil(hasil)
		_hasilAktif    = hasil
		_tampilSampai  = TAMPIL_AWAL
		RenderSampai(_tampilSampai)
	end

	-- Fungsi jalankan pencarian
	DoSearch = function()
		local q1, q2 = "", ""

		if modeAktif == "kombinasi" then
			q1 = InKomboA.Text:lower():gsub("%s+","")
			q2 = InKomboB.Text:lower():gsub("%s+","")
			if q1 == "" and q2 == "" then
				RenderHasil({})
				LabelHasil.Text = "HASIL — isi awalan dan/atau akhiran"
				return
			end
		else
			q1 = InQ1.Text:lower():gsub("%s+","")
			if q1 == "" then
				RenderHasil({})
				LabelHasil.Text = "HASIL — ketik untuk mencari"
				return
			end
		end

		local hasil = Cari(modeAktif, q1, q2)
		RenderHasil(hasil)
	end

	-- Listener input utama (Mengandung/Awalan/Akhiran)
	InQ1:GetPropertyChangedSignal("Text"):Connect(function()
		if debounce then task.cancel(debounce) end
		debounce = task.delay(0.15, DoSearch)
	end)
	-- Listener input kombo Awal+Akhir
	InKomboA:GetPropertyChangedSignal("Text"):Connect(function()
		if debounce then task.cancel(debounce) end
		debounce = task.delay(0.15, DoSearch)
	end)
	InKomboB:GetPropertyChangedSignal("Text"):Connect(function()
		if debounce then task.cancel(debounce) end
		debounce = task.delay(0.15, DoSearch)
	end)

	-- ── RESIZE HANDLE (pojok kanan bawah) ──
	local ResizeHandle = Instance.new("TextButton", Panel)
	ResizeHandle.Size             = UDim2.new(0, 16, 0, 16)
	ResizeHandle.Position         = UDim2.new(1, -16, 1, -16)
	ResizeHandle.BackgroundColor3 = Color3.fromRGB(60, 55, 40)
	ResizeHandle.BorderSizePixel  = 0
	ResizeHandle.Text             = "◢"
	ResizeHandle.TextColor3       = Color3.fromRGB(201, 168, 76)
	ResizeHandle.Font             = Enum.Font.Gotham
	ResizeHandle.TextSize         = 12
	ResizeHandle.ZIndex           = 10
	Instance.new("UICorner", ResizeHandle).CornerRadius = UDim.new(0, 3)

	-- ════════════════════════════════════════
	-- DRAG (pindahkan panel lewat header)
	-- ════════════════════════════════════════

	local dragging    = false
	local dragStart   = Vector2.new()
	local startPos    = UDim2.new()

	Header.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging  = true
			dragStart = Vector2.new(inp.Position.X, inp.Position.Y)
			startPos  = Panel.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(inp)
		if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
			Panel.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	-- ════════════════════════════════════════
	-- RESIZE (tarik pojok kanan bawah)
	-- ════════════════════════════════════════

	local resizing     = false
	local resizeStart  = Vector2.new()
	local startSize    = Vector2.new()

	ResizeHandle.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing    = true
			resizeStart = Vector2.new(inp.Position.X, inp.Position.Y)
			startSize   = Vector2.new(Panel.AbsoluteSize.X, Panel.AbsoluteSize.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = false
		end
	end)

	UserInputService.InputChanged:Connect(function(inp)
		if resizing and inp.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = Vector2.new(inp.Position.X, inp.Position.Y) - resizeStart
			local newW  = math.max(PANEL_MIN_W, startSize.X + delta.X)
			local newH  = math.max(PANEL_MIN_H, startSize.Y + delta.Y)
			Panel.Size  = UDim2.new(0, newW, 0, newH)
		end
	end)

	-- ════════════════════════════════════════
	-- MINIMIZE
	-- ════════════════════════════════════════

	local minimized   = false
	local savedHeight = PANEL_H

	BtnMin.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			savedHeight  = Panel.AbsoluteSize.Y
			Panel.Size   = UDim2.new(0, Panel.AbsoluteSize.X, 0, 40)
			Body.Visible = false
			BtnMin.Text  = "□"
		else
			Panel.Size   = UDim2.new(0, Panel.AbsoluteSize.X, 0, savedHeight)
			Body.Visible = true
			BtnMin.Text  = "─"
		end
	end)

	-- ════════════════════════════════════════
	-- TUTUP
	-- ════════════════════════════════════════

	BtnX.MouseButton1Click:Connect(function()
		GUI:Destroy()
	end)

	-- ════════════════════════════════════════
	-- FETCH KAMUS
	-- ════════════════════════════════════════

	task.spawn(function()
		local ok, result = ExecRequest(URL_JSON)
		if not ok then
			StatusKamus.Text      = "✗  Gagal fetch: " .. tostring(result)
			StatusKamus.TextColor3 = Color3.fromRGB(180, 70, 70)
			return
		end
		local berhasil, pesan = ParseDanMuat(result)
		StatusKamus.Text       = berhasil and ("✓  "..pesan) or ("✗  "..pesan)
		StatusKamus.TextColor3 = berhasil
			and Color3.fromRGB(100, 200, 130)
			or  Color3.fromRGB(180, 70, 70)
	end)

	UpdateInput()
end

-- ═══════════════════════════════════════════════════
-- JALANKAN
-- ═══════════════════════════════════════════════════

BuatUI()
print("[KamusCari] UI berhasil dibuat.")
