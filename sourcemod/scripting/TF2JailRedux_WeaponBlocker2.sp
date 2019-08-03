#include <sourcemod>
#include <morecolors>
#include <tf2jailredux>
#include <tf2_stocks>
#include <sdktools>
#include <tf2wearables>

#pragma semicolon 1
#pragma newdecls required

#define RED 				2
#define BLU 				3

#define PLUGIN_VERSION 		"1.3.0"

public Plugin myinfo =
{
	name = "TF2Jail Redux Weapon-Blocker",
	author = "Scag/Ragenewb",
	description = "Weapon/Wearable blocker made explicitly for TF2Jail Redux",
	version = PLUGIN_VERSION,
	url = "https://github.com/Scags/TF2-Jailbreak-Redux"
};

ArrayList
	hWeaponList[2]	// 0 for Red team, 1 for Blue team
;

ConVar
	bEnabled
;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (LibraryExists("TF2JailRedux_WeaponBlocker"))
	{
		Format(error, err_max, "You have two versions of the weaponblocker uploaded, please use a single one that satisfies your needs.");
		return APLRes_Failure;
	}

	RegPluginLibrary("TF2JailRedux_WeaponBlocker");
	return APLRes_Success;
}

public void OnPluginStart()
{
	bEnabled = CreateConVar("sm_jbwb_enable", "1", "Enable the TF2Jail Redux Weapon Blocker?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("jbwb_version", PLUGIN_VERSION, "TF2Jail Redux Weapon Blocker version.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	RegAdminCmd("sm_refreshlist", Cmd_RefreshList, ADMFLAG_GENERIC);

	hWeaponList[0] = new ArrayList();
	hWeaponList[1] = new ArrayList();
}

public void OnAllPluginsLoaded()
{
	JB_Hook(OnPlayerPrepped, fwdOnPlayerPrepped);
	if (!LibraryExists("tf2wearables"))	// Should fall under REQUIRE_PLUGIN but w/e
		SetFailState("This plugin requires the TF2Wearables plugin to operate. https://github.com/nosoop/sourcemod-tf2wearables/");
}

public void OnMapStart()
{
	char cfg[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, cfg, sizeof(cfg), "configs/tf2jail/weaponblocker.cfg");

	KeyValues kv = new KeyValues("TF2JailRedux_WeaponBlocker");
	if (!kv.ImportFromFile(cfg))
	{
		delete kv;
		SetFailState("Unable to find TF2Jail Redux Weapon Blocker config in path %s!", cfg);
		return;
	}

	if (!kv.GotoFirstSubKey(false))
	{
		delete kv;
		SetFailState("Unable to find TF2Jail Redux Weapon Blocker config in path %s!", cfg);
		return;
	}

	int count, team;
	char index[4];
	for (count = 0; count < 2; ++count)
		hWeaponList[count].Clear();
	count = 0;

	do
	{
		do
		{
			IntToString(count++, index, 4);
			hWeaponList[team].Push(kv.GetNum(index, -1));
		} while hWeaponList[team].Get(hWeaponList[team].Length-1) != -1;

		hWeaponList[team].Erase(hWeaponList[team].Length-1);	// Ack
		count = 0;
		++team;
	} while kv.GotoNextKey(false);

	delete kv;

	for (count = 0; count < 2; ++count)
		if (hWeaponList[count].Get(0) == -1)
			hWeaponList[count].Clear();
}

public Action Cmd_RefreshList(int client, int args)
{
	CReplyToCommand(client, "%t %t", "Plugin Tag", "Weapon Config");
	OnMapStart();
	return Plugin_Handled;
}

public void fwdOnPlayerPrepped(const JBPlayer player)
{
	if (!bEnabled.BoolValue)
		return;

	int team = GetClientTeam(player.index) - 2;
	int len = hWeaponList[team].Length;

	if (!len)
		return;

	int client = player.index, i, index, wep;
	TFClassType class = TF2_GetPlayerClass(client);
	char classname[64];
	for (i = 0; i < 3; ++i)
	{
		wep = TF2_GetPlayerLoadoutSlot(client, view_as< TF2LoadoutSlot >(i));
		if (wep <= MaxClients)
			continue;

		if (hWeaponList[team].FindValue(GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex")) == -1)
			continue;

		if (TF2_IsWearable(wep))
			TF2_RemoveWearable(client, wep);
		else TF2_RemoveWeaponSlot(client, wep);

		switch (class)
		{
			case TFClass_Scout:
			{
				switch (i)
				{
					case 0:
					{
						classname = "tf_weapon_scattergun";
						index = 13;
					}
					case 1:
					{
						classname = "tf_weapon_pistol_scout";
						index = 23;
					}
					case 2:
					{
						classname = "tf_weapon_bat";
						index = 0;
					}
				}
			}
			case TFClass_Soldier:
			{
				switch (i)
				{
					case 0:
					{
						classname = "tf_weapon_rocketlauncher";
						index = 18;
					}
					case 1:
					{
						classname = "tf_weapon_shotgun_soldier";
						index = 10;
					}
					case 2:
					{
						classname = "tf_weapon_shovel";
						index = 6;
					}
				}
			}
			case TFClass_Pyro:
			{
				switch (i)
				{
					case 0:
					{
						classname = "tf_weapon_flamethrower";
						index = 21;
					}
					case 1:
					{
						classname = "tf_weapon_shotgun_pyro";
						index = 12;
					}
					case 2:
					{
						classname = "tf_weapon_fireaxe";
						index = 2;
					}
				}
			}
			case TFClass_DemoMan:
			{
				switch (i)
				{
					case 0:
					{
						classname = "tf_weapon_grenadelauncher";
						index = 19;
					}
					case 1:
					{
						classname = "tf_weapon_pipebomblauncher";
						index = 20;
					}
					case 2:
					{
						classname = "tf_weapon_bottle";
						index = 1;
					}
				}
			}
			case TFClass_Heavy:
			{
				switch (i)
				{
					case 0:
					{
						classname = "tf_weapon_minigun";
						index = 15;
					}
					case 1:
					{
						classname = "tf_weapon_shotgun_hwg";
						index = 11;
					}
					case 2:
					{
						classname = "tf_weapon_fists";
						index = 5;
					}
				}
			}
			case TFClass_Engineer:
			{
				switch (i)
				{
					case 0:
					{
						classname = "tf_weapon_shotgun_primary";
						index = 9;
					}
					case 1:
					{
						classname = "tf_weapon_pistol";
						index = 22;
					}
					case 2:
					{
						classname = "tf_weapon_wrench";
						index = 7;
					}
				}
			}
			case TFClass_Medic:
			{
				switch (i)
				{
					case 0:
					{
						classname = "tf_weapon_syringegun_medic";
						index = 17;
					}
					case 1:
					{
						classname = "tf_weapon_medigun";
						index = 29;
					}
					case 2:
					{
						classname = "tf_weapon_bonesaw";
						index = 8;
					}
				}
			}
			case TFClass_Sniper:
			{
				switch (i)
				{
					case 0:
					{
						classname = "tf_weapon_sniperrifle";
						index = 14;
					}
					case 1:
					{
						classname = "tf_weapon_smg";
						index = 16;
					}
					case 2:
					{
						classname = "tf_weapon_club";
						index = 3;
					}
				}
			}
			case TFClass_Spy:
			{
				switch (i)
				{
					case 0:
					{
						classname = "tf_weapon_revolver";
						index = 24;
					}
					case 1:
					{
						classname = "tf_weapon_pda_spy";
						index = 735;
					}
					case 2:
					{
						classname = "tf_weapon_knife";
						index = 4;
					}
				}
			}
		}

/*	Flamethrower attributes are fucked up after Jungle Inferno, these static attribs are required whenever spawning them
"flame_gravity"                         "0"
"flame_drag"                            "8.5"
"flame_up_speed"                        "50"
"flame_speed"                           "2450"
"flame_spread_degree"                   "2.8"
"flame_lifetime"                        "0.6"
"flame_random_life_time_offset"         "0.1"
*/

		wep = player.SpawnWeapon(classname, index, 1, 0, (index == 21 ? "841 ; 0 ; 843 ; 8.5 ; 865 ; 50 ; 844 ; 2450 ; 839 ; 2.8 ; 862 ; 0.6 ; 863 ; 0.1" : ""));
		if (team + 2 == RED)
		{ SetWeaponAmmo(client, wep, 0); SetWeaponClip(wep, 0); }
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