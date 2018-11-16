local Plugin = Plugin
local Shine = Shine
local Random = math.random

local DebugMode = false

local SkillTable = {}

local Votes = 0
local Voters = {}
local VotesNeeded = 0

local ShuffleInProgress = false

function Plugin:Initialise()
    self:CreateCommands()
    self.Enabled = true

    return true
end

function Plugin:ExternalShuffle()
    if #Shine.GetAllClients() < Plugin.Config.MinPlayersForShuffle then
        Shine:Notify(Client, "PM", Plugin.Config.ChatName, "Not enough players for External Shuffle.")
        return nil
    end

    if Plugin.ShuffleInProgress then
        local Message = "There is a shuffle still pending."
        Shine:NotifyDualColour(nil, 255, 15, 23, Plugin.Config.ChatName .. ": ", 181, 172, 229, Message)
    end

    if not Plugin.ShuffleInProgress then
        Plugin.ShuffleInProgress = true
        local Gamerules = GetGamerules()
        local GameIDs = Shine.GameIDs
        local Players = {}
        local IDs = {}
        local HiveSkills = {}
        local Index = 0
        Shine:NotifyDualColour(
            nil,
            255,
            15,
            23,
            Plugin.Config.ChatName .. ": ",
            181,
            172,
            229,
            Plugin.Config.ChatRequestMsg
        )

        -- Get the NS2IDs of available players (already in a team)
        for Client, ID in GameIDs:Iterate() do
            local TeamNumber = Client:GetControllingPlayer().teamNumber

            if (TeamNumber == 1 or TeamNumber == 2) then
                Index = Index + 1
                IDs[Index] = ID
                HiveSkills[Index] = Client:GetControllingPlayer():GetPlayerSkill()
                Players[ID] = Client
            end
        end

        local function ShuffleResponseParser(data)
            Plugin.ShuffleInProgress = false
            local ShuffleResult = json.decode(data)

            if not ShuffleResult.success then
                Shine:NotifyDualColour(
                    nil,
                    255,
                    15,
                    23,
                    Plugin.Config.ChatName .. ": ",
                    181,
                    172,
                    229,
                    "Shuffle responded with an error"
                )
                return false
            end

            -- Move each player to the corresponding team
            if ShuffleResult.team1 then
                for Key, ID in pairs(ShuffleResult.team1) do
                    if Players[ID] then
                        Gamerules:JoinTeam(Players[ID]:GetControllingPlayer(), 1, true, true)
                    end
                end
            else
                Log('[ExternalShuffle] Key not found in JSON reponse: "teams1"')
            end

            if ShuffleResult.team2 then
                for Key, ID in pairs(ShuffleResult.team2) do
                    if Players[ID] then
                        Gamerules:JoinTeam(Players[ID]:GetControllingPlayer(), 2, true, true)
                    end
                end
            else
                Log('[ExternalShuffle] Key not found in JSON reponse: "teams2"')
            end

            if ShuffleResult.diagnostics then
                for Key, Value in pairs(ShuffleResult.diagnostics) do
                    Shine:NotifyDualColour(nil, 200, 72, 75, Key .. ": ", 181, 172, 229, tostring(Value))
                end
            end

            Shine:NotifyDualColour(nil, 255, 15, 23, Plugin.Config.ChatName .. ": ", 181, 172, 229, "Successful!")
        end

        Shared.SendHTTPRequest(
            Plugin.Config.ShuffleURL,
            "POST",
            {
                ns2ids = json.encode(IDs),
                hiveskills = json.encode(HiveSkills)
            },
            ShuffleResponseParser
        )
    end
end

function Plugin:CreateCommands()
    local ExternalShuffle = self:BindCommand("sh_extshuffle", "sh_extshuffle", self.ExternalShuffle, true)
end

function Plugin:PostJoinTeam(Gamerules, Player, OldTeam, NewTeam, Force, ShineForce)
    local Client = Player:GetClient()
    local ID = Client:GetUserId()
    local HiveSkill = 0

    local function PlayerResponseParser(data)
        local PlayerResult = json.decode(data)

        if PlayerResult then
            SkillTable[PlayerResult.ns2id] = {
                MarineSkill = PlayerResult.marine_skill,
                AlienSkill = PlayerResult.alien_skill
            }

            self:UpdateClientsSkillTable()
        end
    end

    Shine.Timer.Create(
        string.format("ExtShuffleHSAvailable-%d", ID),
        1,
        30,
        function(Timer)
            if DebugMode then
                HiveSkill = Random(100, 2500)
            else
                HiveSkill = Client:GetControllingPlayer():GetPlayerSkill()
            end
            if HiveSkill ~= 1 then
                Shared.SendHTTPRequest(
                    self.Config.PlayerURL,
                    "POST",
                    {
                        ns2id = ID,
                        hiveskill = HiveSkill
                    },
                    PlayerResponseParser
                )
                Shine.Timer.Destroy(string.format("ExtShuffleHSAvailable-%d", ID))
            end
        end
    )
end

function Plugin:UpdateClientsSkillTable(Client)
    for NS2ID, Skills in pairs(SkillTable) do
        self:SendNetworkMessage(
            nil,
            "SkillUpdate",
            {
                MarineSkill = Skills.MarineSkill,
                AlienSkill = Skills.AlienSkill,
                SteamId = NS2ID
            },
            true
        )
    end
end

function Plugin:ReceiveVoteShuffle(Client, Data)
    if #Shine.GetAllClients() < self.Config.MinPlayersForShuffle then
        Shine:Notify(Client, "PM", self.Config.ChatName, "Not enough players for External Shuffle.")
        return nil
    end

    local AlreadyVoted = false
    local VotesNeeded = math.floor(#Shine.GetAllClients() * self.Config.VotePercentNeeded)

    if (Votes == 0) then
        Shine.Timer.Create(
            "Reset ExtShuffleVotes",
            self.Config.VoteTimeoutInSeconds,
            1,
            function(Timer)
                Votes = 0
                Voters = {}
            end
        )
    end

    for _, VoterClient in pairs(Voters) do
        if (VoterClient == Client) then
            AlreadyVoted = true
        end
    end

    if not AlreadyVoted then
        Votes = Votes + 1
        Voters[#Voters + 1] = Client
        local PlayerName = Client:GetControllingPlayer():GetName()
        local Message = string.format("%s voted to shuffle teams (%s/%s)", PlayerName, Votes, VotesNeeded)
        Shine:NotifyDualColour(nil, 255, 15, 23, self.Config.ChatName .. ": ", 181, 172, 229, Message)
    else
        Shine:Notify(Client, "PM", self.Config.ChatName, "You have already voted.")
    end

    if (Votes > VotesNeeded) then
        Votes = 0
        Voters = {}
        Shine.Timer.Destroy("Reset ExtShuffleVotes")
        self:ExternalShuffle()
    end
end

function Plugin:Cleanup()
    self.BaseClass.Cleanup(self)
    Print "Disabling server plugin..."
end
