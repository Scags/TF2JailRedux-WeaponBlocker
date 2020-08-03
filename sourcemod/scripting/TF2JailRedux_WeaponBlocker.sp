#include <sourcemod>
#include <morecolors>
#include <tf2jailredux>
#include <tf2_stocks>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define RED 				2
#define BLU 				3

#define PLUGIN_VERSION 		"2.0.0"

static const char g_strClassNames[10][3][] = {
	{"","",""},	// Dummy first index since classes start at 1
	{"tf_weapon_scattergun", 		"tf_weapon_pistol_scout", 		"tf_weapon_bat"},
	{"tf_weapon_sniperrifle", 		"tf_weapon_smg",				"tf_weapon_club"},
	{"tf_weapon_rocketlauncher",	"tf_weapon_shotgun_soldier", 	"tf_weapon_shovel"},
	{"tf_weapon_grenadelauncher", 	"tf_weapon_pipebomblauncher", 	"tf_weapon_bottle"},
	{"tf_weapon_syringegun_medic", 	"tf_weapon_medigun", 			"tf_weapon_bonesaw"},
	{"tf_weapon_minigun", 			"tf_weapon_shotgun_hwg", 		"tf_weapon_fists"},
	{"tf_weapon_flamethrower", 		"tf_weapon_shotgun_pyro", 		"tf_weapon_fireaxe"},
	{"tf_weapon_revolver", 			"tf_weapon_pda_spy", 			"tf_weapon_knife"},
	{"tf_weapon_shotgun_primary", 	"tf_weapon_pistol", 			"tf_weapon_wrench"}
};

static const int g_iDefIndexes[10][3] = {
	{0,0,0},
	{13, 	23, 	0},
	{14, 	16, 	3},
	{18, 	10, 	6},
	{19, 	20, 	1},
	{17, 	29, 	8},
	{15, 	11, 	5},
	{21, 	12, 	2},
	{24, 	735, 	4},
	{9, 	22, 	7}
};

public Plugin myinfo =
{
	name = "TF2Jail Redux Weapon-Blocker",
	author = "Scag/Ragenewb",
	description = "Weapon/Wearable blocker made explicitly for TF2Jail Redux",
	version = PLUGIN_VERSION,
	url = "https://github.com/Scags/TF2-Jailbreak-Redux"
};

ArrayList
	hNormalList[2],		// Normal Round
	hFreedayList[2],	// Freeday
	hWardayList[2]		// Warday
;

ConVar
	bEnabled
;

public void OnPluginStart()
{
	bEnabled = CreateConVar("sm_jbwb_enable", "1", "Enable the TF2Jail Redux Weapon Blocker?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("jbwb_version", PLUGIN_VERSION, "TF2Jail Redux Weapon Blocker version.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	RegAdminCmd("sm_refreshlist", Cmd_RefreshList, ADMFLAG_GENERIC);
	RegAdminCmd("sm_weaponlist", Cmd_RefreshList, ADMFLAG_GENERIC);

	hNormalList[0] = new ArrayList();
	hNormalList[1] = new ArrayList();
	hFreedayList[0] = new ArrayList();
	hFreedayList[1] = new ArrayList();
	hWardayList[0] = new ArrayList();
	hWardayList[1] = new ArrayList();

	LoadTranslations("tf2jail_redux.phrases");
}

public void OnLibraryAdded(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", true))
	{
		JB_Hook(OnRoundStart, WB_OnRoundStart);
		JB_Hook(OnPlayerPreppedPost, WB_OnPlayerPreppedPost);
	}
}

public void OnMapStart()
{
	RunConfig();
}

public Action Cmd_RefreshList(int client, int args)
{
	CReplyToCommand(client, "%t %t", "Plugin Tag", "Weapon Config");
	RunConfig();
	return Plugin_Handled;
}

public void RunConfig()
{
	char cfg[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, cfg, sizeof(cfg), "configs/tf2jail/weaponblocker.cfg");

	for (int i = 0; i < 2; i++)
	{
		hNormalList[i].Clear();
		hFreedayList[i].Clear();
		hWardayList[i].Clear();
	}

	KeyValues kv = new KeyValues("TF2JailRedux_WeaponBlocker");
	if (!kv.ImportFromFile(cfg))
	{
		delete kv;
		SetFailState("Unable to find TF2Jail Redux Weapon Blocker config in path %s!", cfg);
		return;
	}

	SetBlockList(kv, "Normal", hNormalList);
	SetBlockList(kv, "Freeday", hFreedayList);
	SetBlockList(kv, "Warday", hWardayList);

	// Gotta be special with the "All" key
	SetBlockList(kv, "All", hNormalList);
	SetBlockList(kv, "All", hFreedayList);
	SetBlockList(kv, "All", hWardayList);

	delete kv;
}

public void SetBlockList(KeyValues kv, const char[] name, ArrayList blocks[2])
{
	if (kv.JumpToKey(name))
	{
		AddToList(kv, "Red", blocks[0]);
		AddToList(kv, "Blue", blocks[1]);
		kv.GoBack();
	}
}

public void AddToList(KeyValues kv, const char[] name, ArrayList list)
{
	if (kv.JumpToKey(name))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				list.Push(kv.GetNum(NULL_STRING, -1));
			}	while kv.GotoNextKey(false);
			kv.GoBack();
		}
		kv.GoBack();
	}
}

public void WB_OnRoundStart()
{
	if (!bEnabled.BoolValue)
		return;

	// Delay it in case we aren't last in the hook list
	RequestFrame(PrepPlayers);
}

public void WB_OnPlayerPreppedPost(const JBPlayer player)
{
	PrepPlayer(player.index);
}

public void PrepPlayers()
{
	for (int i = MaxClients; i; --i)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		PrepPlayer(i);
	}
}

public void PrepPlayer(int client)
{
	// I wonder if there'll be a warday and a freeday at the same time
	if (JBGameMode_GetProp("bIsFreedayRound"))
		WeaponStrip(client, hFreedayList[GetClientTeam(client) - 2]);
	else if (JBGameMode_GetProp("bIsWarday"))
		WeaponStrip(client, hWardayList[GetClientTeam(client) - 2]);
	else WeaponStrip(client, hNormalList[GetClientTeam(client) - 2]);
}

public void WeaponStrip(int client, ArrayList list)
{
	if (!list.Length)
		return;

	int weplength = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	int weapon, i, wepindex;
	for (i = 0; i < weplength; ++i)
	{
		weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if (weapon == -1)
			continue;

		wepindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		if (list.FindValue(wepindex) == -1)
			continue;

		CreateWeapon(client, GetSlotFromWeapon(client, weapon));
	}

	for (i = TF2_GetNumWearables(client)-1; i >= 0; --i)	// Reverse iterate because removing a wearable will fuzzle things up with the CUtlVector
	{
		weapon = TF2_GetWearable(client, i);
		// Sometimes ragdolls can get in here, somehow
		if (weapon == -1 || !HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
			continue;

		wepindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		if (list.FindValue(wepindex) == -1)
			continue;

		int slot;
		switch (wepindex)
		{
			// This is awful but there's no other gamedata-less way to do it
			case 405, 608:slot = TFWeaponSlot_Primary;
			case 133, 444, 131, 406, 1099, 1144, 57, 231, 642:slot = TFWeaponSlot_Secondary;
			default:continue;
		}

		TF2_RemoveWearable(client, weapon);
		CreateWeapon(client, slot);
	}
}

stock void SetWeaponAmmo(const int client, const int weapon, const int ammo)
{
	int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
	int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
	SetEntData(client, iAmmoTable+iOffset, ammo, 4, true);
}
stock void SetWeaponClip(const int weapon, const int ammo)
{
	int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
	SetEntData(weapon, iAmmoTable, ammo, 4, true);
}
stock int TF2_GetNumWearables(int client)
{
	// 3552 linux
	// 3532 windows
	int offset = FindSendPropInfo("CTFPlayer", "m_flMaxspeed") - 20 + 12;
	return GetEntData(client, offset);
}

stock int TF2_GetWearable(int client, int wearableidx)
{
	// 3540 linux
	// 3520 windows
	int offset = FindSendPropInfo("CTFPlayer", "m_flMaxspeed") - 20;
	Address m_hMyWearables = view_as< Address >(LoadFromAddress(GetEntityAddress(client) + view_as< Address >(offset), NumberType_Int32));
	int wearable = LoadFromAddress(m_hMyWearables + view_as< Address >(4 * wearableidx), NumberType_Int32) & 0xFFF;

	return (!wearable || wearable == 0xFFF) ? -1 : wearable;
}

stock int GetSlotFromWeapon(int client, int weapon)
{
	if (weapon == -1)
		return -1;

	for (int i = 0; i < 3; ++i)
		if (GetPlayerWeaponSlot(client, i) == weapon)
			return i;
	return -1;
}

public void CreateWeapon(int client, int slot)
{
	if (!(0 <= slot <= 2))
		return;

	TF2_RemoveWeaponSlot(client, slot);
	TFClassType class = TF2_GetPlayerClass(client);
	int wep = JBPlayer(client).SpawnWeapon(g_strClassNames[class][slot], g_iDefIndexes[class][slot], 1, 0, (g_iDefIndexes[class][slot] == 21 ? "841 ; 0 ; 843 ; 8.5 ; 865 ; 50 ; 844 ; 2450 ; 839 ; 2.8 ; 862 ; 0.6 ; 863 ; 0.1" : ""));
	if (GetClientTeam(client) == RED)
	{
		// Should only check for bAllowWeapons but this might be more encompassing. What's a warday without weapons eh?
		if (!JBGameMode_GetProp("bIsWarday") && !JBGameMode_GetProp("bAllowWeapons"))
		{
			SetWeaponAmmo(client, wep, 0);
			SetWeaponClip(wep, 0);
		}
	}
}