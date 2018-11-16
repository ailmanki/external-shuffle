local Plugin = Plugin
local SkillTable = {}
local team1Skill, team2Skill = 0, 0
Plugin.VoteButtonName = "VoteExtShuffle"

Shine.VoteMenu:EditPage(
    "Main",
    Plugin:WrapCallback(
        function(VoteMenu)
            -- Ensure the text reflects the outcome of the vote.
            local ButtonText = "Vote Ext Shuffle"

            local Button =
                VoteMenu:AddSideButton(
                ButtonText,
                function()
                    VoteMenu.GenericClick("sh_voteextshuffle")
                end
            )

            -- Allow the button to be retrieved to have its counter updated.
            Button.Plugin = Plugin.VoteButtonName
            Button.DefaultText = ButtonText
            Button.CheckMarkXScale = 0.5
        end
    )
)

function Plugin:OnFirstThink()
    self:CallModuleEvent("OnFirstThink")
    Shine.Hook.SetupClassHook("GUIScoreboard", "UpdateTeam", "OnGUIScoreboardUpdateTeam", "PassivePost")
    Shine.Hook.SetupClassHook("GUIScoreboard", "Update", "OnGUIScoreboardUpdate", "PassivePost")
end

function Plugin:Initialise()
    self:CreateCommands()
    self.Enabled = true

    return true
end

function Plugin:CreateCommands()
    local function Vote()
        self:SendNetworkMessage(
            "VoteShuffle",
            {
                Vote = true
            },
            true
        )
    end

    local VoteCommand = self:BindCommand("sh_voteextshuffle", Vote)
end

function Plugin:OnGUIScoreboardUpdateTeam(ScoreboardUpdateTeam, updateTeam)
    local teamScores = updateTeam["GetScores"]()
    local teamNumber = updateTeam["TeamNumber"]
    local playerList = updateTeam["PlayerList"]
    local teamSumSkill = 0
    local numPlayers = 0
    local currentPlayerIndex = 1

    for index, player in ipairs(playerList) do
        local playerRecord = teamScores[currentPlayerIndex]
        currentPlayerIndex = currentPlayerIndex + 1

        if playerRecord then
            if SkillTable[playerRecord.SteamId] then
                if teamNumber == 1 then
                    teamSumSkill = teamSumSkill + SkillTable[playerRecord.SteamId].MarineSkill
                end

                if teamNumber == 2 then
                    teamSumSkill = teamSumSkill + SkillTable[playerRecord.SteamId].AlienSkill
                end

                numPlayers = numPlayers + 1
                player["Name"]:SetText(
                    string.format(
                        "[%s %s] %s",
                        SkillTable[playerRecord.SteamId].MarineSkill,
                        SkillTable[playerRecord.SteamId].AlienSkill,
                        playerRecord.Name
                    )
                )
            end
        end
    end

    if (teamNumber == 1 or teamNumber == 2) then
        local avgskill = numPlayers > 0 and teamSumSkill / numPlayers or 0

        if teamNumber == 1 then
            team1Skill = avgskill
        elseif teamNumber == 2 then
            team2Skill = avgskill
        end
    end
end

function Plugin:OnGUIScoreboardUpdate(ScoreboardUpdate, deltaTime)
    local team1Players = #ScoreboardUpdate.teams[2]["GetScores"]()
    local team2Players = #ScoreboardUpdate.teams[3]["GetScores"]()

    if team1Players > 0 then
        team1Text = string.format("Average skill: %d", team1Skill)
    else
        team1Text = ""
    end

    if team2Players > 0 then
        team2Text = string.format("Average skill: %d", team2Skill)
    else
        team2Text = ""
    end

    ScoreboardUpdate.avgSkillItem:SetText(team1Text)
    ScoreboardUpdate.avgSkillItem2:SetText(team2Text)
end

function Plugin:ReceiveSkillUpdate(Data)
    SkillTable[Data.SteamId] = {
        MarineSkill = Data.MarineSkill,
        AlienSkill = Data.AlienSkill
    }
end

function Plugin:Cleanup()
    --Seeing as we're printing a message on cleanup, we need to call the base class cleanup to remove our commands.
    self.BaseClass.Cleanup(self)
    Print "Disabling client plugin..."
end
