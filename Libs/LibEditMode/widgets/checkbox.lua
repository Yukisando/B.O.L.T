local _, ns = ...
local lib
if ns.LibEditMode then
	lib = ns.LibEditMode
else
	local MINOR = 19
	local prevMinor
	lib, prevMinor = LibStub('LibEditMode')
	if prevMinor > MINOR then
		return
	end
end

local function showTooltip(self)
	if self.setting and self.setting.desc then
		SettingsTooltip:SetOwner(self, 'ANCHOR_NONE')
		SettingsTooltip:SetPoint('BOTTOMRIGHT', self, 'TOPLEFT')
		SettingsTooltip:SetText(self.setting.name, 1, 1, 1)
		SettingsTooltip:AddLine(self.setting.desc)
		SettingsTooltip:Show()
	end
end

local checkboxMixin = {}
function checkboxMixin:Setup(data)
	self.setting = data
	self.Label:SetText(data.name)
	self:Refresh()

	local value = data.get(lib:GetActiveLayoutName())
	if value == nil then
		value = data.default
	end

	self.checked = value
	self.Button:SetChecked(not not value) -- force boolean
end

function checkboxMixin:Refresh()
	local data = self.setting
	if type(data.disabled) == 'function' then
		self:SetEnabled(not data.disabled(lib:GetActiveLayoutName()))
	else
		self:SetEnabled(not data.disabled)
	end

	if type(data.hidden) == 'function' then
		self:SetShown(not data.hidden(lib:GetActiveLayoutName()))
	else
		self:SetShown(not data.hidden)
	end
end

function checkboxMixin:OnCheckButtonClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	self.checked = not self.checked
	self.setting.set(lib:GetActiveLayoutName(), not not self.checked, false)

	self:GetParent():GetParent():RefreshWidgets()
end

function checkboxMixin:SetEnabled(enabled)
	self.Button:SetEnabled(enabled)
	self.Label:SetTextColor((enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR):GetRGB())
end

-- SetPropagateMouseMotion is protected in combat (BOLT, 2026-11-15): a checkbox created then,
-- by selecting a system in Edit Mode mid-fight, gets it once combat ends.
local pendingPropagate = {}
local propagateWatcher

local function propagateMouseMotion(button)
	if not InCombatLockdown() then
		button:SetPropagateMouseMotion(true)
		return
	end
	table.insert(pendingPropagate, button)
	if not propagateWatcher then
		propagateWatcher = CreateFrame('Frame')
		propagateWatcher:SetScript('OnEvent', function(watcher)
			for _, pending in ipairs(pendingPropagate) do
				pending:SetPropagateMouseMotion(true)
			end
			wipe(pendingPropagate)
			watcher:UnregisterEvent('PLAYER_REGEN_ENABLED')
		end)
	end
	propagateWatcher:RegisterEvent('PLAYER_REGEN_ENABLED')
end

lib.internal:CreatePool(lib.SettingType.Checkbox, function()
	local frame = CreateFrame('Frame', nil, UIParent, 'EditModeSettingCheckboxTemplate')
	frame:SetScript('OnLeave', DefaultTooltipMixin.OnLeave)
	frame:SetScript('OnEnter', showTooltip)
	propagateMouseMotion(frame.Button)
	return Mixin(frame, checkboxMixin)
end, function(_, frame)
	frame:Hide()
	frame.layoutIndex = nil
end)
