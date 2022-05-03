#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_AUTHOR  "ack"
#define PLUGIN_VERSION "0.10"

public Plugin myinfo = {
	name = "eotl_class_limits",
	author = PLUGIN_AUTHOR,
	description = "limit the number of players for classes",
	version = PLUGIN_VERSION,
	url = ""
};

#define TEAM_RED        2
#define TEAM_BLUE       3
#define TEAM_MAX        3

#define CLASS_UNKNOWN   0
#define CLASS_SCOUT     1
#define CLASS_SNIPER    2
#define CLASS_SOLDIER   3
#define CLASS_DEMOMAN   4
#define CLASS_MEDIC     5
#define CLASS_HEAVY     6
#define CLASS_PYRO      7
#define CLASS_SPY       8
#define CLASS_ENGINEER  9

#define CLASS_MIN       1
#define CLASS_MAX       9

enum struct ClassCache {
    bool isValid;
    int team;
    int class;
}

ConVar g_cvEnabled;
ConVar g_cvSounds;
ConVar g_cvWantClass;
ConVar g_cvLimits[TEAM_MAX + 1][CLASS_MAX + 1];
int g_iLastClass[MAXPLAYERS + 1];
int g_iWantClass[MAXPLAYERS + 1];
bool g_bRoundOver;
ConVar g_cvDebug;
ClassCache g_eClassCache[MAXPLAYERS + 1];

char g_sSounds[][] = {
    "",
    "vo/scout_no03.mp3",
    "vo/sniper_no04.mp3",
    "vo/soldier_no01.mp3",
    "vo/demoman_no03.mp3",
    "vo/medic_no03.mp3",
    "vo/heavy_no02.mp3",
    "vo/pyro_no01.mp3",
    "vo/spy_no02.mp3",
    "vo/engineer_no03.mp3"
};

char g_sClasses[][] = {
    "unknown",
    "scout",
    "sniper",
    "soldier",
    "demoman",
    "medic",
    "heavyweapons",
    "pyro",
    "spy",
    "engineer"
};

char g_sTeams[][] = {
    "unassigned",
    "spectator",
    "red",
    "blue"
};

public void OnPluginStart() {
    LogMessage("version %s starting", PLUGIN_VERSION);
    HookEvent("player_death", EventPlayerDeath);
    HookEvent("player_spawn", EventPlayerSpawn);
    HookEvent("player_team", EventPlayerTeam);
    HookEvent("player_changeclass", EventPlayerClass);

    HookEvent("teamplay_round_start", EventRoundStart);
    HookEvent("teamplay_round_stalemate", EventRoundEnd);
    HookEvent("teamplay_round_win", EventRoundEnd);
    HookEvent("teamplay_game_over", EventRoundEnd);

    AddCommandListener(OnJoinClass, "joinclass");

    RegConsoleCmd("sm_wantclass", CommandWantClass);

    g_cvEnabled = CreateConVar("sm_classrestrict_enabled", "1", "Enable/disable class limits plugin");
    g_cvSounds = CreateConVar("sm_classrestrict_sounds", "1", "Enable/disable sound effects on class restricts.");
    g_cvWantClass = CreateConVar("eotl_class_limits_wantclass", "1", "Enable/disable !wantclass command for all players");
    g_cvDebug = CreateConVar("eotl_class_limits_debug", "0", "0/1 enable debug output", FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvLimits[TEAM_BLUE][CLASS_DEMOMAN]  = CreateConVar("sm_classrestrict_blu_demomen",   "-1", "Limit for Blu demomen in TF2.");
    g_cvLimits[TEAM_BLUE][CLASS_ENGINEER] = CreateConVar("sm_classrestrict_blu_engineers", "-1", "Limit for Blu engineers in TF2.");
    g_cvLimits[TEAM_BLUE][CLASS_HEAVY]    = CreateConVar("sm_classrestrict_blu_heavies",   "-1", "Limit for Blu heavies in TF2.");
    g_cvLimits[TEAM_BLUE][CLASS_MEDIC]    = CreateConVar("sm_classrestrict_blu_medics",    "-1", "Limit for Blu medics in TF2.");
    g_cvLimits[TEAM_BLUE][CLASS_PYRO]     = CreateConVar("sm_classrestrict_blu_pyros",     "-1", "Limit for Blu pyros in TF2.");
    g_cvLimits[TEAM_BLUE][CLASS_SCOUT]    = CreateConVar("sm_classrestrict_blu_scouts",    "-1", "Limit for Blu scouts in TF2.");
    g_cvLimits[TEAM_BLUE][CLASS_SNIPER]   = CreateConVar("sm_classrestrict_blu_snipers",   "-1", "Limit for Blu snipers in TF2.");
    g_cvLimits[TEAM_BLUE][CLASS_SOLDIER]  = CreateConVar("sm_classrestrict_blu_soldiers",  "-1", "Limit for Blu soldiers in TF2.");
    g_cvLimits[TEAM_BLUE][CLASS_SPY]      = CreateConVar("sm_classrestrict_blu_spies",     "-1", "Limit for Blu spies in TF2.");

    g_cvLimits[TEAM_RED][CLASS_DEMOMAN]   = CreateConVar("sm_classrestrict_red_demomen",   "-1", "Limit for Red demomen in TF2.");
    g_cvLimits[TEAM_RED][CLASS_ENGINEER]  = CreateConVar("sm_classrestrict_red_engineers", "-1", "Limit for Red engineers in TF2.");
    g_cvLimits[TEAM_RED][CLASS_HEAVY]     = CreateConVar("sm_classrestrict_red_heavies",   "-1", "Limit for Red heavies in TF2.");
    g_cvLimits[TEAM_RED][CLASS_MEDIC]     = CreateConVar("sm_classrestrict_red_medics",    "-1", "Limit for Red medics in TF2.");
    g_cvLimits[TEAM_RED][CLASS_PYRO]      = CreateConVar("sm_classrestrict_red_pyros",     "-1", "Limit for Red pyros in TF2.");
    g_cvLimits[TEAM_RED][CLASS_SCOUT]     = CreateConVar("sm_classrestrict_red_scouts",    "-1", "Limit for Red scouts in TF2.");
    g_cvLimits[TEAM_RED][CLASS_SNIPER]    = CreateConVar("sm_classrestrict_red_snipers",   "-1", "Limit for Red snipers in TF2.");
    g_cvLimits[TEAM_RED][CLASS_SOLDIER]   = CreateConVar("sm_classrestrict_red_soldiers",  "-1", "Limit for Red soldiers in TF2.");
    g_cvLimits[TEAM_RED][CLASS_SPY]       = CreateConVar("sm_classrestrict_red_spies",     "-1", "Limit for Red spies in TF2.");

}

public void OnConfigsExecuted() {

	if (g_cvSounds.BoolValue) {
		LogMessage("sound effects enabled");

		for (int i = 1; i < sizeof(g_sSounds); i++) {
            // the sounds are all built in, so we shouldn't
            // need to add to download list.
            PrecacheSound(g_sSounds[i]);
		}
	}
}

public void OnMapStart() {
    for(int client = 1; client <= MaxClients; client++) {
        g_iLastClass[client] = CLASS_UNKNOWN;
        g_iWantClass[client] = CLASS_UNKNOWN;
    }
    g_bRoundOver = false;
}

public void OnClientConnected(int client) {
    g_iLastClass[client] = CLASS_UNKNOWN;
    g_iWantClass[client] = CLASS_UNKNOWN;
    g_eClassCache[client].isValid = false;
}

public void OnClientDisconnect(int client) {
    g_iLastClass[client] = CLASS_UNKNOWN;
    g_iWantClass[client] = CLASS_UNKNOWN;
    g_eClassCache[client].isValid = false;
}

public Action EventPlayerSpawn(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    int class = view_as<int>(TF2_GetPlayerClass(client));
    g_iLastClass[client] = class;

    if(!g_cvWantClass.BoolValue) {
        return Plugin_Continue;
    }

    if(g_iWantClass[client] == CLASS_UNKNOWN) {
        return Plugin_Continue;
    }

    if(g_iWantClass[client] == class) {
        g_iWantClass[client] = CLASS_UNKNOWN;
        PrintToChat(client, "\x01[\x03wantclass\x01] You are now a \x03%s\x01, clearing your wantclass", g_sClasses[class]);
    }
    return Plugin_Continue;
}

// When a player dies see if there are too many of thier class,
// and if there is force them to a random class.  This can
// specifically happen if the plugin is enabled mid round or
// if changes where made to the limits.
public Action EventPlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
    int client, team, class, counts[CLASS_MAX + 1], picked;

    if((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER) == TF_DEATHFLAG_DEADRINGER) {
        return Plugin_Continue;
    }

    if(!g_cvEnabled.BoolValue) {
        return Plugin_Continue;
    }

    client = GetClientOfUserId(GetEventInt(event, "userid"));
    team = view_as<int>(TF2_GetClientTeam(client));
    if(team != TEAM_BLUE && team != TEAM_RED) {
        return Plugin_Continue;
    }

    class = view_as<int>(TF2_GetPlayerClass(client));
    if(class == CLASS_UNKNOWN) {
        return Plugin_Continue;
    }

    GetClassCounts(team, counts);
    if(g_cvWantClass.BoolValue) {
        if(g_iWantClass[client] != CLASS_UNKNOWN) {
            if(counts[g_iWantClass[client]] < g_cvLimits[team][g_iWantClass[client]].IntValue || g_cvLimits[team][g_iWantClass[client]].IntValue < 0) {
                PrintToChat(client, "\x01[\x03wantclass\x01] Your wantclass \x03%s\x01 is available, switching", g_sClasses[g_iWantClass[client]]);
                FakeClientCommand(client, "joinclass %s", g_sClasses[g_iWantClass[client]]);
                return Plugin_Continue;
            }
        }
    }

    if(g_cvLimits[team][class].IntValue < 0) {
        return Plugin_Continue;
    }
    if(counts[class] <= g_cvLimits[team][class].IntValue) {
        return Plugin_Continue;
    }

    picked = PickRandomClass(client, team);
    if(picked == 0) {
        LogMessage("ERROR: client: %N no valid classes for random pick!?", client);
        return Plugin_Continue;
    }

    LogMessage("excessive class %s (%d/%d) on team %s, forcing client %N to random class (%s)", g_sClasses[class], counts[class],g_cvLimits[team][class].IntValue, g_sTeams[team], client, g_sClasses[picked]);

    PrintToChat(client, "\x03WARNING\x01: Number of \x03%s\x01 over allowed limit (%d), forcing you to random class \x03%s\x01", g_sClasses[class], g_cvLimits[team][class].IntValue, g_sClasses[picked]);
    PrintToChat(client, "\x01[\x03wantclass\x01] Say \"!wantclass %s\" to auto switch when available", g_sClasses[class]);
    FakeClientCommand(client, "joinclass %s", g_sClasses[picked]);
    return Plugin_Continue;
}

public void EventPlayerClass(Handle event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    int class = GetEventInt(event, "class");
    int team = GetClientTeam(client);

    if(team != TEAM_BLUE && team != TEAM_RED) {
        return;
    }

    if(class == CLASS_UNKNOWN) {
        return;
    }

    g_eClassCache[client].isValid = true;
    g_eClassCache[client].team = team;
    g_eClassCache[client].class = class;
}

// If a player is on team A and is class C and then switches to team B,
// there will be no joinclass <class> command.  They will just
// automatically be class C on team B.  So we need to have a check for
// over limits when a player joins a team and force the player off the
// class.  Note: this event is telling us the player is joining the team
// in the event, they arent actually on it yet.
public Action EventPlayerTeam(Handle event, const char[] name, bool dontBroadcast) {
    int client, team, class, counts[CLASS_MAX + 1], picked;

    client = GetClientOfUserId(GetEventInt(event, "userid"));
    team = GetEventInt(event, "team");

    if(!g_cvEnabled.BoolValue) {
        return Plugin_Continue;
    }

    LogDebug("client: %N team change to %s", client, g_sTeams[team]);

    if(team != TEAM_BLUE && team != TEAM_RED) {
        return Plugin_Continue;
    }

    // This is a little annoying, we have use the last class from joinclass
    // and not the players actual class.  There is a weird effect that happens
    // when the player is dead, switches classes, then switches teams (while
    // still dead).  If we were to do a TF2_GetPlayerClass() here it would
    // actually return their class from before their class switch, but when
    // the player actually spawns on the new team they will end up being the
    // new class.
    class = g_iLastClass[client];
    if(class == CLASS_UNKNOWN) {
        return Plugin_Continue;
    }

    if(g_cvLimits[team][class].IntValue < 0) {
        return Plugin_Continue;
    }

    GetClassCounts(team, counts);

    // if we are in the end round state we are assuming this team change
    // will be from the mass team swap.  In this case we just need to
    // make sure we are at or under the limit.
    if(g_bRoundOver) {
        if(counts[class] <= g_cvLimits[team][class].IntValue) {
            return Plugin_Continue;
        }
    } else {
    // outside a end round state, this team change would indicate an
    // additional player being added to the class, so we need make
    // we are under the limit.
        if(counts[class] < g_cvLimits[team][class].IntValue) {
            return Plugin_Continue;
        }
    }

    picked = PickRandomClass(client, team);
    if(picked == 0) {
        LogMessage("ERROR: client: %N no valid classes for random pick!?", client);
        return Plugin_Continue;
    }

    LogMessage("excessive class %s on team %s, forcing client %N to random class (%s)", g_sClasses[class], g_sTeams[team], client, g_sClasses[picked]);

    // need to do the joinclass on a delay here since it will
    // be ignored with them not being on the team
    int encode = (client << 4) | picked;
    CreateTimer(0.1, ChangeClassTimer, encode, TIMER_FLAG_NO_MAPCHANGE);
    PrintToChat(client, "\x03WARNING\x01: Number of \x03%s\x01 over allowed limit (%d), forcing you to random class \x03%s\x01", g_sClasses[class], g_cvLimits[team][class].IntValue, g_sClasses[picked]);
    return Plugin_Continue;
}

public Action EventRoundStart(Handle event, const char[] name, bool dontBroadcast) {
    g_bRoundOver = false;
    LogDebug("EventRoundStart");
    return Plugin_Continue;
}

public Action EventRoundEnd(Handle event, const char[] name, bool dontBroadcast) {
    int client, team, class;

    // only care about full round which would then cause a team swap
    if(StrEqual(name, "teamplay_round_win") && !GetEventInt(event, "full_round")) {
	    return Plugin_Continue;
    }

    LogDebug("EventRoundEnd");
    g_bRoundOver = true;
    for(client = 1; client <= MaxClients; client++) {
        if(!IsClientConnected(client) || !IsClientInGame(client)) {
            g_eClassCache[client].isValid = false;
            continue;
        }

        team = view_as<int>(TF2_GetClientTeam(client));
        if(team != TEAM_BLUE && team != TEAM_RED) {
            g_eClassCache[client].isValid = false;
            continue;
        }

        if(IsPlayerAlive(client)) {
            class = view_as<int>(TF2_GetPlayerClass(client));
        } else {
            class = g_iLastClass[client];
        }

        if(class == CLASS_UNKNOWN) {
            g_eClassCache[client].isValid = false;
            continue;
        }

        // this is in prep for a team swap so we need to switch teams
        if(team == TEAM_BLUE) {
            team = TEAM_RED;
        } else {
            team = TEAM_BLUE;
        }

        g_eClassCache[client].isValid = true;
        g_eClassCache[client].team = team;
        g_eClassCache[client].class = class;
    }

    return Plugin_Continue;
}

public Action ChangeClassTimer(Handle timer, int encode) {
    int client = (encode >> 4);
    int class = encode & 0xf;

    if(!IsClientConnected(client) || !IsClientInGame(client)) {
        return Plugin_Continue;
    }

    FakeClientCommand(client, "joinclass %s", g_sClasses[class]);
    return Plugin_Continue;
}

// intercept joinclass <class> commands and block them if it would
// cause us to go over the class limit for the given class/team.
public Action OnJoinClass(int client, const char[] command, int args) {
    char argv[32];
    int targetClass, currentClass, team;

    if(!g_cvEnabled.BoolValue) {
        return Plugin_Continue;
    }

    team = view_as<int>(TF2_GetClientTeam(client));
    if(team != TEAM_BLUE && team != TEAM_RED) {
        LogDebug("client: %N, joinclass command when not on a team!? (%s), allowing", client, g_sTeams[team]);
        return Plugin_Continue;
    }

    GetCmdArg(1, argv, sizeof(argv));
    StringToLower(argv);
    targetClass = view_as<int>(TF2_GetClass(argv));

    if(IsPlayerAlive(client)) {
        currentClass = view_as<int>(TF2_GetPlayerClass(client));
    } else {
        currentClass = g_iLastClass[client];
    }

    LogDebug("client: %N got joinclass %s", client, argv);

    if(targetClass == CLASS_UNKNOWN) {

        if(StrEqual("random", argv, false) || StrEqual("auto", argv, false)) {
            LogDebug("client: %N wants a random class", client);

            int picked = PickRandomClass(client, team);
            if(picked == 0) {
                LogMessage("ERROR: client: %N no valid classes for random pick!?", client);
                return Plugin_Continue;
            }

            LogDebug("client: %N, randomly picked class %s", client, g_sClasses[picked]);
            FakeClientCommand(client, "joinclass %s", g_sClasses[picked]);
            return Plugin_Handled;
        }

        LogDebug("client: %N, unknown class \"%s\" on joinclass command, allowing", client, argv);
        return Plugin_Continue;
    }

    if(targetClass == currentClass) {
        LogDebug("client: %N, current/target classes are the same (%s), allowing", client, g_sClasses[currentClass]);
        return Plugin_Continue;
    }

    if(!AllowClassChange(client, team, targetClass)) {
        ShowVGUIPanel(client, team == TEAM_BLUE ? "class_blue" : "class_red");
        PrintToChat(client, "\x01[\x03wantclass\x01] Say \"!wantclass %s\" to auto switch when available", g_sClasses[targetClass]);
        if(g_cvSounds.BoolValue) {
		    EmitSoundToClient(client, g_sSounds[targetClass]);
        }
        return Plugin_Handled;
    }

    g_iLastClass[client] = targetClass;

    LogDebug("client: %N allowing class change from %s to %s (team: %s)", client, g_sClasses[currentClass], g_sClasses[targetClass], g_sTeams[team]);
    return Plugin_Continue;
}

bool AllowClassChange(int client, int team, int targetClass) {
    int limit, counts[CLASS_MAX + 1];

    limit = g_cvLimits[team][targetClass].IntValue;
    if(limit < 0) {
        return true;
    }

    GetClassCounts(team, counts);
    if(counts[targetClass] < limit) {
        return true;
    }

    LogMessage("client: %N blocking class change to %s (team: %s, limit: %d, count: %d)", client, g_sClasses[targetClass], g_sTeams[team], limit, counts[targetClass]);
    return false;
}

void GetClassCounts(int team, int counts[CLASS_MAX + 1]) {
    int client, clientClass, clientTeam;

    LogDebug("GetClassCounts: %s cache", (g_bRoundOver ? "using" : "not using"));
    for(int i = 0; i <= CLASS_MAX; i++) {
        counts[i] = 0;
    }

    for(client = 1; client <= MaxClients; client++) {
        if(!IsClientInGame(client)) {
            continue;
        }

        if(g_bRoundOver && !g_eClassCache[client].isValid) {
            continue;
        }

        if(g_bRoundOver) {
            clientTeam = g_eClassCache[client].team;
            clientClass = g_eClassCache[client].class;

        // If a player is dead we can't trust the class provided
        // by TF2_GetPlayerClass().  The player may have changed
        // their class while dead and TF2_GetPlayerClass() won't
        // reflect that change until they spawn.
        } else if(!IsPlayerAlive(client)) {
            clientTeam = view_as<int>(TF2_GetClientTeam(client));
            clientClass = g_iLastClass[client];

        } else {
            clientTeam = view_as<int>(TF2_GetClientTeam(client));
            clientClass = view_as<int>(TF2_GetPlayerClass(client));
        }

        if(clientTeam != team) {
            continue;
        }

        counts[clientClass]++;
    }

}

// put valid classes onto an ArrayList and pick one of those
// at random
int PickRandomClass(int client, int team) {

    ArrayList validClasses;
    int class, counts[CLASS_MAX + 1];

    GetClassCounts(team, counts);

    validClasses = CreateArray(32);
    for(class = CLASS_MIN; class <= CLASS_MAX; class++) {
        if(g_cvLimits[team][class].IntValue < 0 || counts[class] < g_cvLimits[team][class].IntValue) {
            validClasses.Push(class);
        }
    }

    if(validClasses.Length == 0) {
        LogMessage("ERROR: no valid classes for client %N (team: %s) to join!", client, g_sTeams[team]);
        CloseHandle(validClasses);
        return 0;
    }

    int picked = validClasses.Get(GetRandomInt(0, validClasses.Length - 1));
    CloseHandle(validClasses);
    return picked;
}

public Action CommandWantClass(int client, int args) {
    char argv[32];
    int class;

    if(!g_cvWantClass.BoolValue) {
        PrintToChat(client, "\x01[\x03wantclass\x01] Command is currently disabled");
        return Plugin_Handled;
    }

    if(args == 0) {
        if(g_iWantClass[client] == CLASS_UNKNOWN) {
            PrintToChat(client, "\x01[\x03wantclass\x01] Usage: !wantclass <class>");
        } else {
            LogDebug("client: %N cleared their wantclass (%s)", client, g_sClasses[g_iWantClass[client]]);
            PrintToChat(client, "\x01[\x03wantclass\x01] Cleared your wantclass (was: %s)", g_sClasses[g_iWantClass[client]]);
            g_iWantClass[client] = CLASS_UNKNOWN;
        }
        return Plugin_Handled;
    }

    if(args != 1) {
        PrintToChat(client, "\x01[\x03wantclass\x01] Invalid syntax, usage: !wantclass <class>");
        return Plugin_Handled;
    }

    GetCmdArg(1, argv, sizeof(argv));
    StringToLower(argv);
    class = view_as<int>(TF2_GetClass(argv));

    if(class == CLASS_UNKNOWN) {
        // deal with a couple common short hand version of class names
        if(StrEqual(argv, "heavy")) {
            class = CLASS_HEAVY;
        } else if(StrEqual(argv, "demo")) {
            class = CLASS_DEMOMAN;
        } else {
            PrintToChat(client, "\x01[\x03wantclass\x01] Invalid class name %s", argv);
            return Plugin_Handled;
        }
    }

    g_iWantClass[client] = class;
    LogDebug("client: %N set their wantclass to %s", client, g_sClasses[class]);
    PrintToChat(client, "\x01[\x03wantclass\x01] Set to \x03%s\x01, use !wantclass with no args to clear", g_sClasses[class]);

    return Plugin_Handled;
}

void StringToLower(char[] string) {
    int len = strlen(string);
    int i;

    for(i = 0;i < len;i++) {
        string[i] = CharToLower(string[i]);
    }
}

void LogDebug(char []fmt, any...) {

    if(!g_cvDebug.BoolValue) {
        return;
    }

    char message[128];
    VFormat(message, sizeof(message), fmt, 2);
    LogMessage(message);
}