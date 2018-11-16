local Plugin = {}
local Shine = Shine
Plugin.Version = "2.81"
Plugin.HasConfig = true
Plugin.ConfigName = "ExternalShuffle.json"

Plugin.DefaultConfig = {
    ShuffleURL = "http://localhost:5000/shuffle",
    PlayerURL = "http://localhost:5000/player",
    ChatName = "ConeSkill",
    ChatRequestMsg = "Aligning cones...",
    VotePercentNeeded = 0.4,
    VoteTimeoutInSeconds = 60,
    MinPlayersForShuffle = 12
}

Plugin.CheckConfig = true
Plugin.CheckConfigTypes = true
Plugin.CheckConfigRecursively = false
Plugin.DefaultState = false
Plugin.NS2Only = false

function Plugin:SetupDataTable()
    self:AddNetworkMessage(
        "SkillUpdate",
        {
            MarineSkill = "integer",
            AlienSkill = "integer",
            SteamId = "integer"
        },
        "Client"
    )

    self:AddNetworkMessage(
        "VoteShuffle",
        {
            Vote = "boolean"
        },
        "Server"
    )
end

Shine:RegisterExtension("externalshuffle", Plugin)
