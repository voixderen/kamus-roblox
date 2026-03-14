--[[
	KamusAutoJawab.lua
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	Script gabungan: KamusModule + UI Auto Jawab
	Fetch kosakata langsung dari file JSON di GitHub

	CARA PAKAI (LocalScript / executor):
	
	loadstring(game:HttpGet("https://raw.githubusercontent.com/voixderen/kamus-roblox/main/KamusAutoJawab.lua"))()

	SETUP JSON DI GITHUB:
	Format JSON yang didukung (pilih salah satu):
	  1. {"dictionary": [{"word": "oli", "arti": "..."}, ...]}   ← format KBBI
	  2. ["oli", "abadi", "operasi", ...]                        ← array kata saja
	  3. {"oli": "artinya...", "abadi": "artinya..."}            ← objek key-value

	Ganti URL_JSON di bawah dengan URL raw GitHub JSON kamu.
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

-- ═══════════════════════════════════════════════════
-- KONFIGURASI — GANTI SESUAI KEBUTUHAN KAMU
-- ═══════════════════════════════════════════════════

local URL_JSON = "https://github.com/voixderen/kamus-roblox/releases/download/Dictionary/dictionary_JSON.json"

-- Path TextBox input jawaban di game kamu
-- Contoh: "PlayerGui.GameUI.InputFrame.AnswerBox"
-- Kosongkan ("") untuk auto-detect TextBox aktif
local PATH_INPUT_BOX = ""

-- ═══════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════

local Players            = game:GetService("Players")
local HttpService        = game:GetService("HttpService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")

local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════

local _kata       = {}   -- { [string] = true }
local _indexKeys  = {}   -- array kata terurut A-Z

local autoAktif      = false
local kecepatanDelay = 1.0
local modePanjang    = false
local kecepatanKetik = 0.07

-- ═══════════════════════════════════════════════════
-- KAMUS — MUAT & PARSE JSON
-- ═══════════════════════════════════════════════════

local function MuatDariTabel(tabel)
	_kata      = {}
	_indexKeys = {}
	for _, k in ipairs(tabel) do
		local w = tostring(k):lower():gsub("%s+", "")
		if w ~= "" and not _kata[w] then
			_kata[w] = true
			table.insert(_indexKeys, w)
		end
	end
	table.sort(_indexKeys)
end

local function ParseJSON(jsonStr)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(jsonStr)
	end)
	if not ok then
		warn("[Kamus] Gagal parse JSON: " .. tostring(data))
		return false
	end

	local tabel = {}

	-- Format 1: {"dictionary": [{word, arti}]}
	if type(data) == "table" and data.dictionary and type(data.dictionary) == "table" then
		for _, item in ipairs(data.dictionary) do
			if item.word then
				table.insert(tabel, tostring(item.word):gsub("%s+$",""))
			end
		end

	-- Format 2: ["oli", "abadi", ...]
	elseif type(data) == "table" and type(data[1]) == "string" then
		for _, w in ipairs(data) do
			table.insert(tabel, w)
		end

	-- Format 3: {"oli": "arti", "abadi": "arti"}
	elseif type(data) == "table" then
		for k, _ in pairs(data) do
			table.insert(tabel, k)
		end
	end

	if #tabel == 0 then
		warn("[Kamus] JSON valid tapi tidak ada kata ditemukan.")
		return false
	end

	MuatDariTabel(tabel)
	print(("[Kamus] %d kata berhasil dimuat dari JSON."):format(#_indexKeys))
	return true
end

local function FetchKamus(url, callback)
	task.spawn(function()
		local ok, result = pcall(function()
			return HttpService:GetAsync(url, true)
		end)
		if not ok then
			warn("[Kamus] Gagal fetch URL: " .. tostring(result))
			callback(false, "Gagal mengambil data dari GitHub.")
			return
		end
		local berhasil = ParseJSON(result)
		callback(berhasil, berhasil and
			("%d kata dimuat."):format(#_indexKeys) or
			"Gagal parse JSON."
		)
	end)
end

-- ═══════════════════════════════════════════════════
-- KAMUS — PENCARIAN
-- ═══════════════════════════════════════════════════

local WILD = {["-"]=true, ["_"]=true, ["?"]=true}

local function CocokPola(kata, pola)
	if #kata ~= #pola then return false end
	for i = 1, #pola do
		local cp = pola:sub(i,i)
		if not WILD[cp] and cp ~= kata:sub(i,i) then
			return false
		end
	end
	return true
end

local function CariPola(pola, maks)
	pola = pola:lower():gsub("%s+","")
	maks = maks or 50
	local r = {}
	for _, k in ipairs(_indexKeys) do
		if CocokPola(k, pola) then
			table.insert(r, k)
			if #r >= maks then break end
		end
	end
	return r
end

local function CariAwalan(awalan, maks)
	awalan = awalan:lower():gsub("%s+","")
	maks   = maks or 50
	local r = {}
	for _, k in ipairs(_indexKeys) do
		if k:sub(1, #awalan) == awalan then
			table.insert(r, k)
			if #r >= maks then break end
		end
	end
	return r
end

local function CariAkhiran(akhiran, maks)
	akhiran = akhiran:lower():gsub("%s+","")
	maks    = maks or 50
	local r = {}
	for _, k in ipairs(_indexKeys) do
		if #k >= #akhiran and k:sub(-#akhiran) == akhiran then
			table.insert(r, k)
			if #r >= maks then break end
		end
	end
	return r
end

local function CariKombinasi(awalan, akhiran, maks)
	awalan  = awalan:lower():gsub("%s+","")
	akhiran = akhiran:lower():gsub("%s+","")
	maks    = maks or 50
	local r = {}
	for _, k in ipairs(_indexKeys) do
		local okA = awalan  == "" or k:sub(1, #awalan)  == awalan
		local okB = akhiran == "" or (#k >= #akhiran and k:sub(-#akhiran) == akhiran)
		if okA and okB then
			table.insert(r, k)
			if #r >= maks then break end
		end
	end
	return r
end

local function CariMengandung(sub, maks)
	sub  = sub:lower():gsub("%s+","")
	maks = maks or 50
	local r = {}
	for _, k in ipairs(_indexKeys) do
		if k:find(sub, 1, true) then
			table.insert(r, k)
			if #r >= maks then break end
		end
	end
	return r
end

local function CariFuzzy(query, maks)
	query = query:lower():gsub("%s+","")
	maks  = maks or 20
	local function skor(kata, pat)
		local si, pi, s, kon = 1, 1, 0, 0
		while si <= #kata and pi <= #pat do
			if kata:sub(si,si) == pat:sub(pi,pi) then
				s   = s + 1 + kon
				kon = kon + 1
				pi  = pi + 1
			else
				kon = 0
			end
			si = si + 1
		end
		return pi > #pat and s or 0
	end
	local kandidat = {}
	for _, k in ipairs(_indexKeys) do
		local s = skor(k, query)
		if s > 0 then table.insert(kandidat, {k=k, s=s}) end
	end
	table.sort(kandidat, function(a,b) return a.s > b.s end)
	local r = {}
	for i = 1, math.min(#kandidat, maks) do
		table.insert(r, kandidat[i].k)
	end
	return r
end

local function AutoJawab(pola)
	pola = pola:lower():gsub("%s+","")
	if pola == "" then return nil end
	local r
	if pola:find("[-_?]") then
		r = CariPola(pola, 1)
		if r[1] then return r[1] end
	end
	r = CariAwalan(pola, 1)
	if r[1] then return r[1] end
	r = CariMengandung(pola, 1)
	if r[1] then return r[1] end
	r = CariFuzzy(pola, 1)
	return r[1]
end

-- ═══════════════════════════════════════════════════
-- INPUT BOX — KIRIM JAWABAN
-- ═══════════════════════════════════════════════════

local function DapatkanInputBox()
	-- Prioritas 1: path manual dari konfigurasi
	if PATH_INPUT_BOX ~= "" then
		local ok, obj = pcall(function()
			local parts = PATH_INPUT_BOX:split(".")
			local cur   = PlayerGui
			for _, p in ipairs(parts) do cur = cur:WaitForChild(p, 3) end
			return cur
		end)
		if ok and obj and obj:IsA("TextBox") then return obj end
	end
	-- Prioritas 2: auto-detect TextBox yang visible & aktif
	for _, obj in ipairs(PlayerGui:GetDescendants()) do
		if obj:IsA("TextBox") and obj.Visible and obj.Parent.Visible then
			return obj
		end
	end
	return nil
end

local function KirimJawaban(teks)
	local box = DapatkanInputBox()
	if not box then
		warn("[AutoJawab] TextBox tidak ditemukan!")
		return false
	end
	box:CaptureFocus()
	if modePanjang then
		box.Text = ""
		for i = 1, #teks do
			box.Text = teks:sub(1, i)
			task.wait(kecepatanKetik + math.random() * 0.05)
		end
	else
		box.Text = teks
	end
	task.wait(0.05)
	box:ReleaseFocus(true)
	return true
end

-- ═══════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════

local function BuatUI()
	if PlayerGui:FindFirstChild("KamusUI") then
		PlayerGui.KamusUI:Destroy()
	end

	-- ── ScreenGui ──
	local GUI = Instance.new("ScreenGui")
	GUI.Name           = "KamusUI"
	GUI.ResetOnSpawn   = false
	GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	GUI.Parent         = PlayerGui

	-- ── Panel ──
	local Panel = Instance.new("Frame")
	Panel.Name             = "Panel"
	Panel.Size             = UDim2.new(0, 330, 0, 480)
	Panel.Position         = UDim2.new(0, 16, 0.5, -240)
	Panel.BackgroundColor3 = Color3.fromRGB(15, 14, 12)
	Panel.BorderSizePixel  = 0
	Panel.Active           = true
	Panel.Draggable        = true
	Panel.Parent           = GUI
	Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 6)
	local Stroke = Instance.new("UIStroke", Panel)
	Stroke.Color = Color3.fromRGB(46, 43, 36); Stroke.Thickness = 1

	-- Garis emas atas
	local GarisEmas = Instance.new("Frame", Panel)
	GarisEmas.Size             = UDim2.new(1, 0, 0, 2)
	GarisEmas.BackgroundColor3 = Color3.fromRGB(201, 168, 76)
	GarisEmas.BorderSizePixel  = 0
	Instance.new("UICorner", GarisEmas).CornerRadius = UDim.new(0, 6)

	-- ── Header ──
	local Header = Instance.new("Frame", Panel)
	Header.Size             = UDim2.new(1, 0, 0, 42)
	Header.BackgroundColor3 = Color3.fromRGB(22, 20, 17)
	Header.BorderSizePixel  = 0

	local Judul = Instance.new("TextLabel", Header)
	Judul.Size              = UDim2.new(1, -46, 1, 0)
	Judul.Position          = UDim2.new(0, 12, 0, 0)
	Judul.BackgroundTransparency = 1
	Judul.Text              = "⌕  KAMUS AUTO JAWAB"
	Judul.TextColor3        = Color3.fromRGB(201, 168, 76)
	Judul.Font              = Enum.Font.GothamBold
	Judul.TextSize          = 11
	Judul.TextXAlignment    = Enum.TextXAlignment.Left

	local BtnX = Instance.new("TextButton", Header)
	BtnX.Size             = UDim2.new(0, 28, 0, 28)
	BtnX.Position         = UDim2.new(1, -36, 0, 7)
	BtnX.BackgroundColor3 = Color3.fromRGB(120, 50, 50)
	BtnX.BorderSizePixel  = 0
	BtnX.Text             = "✕"
	BtnX.TextColor3       = Color3.fromRGB(255,255,255)
	BtnX.Font             = Enum.Font.GothamBold
	BtnX.TextSize         = 11
	Instance.new("UICorner", BtnX).CornerRadius = UDim.new(0, 3)

	-- ── Konten scroll ──
	local Konten = Instance.new("Frame", Panel)
	Konten.Size             = UDim2.new(1, 0, 1, -42)
	Konten.Position         = UDim2.new(0, 0, 0, 42)
	Konten.BackgroundTransparency = 1
	local Pad = Instance.new("UIPadding", Konten)
	Pad.PaddingLeft  = UDim.new(0, 12)
	Pad.PaddingRight = UDim.new(0, 12)
	Pad.PaddingTop   = UDim.new(0, 10)
	local List = Instance.new("UIListLayout", Konten)
	List.SortOrder = Enum.SortOrder.LayoutOrder
	List.Padding   = UDim.new(0, 7)

	-- Helper fungsi
	local function Label(teks, order)
		local l = Instance.new("TextLabel", Konten)
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

	local function Input(placeholder, order)
		local box = Instance.new("TextBox", Konten)
		box.Size              = UDim2.new(1, 0, 0, 32)
		box.BackgroundColor3  = Color3.fromRGB(28, 26, 22)
		box.BorderSizePixel   = 0
		box.PlaceholderText   = placeholder
		box.PlaceholderColor3 = Color3.fromRGB(80, 75, 65)
		box.Text              = ""
		box.TextColor3        = Color3.fromRGB(232, 224, 208)
		box.Font              = Enum.Font.Gotham
		box.TextSize          = 12
		box.ClearTextOnFocus  = false
		box.LayoutOrder       = order
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
		local s = Instance.new("UIStroke", box)
		s.Color = Color3.fromRGB(46, 43, 36)
		local p = Instance.new("UIPadding", box)
		p.PaddingLeft = UDim.new(0, 9)
		return box
	end

	local function Tombol(teks, warna, warnaText, order)
		local b = Instance.new("TextButton", Konten)
		b.Size             = UDim2.new(1, 0, 0, 30)
		b.BackgroundColor3 = warna
		b.BorderSizePixel  = 0
		b.Text             = teks
		b.TextColor3       = warnaText or Color3.fromRGB(15,14,12)
		b.Font             = Enum.Font.GothamBold
		b.TextSize         = 10
		b.LayoutOrder      = order
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		return b
	end

	-- ── STATUS KAMUS ──
	local StatusKamus = Instance.new("TextLabel", Konten)
	StatusKamus.Size              = UDim2.new(1, 0, 0, 22)
	StatusKamus.BackgroundColor3  = Color3.fromRGB(22, 20, 17)
	StatusKamus.BorderSizePixel   = 0
	StatusKamus.Text              = "⟳  Memuat kamus dari GitHub..."
	StatusKamus.TextColor3        = Color3.fromRGB(201, 168, 76)
	StatusKamus.Font              = Enum.Font.Gotham
	StatusKamus.TextSize          = 10
	StatusKamus.LayoutOrder       = 0
	Instance.new("UICorner", StatusKamus).CornerRadius = UDim.new(0, 3)
	local PadSK = Instance.new("UIPadding", StatusKamus)
	PadSK.PaddingLeft = UDim.new(0, 8)

	-- ── POLA ──
	Label("POLA  ( - untuk wildcard,  cth: o--i  atau  ---u-- )", 1)
	local InPola = Input("Contoh: o--i  /  ab-  /  oper-si", 2)

	-- ── AWALAN + AKHIRAN ──
	Label("AWALAN  +  AKHIRAN  (bisa isi salah satu atau keduanya)", 3)
	local RowFrame = Instance.new("Frame", Konten)
	RowFrame.Size             = UDim2.new(1, 0, 0, 32)
	RowFrame.BackgroundTransparency = 1
	RowFrame.LayoutOrder      = 4
	local RowList = Instance.new("UIListLayout", RowFrame)
	RowList.FillDirection = Enum.FillDirection.Horizontal
	RowList.Padding       = UDim.new(0, 6)

	local function InputInline(placeholder, relW, parent)
		local box = Instance.new("TextBox", parent)
		box.Size              = UDim2.new(relW, -3, 1, 0)
		box.BackgroundColor3  = Color3.fromRGB(28, 26, 22)
		box.BorderSizePixel   = 0
		box.PlaceholderText   = placeholder
		box.PlaceholderColor3 = Color3.fromRGB(80, 75, 65)
		box.Text              = ""
		box.TextColor3        = Color3.fromRGB(232, 224, 208)
		box.Font              = Enum.Font.Gotham
		box.TextSize          = 12
		box.ClearTextOnFocus  = false
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
		local s = Instance.new("UIStroke", box); s.Color = Color3.fromRGB(46,43,36)
		local p = Instance.new("UIPadding", box); p.PaddingLeft = UDim.new(0, 8)
		return box
	end

	local InAwalan  = InputInline("Awalan...",  0.46, RowFrame)
	local SepLabel  = Instance.new("TextLabel", RowFrame)
	SepLabel.Size              = UDim2.new(0, 12, 1, 0)
	SepLabel.BackgroundTransparency = 1
	SepLabel.Text              = "+"
	SepLabel.TextColor3        = Color3.fromRGB(201, 168, 76)
	SepLabel.Font              = Enum.Font.GothamBold
	SepLabel.TextSize          = 14
	local InAkhiran = InputInline("Akhiran...", 0.46, RowFrame)

	-- ── HASIL ──
	Label("HASIL PENCARIAN", 5)
	local HasilLabel = Instance.new("TextLabel", Konten)
	HasilLabel.Size              = UDim2.new(1, 0, 0, 52)
	HasilLabel.BackgroundColor3  = Color3.fromRGB(22, 20, 17)
	HasilLabel.BorderSizePixel   = 0
	HasilLabel.Text              = "— ketik pola atau awalan/akhiran di atas —"
	HasilLabel.TextColor3        = Color3.fromRGB(90, 85, 75)
	HasilLabel.Font              = Enum.Font.Gotham
	HasilLabel.TextSize          = 11
	HasilLabel.TextWrapped       = true
	HasilLabel.LayoutOrder       = 6
	Instance.new("UICorner", HasilLabel).CornerRadius = UDim.new(0, 4)
	local PadH = Instance.new("UIPadding", HasilLabel)
	PadH.PaddingLeft = UDim.new(0, 8); PadH.PaddingRight = UDim.new(0, 8)

	-- ── SLIDER KECEPATAN ──
	Label("KECEPATAN JAWAB  (" .. ("%.1f"):format(kecepatanDelay) .. " detik)", 7)

	local SliderBG = Instance.new("Frame", Konten)
	SliderBG.Size             = UDim2.new(1, 0, 0, 18)
	SliderBG.BackgroundColor3 = Color3.fromRGB(28, 26, 22)
	SliderBG.BorderSizePixel  = 0
	SliderBG.LayoutOrder      = 8
	Instance.new("UICorner", SliderBG).CornerRadius = UDim.new(0, 9)

	local SliderFill = Instance.new("Frame", SliderBG)
	SliderFill.Size             = UDim2.new(0.2, 0, 1, 0)
	SliderFill.BackgroundColor3 = Color3.fromRGB(201, 168, 76)
	SliderFill.BorderSizePixel  = 0
	Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(0, 9)

	local SliderInfo = Label("Delay: 1.0 detik  |  Geser untuk ubah (0 – 5 detik)", 9)
	SliderInfo.TextColor3 = Color3.fromRGB(120, 113, 100)

	-- Slider drag
	local dragging = false
	SliderBG.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local rel = math.clamp(
				(i.Position.X - SliderBG.AbsolutePosition.X) / SliderBG.AbsoluteSize.X, 0, 1)
			SliderFill.Size    = UDim2.new(rel, 0, 1, 0)
			kecepatanDelay     = math.floor(rel * 50 + 0.5) / 10
			SliderInfo.Text    = ("Delay: %.1f detik  |  Geser untuk ubah (0 – 5 detik)"):format(kecepatanDelay)
		end
	end)

	-- ── TOGGLE MODE PANJANG ──
	local BtnPanjang = Instance.new("TextButton", Konten)
	BtnPanjang.Size             = UDim2.new(1, 0, 0, 26)
	BtnPanjang.BackgroundColor3 = Color3.fromRGB(28, 26, 22)
	BtnPanjang.BorderSizePixel  = 0
	BtnPanjang.Text             = "○  Mode Ketik Per Huruf (Jawaban Panjang) : MATI"
	BtnPanjang.TextColor3       = Color3.fromRGB(100, 95, 85)
	BtnPanjang.Font             = Enum.Font.Gotham
	BtnPanjang.TextSize         = 10
	BtnPanjang.LayoutOrder      = 10
	Instance.new("UICorner", BtnPanjang).CornerRadius = UDim.new(0, 4)
	local StrokePanjang = Instance.new("UIStroke", BtnPanjang)
	StrokePanjang.Color = Color3.fromRGB(46, 43, 36)

	BtnPanjang.MouseButton1Click:Connect(function()
		modePanjang = not modePanjang
		if modePanjang then
			BtnPanjang.Text       = "●  Mode Ketik Per Huruf (Jawaban Panjang) : NYALA"
			BtnPanjang.TextColor3 = Color3.fromRGB(201, 168, 76)
			StrokePanjang.Color   = Color3.fromRGB(201, 168, 76)
		else
			BtnPanjang.Text       = "○  Mode Ketik Per Huruf (Jawaban Panjang) : MATI"
			BtnPanjang.TextColor3 = Color3.fromRGB(100, 95, 85)
			StrokePanjang.Color   = Color3.fromRGB(46, 43, 36)
		end
	end)

	-- ── TOMBOL JAWAB SEKARANG ──
	local BtnJawab = Tombol("⌨   JAWAB SEKARANG", Color3.fromRGB(201, 168, 76), Color3.fromRGB(15,14,12), 11)

	-- ── TOMBOL AUTO ANSWER ──
	local BtnAuto = Tombol("▶   AUTO ANSWER : MATI", Color3.fromRGB(33, 31, 27), Color3.fromRGB(140,133,118), 12)
	local StrokeAuto = Instance.new("UIStroke", BtnAuto)
	StrokeAuto.Color = Color3.fromRGB(46, 43, 36)

	-- ── STATUS BAR ──
	local StatusBar = Instance.new("TextLabel", Konten)
	StatusBar.Size             = UDim2.new(1, 0, 0, 13)
	StatusBar.BackgroundTransparency = 1
	StatusBar.Text             = "Menunggu kamus selesai dimuat..."
	StatusBar.TextColor3       = Color3.fromRGB(90, 85, 75)
	StatusBar.Font             = Enum.Font.Gotham
	StatusBar.TextSize         = 9
	StatusBar.TextXAlignment   = Enum.TextXAlignment.Left
	StatusBar.LayoutOrder      = 13

	-- ════════════════════════════════════════
	-- LOGIKA PENCARIAN LIVE
	-- ════════════════════════════════════════

	local function UpdateHasil()
		local pola    = InPola.Text:lower():gsub("%s+","")
		local awalan  = InAwalan.Text:lower():gsub("%s+","")
		local akhiran = InAkhiran.Text:lower():gsub("%s+","")
		local hasil   = {}

		if pola ~= "" then
			if pola:find("[-_?]") then
				hasil = CariPola(pola, 30)
			else
				hasil = CariAwalan(pola, 30)
			end
		elseif awalan ~= "" or akhiran ~= "" then
			hasil = CariKombinasi(awalan, akhiran, 30)
		end

		if #hasil == 0 then
			HasilLabel.Text      = "Tidak ditemukan."
			HasilLabel.TextColor3 = Color3.fromRGB(160, 70, 70)
		else
			HasilLabel.Text       = table.concat(hasil, ",  ")
			HasilLabel.TextColor3 = Color3.fromRGB(168, 159, 142)
		end
	end

	for _, box in ipairs({InPola, InAwalan, InAkhiran}) do
		box:GetPropertyChangedSignal("Text"):Connect(UpdateHasil)
	end

	-- ════════════════════════════════════════
	-- JAWAB SEKARANG
	-- ════════════════════════════════════════

	local function JawabSekarang()
		local pola    = InPola.Text:lower():gsub("%s+","")
		local awalan  = InAwalan.Text:lower():gsub("%s+","")
		local akhiran = InAkhiran.Text:lower():gsub("%s+","")
		local jawaban

		if pola ~= "" then
			jawaban = AutoJawab(pola)
		elseif awalan ~= "" or akhiran ~= "" then
			local r = CariKombinasi(awalan, akhiran, 1)
			jawaban = r[1]
		end

		if not jawaban then
			StatusBar.Text      = "✗ Tidak ada kata yang cocok."
			StatusBar.TextColor3 = Color3.fromRGB(180, 70, 70)
			return
		end

		StatusBar.Text       = ("▶ Menjawab '%s' dalam %.1f detik..."):format(jawaban, kecepatanDelay)
		StatusBar.TextColor3 = Color3.fromRGB(201, 168, 76)

		task.delay(kecepatanDelay, function()
			local ok = KirimJawaban(jawaban)
			StatusBar.Text      = ok and ("✓  Dijawab: " .. jawaban) or "✗ Gagal — TextBox tidak ditemukan."
			StatusBar.TextColor3 = ok and Color3.fromRGB(100, 200, 130) or Color3.fromRGB(180,70,70)
		end)
	end

	BtnJawab.MouseButton1Click:Connect(JawabSekarang)

	-- ════════════════════════════════════════
	-- AUTO ANSWER
	-- ════════════════════════════════════════

	BtnAuto.MouseButton1Click:Connect(function()
		autoAktif = not autoAktif
		if autoAktif then
			BtnAuto.Text             = "■   AUTO ANSWER : NYALA"
			BtnAuto.BackgroundColor3 = Color3.fromRGB(201, 168, 76)
			BtnAuto.TextColor3       = Color3.fromRGB(15, 14, 12)
			StrokeAuto.Color         = Color3.fromRGB(201, 168, 76)
			StatusBar.Text           = "Auto answer aktif..."
			StatusBar.TextColor3     = Color3.fromRGB(201, 168, 76)

			task.spawn(function()
				while autoAktif do
					local pola    = InPola.Text:lower():gsub("%s+","")
					local awalan  = InAwalan.Text:lower():gsub("%s+","")
					local akhiran = InAkhiran.Text:lower():gsub("%s+","")
					local jawaban

					if pola ~= "" then
						jawaban = AutoJawab(pola)
					elseif awalan ~= "" or akhiran ~= "" then
						local r = CariKombinasi(awalan, akhiran, 1)
						jawaban = r[1]
					end

					if jawaban then
						StatusBar.Text       = ("⟳  Auto: '%s' dalam %.1f dtk"):format(jawaban, kecepatanDelay)
						StatusBar.TextColor3 = Color3.fromRGB(201, 168, 76)
						task.wait(kecepatanDelay)
						if autoAktif then
							KirimJawaban(jawaban)
							StatusBar.Text       = "✓  Auto dijawab: " .. jawaban
							StatusBar.TextColor3 = Color3.fromRGB(100, 200, 130)
						end
					end
					task.wait(1.5)
				end
			end)
		else
			autoAktif                = false
			BtnAuto.Text             = "▶   AUTO ANSWER : MATI"
			BtnAuto.BackgroundColor3 = Color3.fromRGB(33, 31, 27)
			BtnAuto.TextColor3       = Color3.fromRGB(140, 133, 118)
			StrokeAuto.Color         = Color3.fromRGB(46, 43, 36)
			StatusBar.Text           = "Auto answer dimatikan."
			StatusBar.TextColor3     = Color3.fromRGB(90, 85, 75)
		end
	end)

	-- ════════════════════════════════════════
	-- TUTUP
	-- ════════════════════════════════════════

	BtnX.MouseButton1Click:Connect(function()
		autoAktif = false
		GUI:Destroy()
	end)

	-- ════════════════════════════════════════
	-- FETCH KAMUS DARI GITHUB
	-- ════════════════════════════════════════

	FetchKamus(URL_JSON, function(berhasil, pesan)
		StatusKamus.Text = berhasil
			and ("✓  " .. pesan)
			or  ("✗  " .. pesan)
		StatusKamus.TextColor3 = berhasil
			and Color3.fromRGB(100, 200, 130)
			or  Color3.fromRGB(180, 70, 70)
		StatusBar.Text      = berhasil and "Kamus siap. Ketik pola untuk mencari." or "Kamus gagal dimuat."
		StatusBar.TextColor3 = berhasil and Color3.fromRGB(90, 85, 75) or Color3.fromRGB(180,70,70)
	end)
end

-- ═══════════════════════════════════════════════════
-- JALANKAN
-- ═══════════════════════════════════════════════════

BuatUI()
print("[KamusAutoJawab] Siap digunakan.")
