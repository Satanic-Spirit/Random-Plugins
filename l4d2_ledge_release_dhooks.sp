#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define GAMEDATA			"left4downtown.l4d2"
#define PLUGIN_VERSION 		"1.0"
#define CHAT_TAG			"\x04[\x05Ledge Release\x04] \x01"

// Global bool variables
bool	g_bPlayer[MAXPLAYERS];
bool	g_bPlayerDelay[MAXPLAYERS];
bool g_bPlayerHanging[MAXPLAYERS];

// Global Handle for Client Timer
Handle g_hClientTimer[MAXPLAYERS];

// Store health
int g_iPlayerHealth[MAXPLAYERS];

// Setting up ConVAr Handles
ConVar Cvar_On;
ConVar Cvar_Interval;
ConVar Cvar_Revive;

public Plugin myinfo =
{
	name = "Ledge Release Dhooks",
	author = "$atanic $pirit",
	description	= "Allows you to drop from hanging position",
	version = PLUGIN_VERSION,
	url = ""
}

public void OnPluginStart()
{
	Cvar_On			= CreateConVar("l4d2_lg_on",			"1",	"On/Off switch for the plugin");	
	Cvar_Interval	= CreateConVar("l4d2_lg_interval",	"3.0",	"Interval before you can release ledge.");
	Cvar_Revive		= CreateConVar("l4d2_lg_revive",		"1",	"Should you be able to release, while being revived?");
		
	// ====================================================================================================
	// Detour
	// ====================================================================================================
	Handle hGamedata = LoadGameConfigFile(GAMEDATA);
	if( hGamedata == null ) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
	
	Handle hDetour_OnLedgeGrabbed = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	if( !hDetour_OnLedgeGrabbed )
		SetFailState("Failed to setup detour for hDetour_OnLedgeGrabbed");
	
	// Load the address of the function from gamedata file.
	if (!DHookSetFromConf(hDetour_OnLedgeGrabbed, hGamedata, SDKConf_Signature, "CTerrorPlayer__OnLedgeGrabbed"))
		SetFailState("Failed to find \"CTerrorPlayer::OnLedgeGrabbed\" signature.");

	// Add all parameters.
	DHookAddParam(hDetour_OnLedgeGrabbed, HookParamType_CBaseEntity);
	
	// Add a pre hook on the function.
	if (!DHookEnableDetour(hDetour_OnLedgeGrabbed, false, Detour_OnLedgeGrabbed_pre))
		SetFailState("Failed to detour OnOnLedgeGrabbed.");
		
	// And a post hook.
	if (!DHookEnableDetour(hDetour_OnLedgeGrabbed, true, Detour_OnLedgeGrabbed))
		SetFailState("Failed to detour CTerrorPlayer::OnLedgeGrabbed post.");
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon)
{
	if(!Cvar_On.BoolValue)
	{
		return Plugin_Continue;
	}

	if(!g_bPlayer[client] && buttons & IN_DUCK)
	{
		OnCrouchButtonPressed(client);
		g_bPlayer[client] = true;
	}
	else if(g_bPlayer[client] && !(buttons & IN_DUCK))
	{
		g_bPlayer[client] = false;
	}
	
	return Plugin_Continue;
}

public MRESReturn Detour_OnLedgeGrabbed_pre(Address pThis, Handle hParam)
{
	int client = view_as<int>(pThis);
	
	g_iPlayerHealth[client] = GetClientHealth(client);
	//PrintToChat(client, "%s Storing player health to %d.", CHAT_TAG, g_iPlayerHealth[client]);
	
	if(g_bPlayerHanging[client])
	{
		//PrintToChatAll("%s Detour_OnLedgeGrabbed skipped for %d, %N!", CHAT_TAG, client, client);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn Detour_OnLedgeGrabbed(Address pThis, Handle hParam)
{	
	int client = view_as<int>(pThis);
	if(Cvar_On.BoolValue && !g_bPlayerHanging[client])
	{
		//PrintToChatAll("%s Detour_OnLedgeGrabbed called by %d, %N!", CHAT_TAG, client, client);
		g_hClientTimer[client] = CreateTimer(Cvar_Interval.FloatValue, Timer_HoldTime, client);
	}
	return MRES_Ignored;
}

public Action Timer_HoldTime(Handle timer, any client)
{
	g_bPlayerDelay[client] = true;
	PrintToChat(client, "%s You can press crouch key to release ledge.", CHAT_TAG);
}

public Action OnCrouchButtonPressed(int client)
{	
	if(Cvar_Revive.BoolValue)
	{
		int rescuer = GetEntProp(client, Prop_Send, "m_reviveOwner");
		int hanging = GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
		if ((rescuer > 0) && hanging)
		{
			PrintToChat(client, "%s You cannot let go while being rescued.", CHAT_TAG);
			return Plugin_Stop;
		}
	}
	if(g_bPlayerDelay[client])
	{
		SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);
		SetEntProp(client, Prop_Send, "m_isHangingFromLedge", 0);
		SetEntProp(client, Prop_Send, "m_isFallingFromLedge", 0);
		g_bPlayerDelay[client] = false;
		g_bPlayerHanging[client] = true;
		CreateTimer(6.0, Timer_HangDelay, client);
		
		//PrintToChat(client, "%s Setting player health to %d.", CHAT_TAG, g_iPlayerHealth[client]);
		SetEntityHealth(client, g_iPlayerHealth[client]);
		
		ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangTwoHands");
		ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangOneHand");
		ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangFingers");
		ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangAboutToFall");
		ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangFalling");
	}
	
	return Plugin_Handled;
}

public Action Timer_HangDelay(Handle timer, any client)
{
	g_bPlayerHanging[client] = false;
	//PrintToChat(client, "%s Setting the value to %d.", CHAT_TAG, g_bPlayerHanging[client]);
}

public void OnMapStart()
{
	for(int i=1; i<MAXPLAYERS; i++)
	{
		g_bPlayerHanging[i] = false;
	}
}
