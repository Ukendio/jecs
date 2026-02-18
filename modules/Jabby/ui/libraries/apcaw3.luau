local SA98G = {
	mainTRC = 2.4,
	mainTRCencode = 1 / 2.4,
	sRco = 0.2126729,
	sGco = 0.7151522,
	sBco = 0.0721750,
	normBG = 0.56,
	normTXT = 0.57,
	revTXT = 0.62,
	revBG = 0.65,
	blkThrs = 0.022,
	blkClmp = 1.414,
	scaleBoW = 1.14,
	scaleWoB = 1.14,
	loBoWoffset = 0.027,
	loWoBoffset = 0.027,
	deltaYmin = 0.0005,
	loClip = 0.1,
	mFactor = 1.94685544331710,
	mFactInv = 1 / 1.94685544331710,
	mOffsetIn = 0.03873938165714010,
	mExpAdj = 0.2833433964208690,
	mExp = 0.2833433964208690 / 1.414,
	mOffsetOut = 0.3128657958707580,
}

local function isNaN(n)
	return n ~= n
end

local function reverseAPCA(contrast, knownY, knownType, returnAs)
	if contrast == nil then
		contrast = 0
	end
	if knownY == nil then
		knownY = 1.0
	end
	if knownType == nil then
		knownType = "bg"
	end
	if returnAs == nil then
		returnAs = "hex"
	end
	if math.abs(contrast) < 9 then
		return false
	end
	local unknownY = knownY
	local knownExp
	local unknownExp
	--///   APCA   0.0.98G - 4g - W3 Compatible Constants   ////////////////////
	local scale = if contrast > 0 then SA98G.scaleBoW else SA98G.scaleWoB
	local offset = if contrast > 0 then SA98G.loBoWoffset else -SA98G.loWoBoffset
	contrast = (assert(tonumber(contrast)) * 0.01 + offset) / scale
	-- Soft clamps Y if it is near black.
	knownY = if (knownY > SA98G.blkThrs) then knownY else knownY + math.pow(SA98G.blkThrs - knownY, SA98G.blkClmp)
	-- set the known and unknown exponents
	if knownType == "bg" or knownType == "background" then
		knownExp = if contrast > 0 then SA98G.normBG else SA98G.revBG
		unknownExp = if contrast > 0 then SA98G.normTXT else SA98G.revTXT
		unknownY = math.pow(math.pow(knownY, knownExp) - contrast, 1 / unknownExp)
		if isNaN(unknownY) then
			return false
		end
	elseif knownType == "txt" or knownType == "text" then
		knownExp = if contrast > 0 then SA98G.normTXT else SA98G.revTXT
		unknownExp = if contrast > 0 then SA98G.normBG else SA98G.revBG
		unknownY = math.pow(contrast + math.pow(knownY, knownExp), 1 / unknownExp)
		if isNaN(unknownY) then
			return false
		end
	else
		return false
	end
	--return contrast +'----'+unknownY;
	if unknownY > 1.06 or unknownY < 0 then
		return false
	end
	-- if (unknownY < 0) { return false } // return false on underflow
	--unknownY = math.max(unknownY,0.0);
	--  unclamp
	unknownY = if (unknownY > SA98G.blkThrs) then unknownY else (math.pow(((unknownY + SA98G.mOffsetIn) * SA98G.mFactor), SA98G.mExp) * SA98G.mFactInv) - SA98G.mOffsetOut
	--    unknownY - 0.22 * math.pow(unknownY*0.5, 1/blkClmp);
	unknownY = math.max(math.min(unknownY, 1.0), 0.0)
	if returnAs == "color" then
		local colorB = math.round(math.pow(unknownY, SA98G.mainTRCencode) * 255)
		local retUse = if (knownType == "bg") then "txtColor" else "bgColor"
		return { colorB, colorB, colorB, 1, retUse }
	elseif returnAs == "Y" or returnAs == "y" then
		return math.max(0.0, unknownY)
	else
		return false
	end
end

local function sRGBtoY(sRGBcolor: Color3)
	local r = sRGBcolor.R
	local g = sRGBcolor.G
	local b = sRGBcolor.B

	local function simpleExp(chan)
		return math.pow(chan, SA98G.mainTRC)
	end

	return SA98G.sRco * simpleExp(r) + SA98G.sGco * simpleExp(g) + SA98G.sBco * simpleExp(b)
end

local function displayP3toY(rgb: Color3)
	local mainTRC = 2.4
	local sRco, sGco, sBco = 0.2289829594805780, 0.6917492625852380, 0.0792677779341829

	local function simpleExp(chan)
		return math.pow(chan, mainTRC)
	end

	return sRco * simpleExp(rgb.R) + sGco * simpleExp(rgb.G) + sBco * simpleExp(rgb.B)
end

local function adobeRGBtoY(rgb: Color3)
	local mainTRC = 2.35

	local sRco = 0.2973550227113810
	local sGco = 0.6273727497145280
	local sBco = 0.0752722275740913

	local function simpleExp(chan)
		return math.pow(chan / 255.0, mainTRC)
	end

	return sRco * simpleExp(rgb.R) + sGco * simpleExp(rgb.G) + sBco * simpleExp(rgb.B)
end


local function APCAcontrast(txtY, bgY, places)
	places = places or -1

	local icp = { 0, 1.1 }

	if math.min(txtY, bgY) < icp[1] or math.max(txtY, bgY) > icp[2] then
		return 0
	end

	local SAPC = 0
	local outputContrast = 0
	local polCat = "BoW"

	txtY = (txtY > SA98G.blkThrs) and txtY or txtY + math.pow(SA98G.blkThrs - txtY, SA98G.blkClmp)
	bgY = (bgY > SA98G.blkThrs) and bgY or bgY + math.pow(SA98G.blkThrs - bgY, SA98G.blkClmp)

	if math.abs(bgY - txtY) < SA98G.deltaYmin then
		return 0
	end

	if bgY > txtY then -- black text on white
		SAPC = (math.pow(bgY, SA98G.normBG) - math.pow(txtY, SA98G.normTXT)) * SA98G.scaleBoW

		outputContrast = (SAPC < SA98G.loClip) and 0.0 or SAPC - SA98G.loBoWoffset
	else
		-- should always return negative
		polCat = "WoB" -- white on black

		SAPC = (math.pow(bgY, SA98G.revBG) - math.pow(txtY, SA98G.revTXT)) * SA98G.scaleWoB

		outputContrast = (SAPC > -SA98G.loClip) and 0.0 or SAPC + SA98G.loWoBoffset
	end

	if places < 0 then
		return outputContrast * 100.0
	elseif places == 0 then
		return math.round(math.abs(outputContrast) * 100.0) --+ "<sub>" + polCat + "</sub>" -- why is there html
	elseif places // 1 == places then
		return (outputContrast * 100.0) * places // 1 / places
	else
		return 0.0
	end
end

local function alphaBlend(rgbFG: Color3, aFG: number, rgbBG: Color3, round: boolean?)
	round = if round == nil then true else round
	aFG = aFG or 1
	local compBlend = 1 - aFG
	local rgbOut = {0, 0, 0}

	rgbOut[1] = rgbBG.R * compBlend + rgbFG.R * aFG
	if round then rgbOut[1] = math.min(math.round(rgbOut[1]), 255) end
	rgbOut[2] = rgbBG.G * compBlend + rgbFG.G * aFG
	if round then rgbOut[2] = math.min(math.round(rgbOut[2]), 255) end
	rgbOut[3] = rgbBG.B * compBlend + rgbFG.B * aFG
	if round then rgbOut[3] = math.min(math.round(rgbOut[3]), 255) end

	return Color3.new(rgbOut[1], rgbOut[2], rgbOut[3])

end

local function calcAPCA(textcolor: Color3, bgColor: Color3, textalpha: number?, places: number?, round: boolean?)
	places = -1

	--todo: alpha blending
	if textalpha then textcolor = alphaBlend(textcolor, textalpha, bgColor, round) end

	return APCAcontrast(sRGBtoY(textcolor), sRGBtoY(bgColor), places)
end

local function fontLookupAPCA(contrast, places: number?)
	places = places or 2

	-- Font size interpolations. Here the chart was re-ordered to put
	-- the main contrast levels each on one line, instead of font size per line.
	-- First column is LC value, then each following column is font size by weight

	-- G G G G G G  Public Beta 0.1.7 (G) • MAY 28 2022

	-- Lc values under 70 should have Lc 15 ADDED if used for body text
	-- All font sizes are in px and reference font is Barlow

	-- 999: prohibited - too low contrast
	-- 777: NON TEXT at this minimum weight stroke
	-- 666 - this is for spot text, not fluent-Things like copyright or placeholder.
	-- 5xx - minimum font at this weight for content, 5xx % 500 for font-size
	-- 4xx - minimum font at this weight for any purpose], 4xx % 400 for font-size

	-- MAIN FONT SIZE LOOKUP

	---- ASCENDING SORTED  Public Beta 0.1.7 (G) • MAY 28 2022  ////

	---- Lc 45 * 0.2 = 9 which is the index for the row for Lc 45

	--  MAIN FONT LOOKUP May 28 2022 EXPANDED
	-- Sorted by Lc Value
	-- First row is standard weights 100-900
	-- First column is font size in px
	-- All other values are the Lc contrast 
	-- 999 = too low. 777 = non-text and spot text only

	local fontMatrixAscend = {
		{'Lc',100,200,300,400,500,600,700,800,900},
		{0,999,999,999,999,999,999,999,999,999},
		{10,999,999,999,999,999,999,999,999,999},
		{15,777,777,777,777,777,777,777,777,777},
		{20,777,777,777,777,777,777,777,777,777},
		{25,777,777,777,120,120,108,96,96,96},
		{30,777,777,120,108,108,96,72,72,72},
		{35,777,120,108,96,72,60,48,48,48},
		{40,120,108,96,60,48,42,32,32,32},
		{45,108,96,72,42,32,28,24,24,24},
		{50,96,72,60,32,28,24,21,21,21},
		{55,80,60,48,28,24,21,18,18,18},
		{60,72,48,42,24,21,18,16,16,18},
		{65,68,46,32,21.75,19,17,15,16,18},
		{70,64,44,28,19.5,18,16,14.5,16,18},
		{75,60,42,24,18,16,15,14,16,18},
		{80,56,38.25,23,17.25,15.81,14.81,14,16,18},
		{85,52,34.5,22,16.5,15.625,14.625,14,16,18},
		{90,48,32,21,16,15.5,14.5,14,16,18},
		{95,45,28,19.5,15.5,15,14,13.5,16,18},
		{100,42,26.5,18.5,15,14.5,13.5,13,16,18},
		{105,39,25,18,14.5,14,13,12,16,18},
		{110,36,24,18,14,13,12,11,16,18},
		{115,34.5,22.5,17.25,12.5,11.875,11.25,10.625,14.5,16.5},
		{120,33,21,16.5,11,10.75,10.5,10.25,13,15},
		{125,32,20,16,10,10,10,10,12,14},
	}

	local fontDeltaAscend = {
		{'∆Lc',100,200,300,400,500,600,700,800,900},
		{0,0,0,0,0,0,0,0,0,0},
		{10,0,0,0,0,0,0,0,0,0},
		{15,0,0,0,0,0,0,0,0,0},
		{20,0,0,0,0,0,0,0,0,0},
		{25,0,0,0,12,12,12,24,24,24},
		{30,0,0,12,12,36,36,24,24,24},
		{35,0,12,12,36,24,18,16,16,16},
		{40,12,12,24,18,16,14,8,8,8},
		{45,12,24,12,10,4,4,3,3,3},
		{50,16,12,12,4,4,3,3,3,3},
		{55,8,12,6,4,3,3,2,2,0},
		{60,4,2,10,2.25,2,1,1,0,0},
		{65,4,2,4,2.25,1,1,0.5,0,0},
		{70,4,2,4,1.5,2,1,0.5,0,0},
		{75,4,3.75,1,0.75,0.188,0.188,0,0,0},
		{80,4,3.75,1,0.75,0.188,0.188,0,0,0},
		{85,4,2.5,1,0.5,0.125,0.125,0,0,0},
		{90,3,4,1.5,0.5,0.5,0.5,0.5,0,0},
		{95,3,1.5,1,0.5,0.5,0.5,0.5,0,0},
		{100,3,1.5,0.5,0.5,0.5,0.5,1,0,0},
		{105,3,1,0,0.5,1,1,1,0,0},
		{110,1.5,1.5,0.75,1.5,1.125,0.75,0.375,1.5,1.5},
		{115,1.5,1.5,0.75,1.5,1.125,0.75,0.375,1.5,1.5},
		{120,1,1,0.5,1,0.75,0.5,0.25,1,1},
		{125,0,0,0,0,0,0,0,0,0},
	};

	local weightArray = {0, 100, 200, 300, 400, 500, 600, 700, 800, 900}
	local weightArrayLen = #weightArray

	local returnArray = {tostring(contrast * places // 1 / places), 0, 0, 0, 0, 0, 0, 0, 0, 0}
	local returnArrayLen = #returnArray

	local contrastArrayAscend = {'lc',0,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,100,105,110,115,120,125,}
	local contrastArrayLenAsc = #contrastArrayAscend

	-- Lc 45 * 0.2 = 9 and 9 is the index for the row for lc 45

	local tempFont = 777
	local contrast = math.abs(contrast)
	local factor = 0.2
	local index = contrast == 0 and 1 or bit32.bor(contrast * factor, 0)
	local w = 0
	local scoreAdj = (contrast - fontMatrixAscend[index + 1][w + 1]) * factor

	w += 1

	while w < weightArrayLen do
		w += 1
		tempFont = fontMatrixAscend[index+1][w+1]

		if tempFont > 400 then
			returnArray[w + 1] = tempFont
		elseif contrast < 14.5 then
			returnArray[w + 1] = 999
		elseif contrast < 29.5 then
			returnArray[w + 1] = 777
		else
			--- interpolation of font size

			if tempFont > 24 then
				returnArray[w + 1] = math.round(tempFont - (fontDeltaAscend[index + 1][w + 1] * scoreAdj))
			else
				returnArray[w + 1] = tempFont - ((2 * fontDeltaAscend[index + 1][w + 1] * scoreAdj // 1) * 0.5)
		
			end
		end
	end

	return returnArray

end

return {

	APCAcontrast = APCAcontrast,
	reverseAPCA = reverseAPCA,
	calcAPCA = calcAPCA,
	fontLookupAPCA = fontLookupAPCA,

	sRGBtoY = sRGBtoY,
	displayP3toY = displayP3toY,
	adobeRGBtoY = adobeRGBtoY,
	alphaBlend = alphaBlend

}