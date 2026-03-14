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
	if filterPanjang and #k < PANJANG_MIN then return false end
	return true
end

local function Cari(mode, q1, q2)
	q1 = (q1 or ""):lower():gsub("%s+","")
	q2 = (q2 or ""):lower():gsub("%s+","")
	local hasil = {}

	if mode == "pola" then
		for _, k in ipairs(_indexKeys) do
			if filterKata(k) and CocokPola(k, q1) then
				table.insert(hasil, k)
			end
		end
	elseif mode == "awalan" then
		for _, k in ipairs(_indexKeys) do
			if filterKata(k) and k:sub(1,#q1)==q1 then
				table.insert(hasil, k)
			end
		end
	elseif mode == "akhiran" then
		for _, k in ipairs(_indexKeys) do
			if filterKata(k) and #k>=#q1 and k:sub(-#q1)==q1 then
				table.insert(hasil, k)
			end
		end
	elseif mode == "kombinasi" then
		for _, k in ipairs(_indexKeys) do
			if filterKata(k) then
				local okA = q1=="" or k:sub(1,#q1)==q1
				local okB = q2=="" or (#k>=#q2 and k:sub(-#q2)==q2)
				if okA and okB then table.insert(hasil, k) end
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
	local TabFrame = Instance.new("Frame", Body)
	TabFrame.Size             = UDim2.new(1, 0, 0, 28)
	TabFrame.BackgroundTransparency = 1
	TabFrame.LayoutOrder      = 1
	local TabList = Instance.new("UIListLayout", TabFrame)
	TabList.FillDirection = Enum.FillDirection.Horizontal
	TabList.Padding       = UDim.new(0, 4)

	local modeAktif = "awalan"
	local tabs = {}

	local function BuatTab(label, mode)
		local btn = Instance.new("TextButton", TabFrame)
		btn.Size             = UDim2.new(0.24, -3, 1, 0)
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

	local TabAwalan  = BuatTab("Awalan",         "awalan")
	local TabAkhiran = BuatTab("Akhiran",         "akhiran")
	local TabKombo   = BuatTab("Awal + Akhir",   "kombinasi")
	local TabPola    = BuatTab("Pola  (- = ?)",  "pola")

	local function SetTabAktif(mode)
		modeAktif = mode
		for m, t in pairs(tabs) do
			local aktif = m == mode
			t.btn.BackgroundColor3 = aktif and Color3.fromRGB(40,36,24) or Color3.fromRGB(26,24,20)
			t.btn.TextColor3       = aktif and Color3.fromRGB(201,168,76) or Color3.fromRGB(100,95,85)
			t.stroke.Color         = aktif and Color3.fromRGB(201,168,76) or Color3.fromRGB(46,43,36)
		end
	end
	SetTabAktif("awalan")

	for mode, t in pairs(tabs) do
		t.btn.MouseButton1Click:Connect(function()
			SetTabAktif(mode)
			-- update hint input
		end)
	end

	-- ── INPUT AREA ──
	-- Input utama (awalan / akhiran / pola)
	Label("KATA PENCARIAN", 2)
	local InQ1 = Input("Ketik awalan / pola di sini...", 3)

	-- Input akhiran (hanya untuk mode kombinasi)
	local LabelQ2 = Label("AKHIRAN", 4)
	local InQ2    = Input("Ketik akhiran...", 5)
	LabelQ2.Visible = false
	InQ2.Visible    = false

	-- Update visibility input berdasarkan mode
	local function UpdateInput()
		local isKombo = modeAktif == "kombinasi"
		LabelQ2.Visible = isKombo
		InQ2.Visible    = isKombo
		if modeAktif == "awalan" then
			InQ1.PlaceholderText = "Ketik awalan...  cth: me, ber, per"
		elseif modeAktif == "akhiran" then
			InQ1.PlaceholderText = "Ketik akhiran...  cth: kan, an, i"
		elseif modeAktif == "kombinasi" then
			InQ1.PlaceholderText = "Awalan...  cth: me"
			InQ2.PlaceholderText = "Akhiran...  cth: kan"
		elseif modeAktif == "pola" then
			InQ1.PlaceholderText = "Pola wildcard...  cth: o--i  atau  ---u--"
		end
	end

	for mode, t in pairs(tabs) do
		t.btn.MouseButton1Click:Connect(function()
			UpdateInput()
			-- trigger pencarian ulang
			InQ1:GetPropertyChangedSignal("Text"):Wait()
		end)
	end

	-- Trigger update saat tab diklik
	TabAwalan.MouseButton1Click:Connect(UpdateInput)
	TabAkhiran.MouseButton1Click:Connect(UpdateInput)
	TabKombo.MouseButton1Click:Connect(UpdateInput)
	TabPola.MouseButton1Click:Connect(UpdateInput)

	-- ── FILTER KATA PANJANG ──
	local BtnPanjang, IsPanjangAktif = Toggle("Kata Panjang  (6+ huruf)", 6)
	BtnPanjang.MouseButton1Click:Connect(function()
		-- toggle sudah ditangani di dalam fungsi Toggle
		-- update filterPanjang
		task.wait(0.01)
		filterPanjang = IsPanjangAktif()
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
	local function RenderHasil(hasil)
		-- Hapus hasil lama
		for _, c in ipairs(ScrollFrame:GetChildren()) do
			if c:IsA("TextLabel") or c:IsA("TextButton") then c:Destroy() end
		end

		LabelHasil.Text = ("HASIL — %d kata ditemukan"):format(#hasil)

		if #hasil == 0 then
			local empty = Instance.new("TextLabel", ScrollFrame)
			empty.Size              = UDim2.new(1, 0, 0, 30)
			empty.BackgroundTransparency = 1
			empty.Text              = "Tidak ditemukan."
			empty.TextColor3        = Color3.fromRGB(120, 60, 60)
			empty.Font              = Enum.Font.Gotham
			empty.TextSize          = 11
			empty.LayoutOrder       = 0
			return
		end

		-- Render kata dalam grid 2 kolom
		local baris = math.ceil(#hasil / 2)
		for i = 1, baris do
			local row = Instance.new("Frame", ScrollFrame)
			row.Size             = UDim2.new(1, -4, 0, 24)
			row.BackgroundTransparency = 1
			row.LayoutOrder      = i
			local rowList = Instance.new("UIListLayout", row)
			rowList.FillDirection = Enum.FillDirection.Horizontal
			rowList.Padding       = UDim.new(0, 4)

			for col = 1, 2 do
				local idx = (i-1)*2 + col
				local kata = hasil[idx]
				local cell = Instance.new("TextButton", row)
				cell.Size             = UDim2.new(0.5, -2, 1, 0)
				cell.BackgroundColor3 = Color3.fromRGB(28, 26, 22)
				cell.BorderSizePixel  = 0
				cell.Font             = Enum.Font.Gotham
				cell.TextSize         = 11
				cell.TextXAlignment   = Enum.TextXAlignment.Left
				Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 3)
				local cp = Instance.new("UIPadding", cell)
				cp.PaddingLeft = UDim.new(0, 6)

				if kata then
					cell.Text      = kata
					cell.TextColor3 = Color3.fromRGB(200, 192, 175)
					-- Hover effect
					cell.MouseEnter:Connect(function()
						cell.BackgroundColor3 = Color3.fromRGB(38, 34, 26)
						cell.TextColor3 = Color3.fromRGB(201, 168, 76)
					end)
					cell.MouseLeave:Connect(function()
						cell.BackgroundColor3 = Color3.fromRGB(28, 26, 22)
						cell.TextColor3 = Color3.fromRGB(200, 192, 175)
					end)
				else
					cell.Text             = ""
					cell.BackgroundTransparency = 1
					cell.Active           = false
				end
			end
		end
	end

	-- Fungsi jalankan pencarian
	local debounce
	local function DoSearch()
		local q1 = InQ1.Text:lower():gsub("%s+","")
		local q2 = InQ2.Text:lower():gsub("%s+","")

		if q1 == "" and q2 == "" then
			RenderHasil({})
			LabelHasil.Text = "HASIL — ketik untuk mencari"
			return
		end

		local hasil = Cari(modeAktif, q1, q2)
		RenderHasil(hasil)
	end

	InQ1:GetPropertyChangedSignal("Text"):Connect(function()
		if debounce then task.cancel(debounce) end
		debounce = task.delay(0.15, DoSearch)
	end)
	InQ2:GetPropertyChangedSignal("Text"):Connect(function()
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
