#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define DEBUG 0

#define PLUGIN_VERSION "1.0"

native LMC_GetClientOverlayModel(iClient);// remove this and enable the include to compile with the include this is just here for AM compiler

static iEntRef[MAXPLAYERS+1];
static iEntOwner[2048+1];
static iAttachedRef[2048+1];
static iAttachedOwner[2048+1];
static bool:bThirdPerson[MAXPLAYERS+1];
static bool:bTeleported[MAXPLAYERS+1];

static bool:bLMC_Available = false;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("LMC_GetClientOverlayModel");
	return APLRes_Success;
}

public OnAllPluginsLoaded()
{
	bLMC_Available = LibraryExists("L4D2ModelChanger");
}

public OnLibraryAdded(const String:sName[])
{
	if(StrEqual(sName, "L4D2ModelChanger"))
		bLMC_Available = true;
}

public OnLibraryRemoved(const String:sName[])
{
	if(StrEqual(sName, "L4D2ModelChanger"))
		bLMC_Available = false;
}

public Plugin:myinfo =
{
	name = "[L4D2]Survivor_Legs_Restore",
	author = "Lux",
	description = "Add's Left 4 Dead 1 Style ViewModel Legs",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=299560"
};

public OnPluginStart()
{
	CreateConVar("survivor_legs_version", PLUGIN_VERSION, "[L4D2]Survivor_Legs_version", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	HookEvent("player_death", ePlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", ePlayerSpawn);
	HookEvent("player_team", eTeamChange);
	HookEvent("round_start", eRoundStart);
	
	AddCommandListener(CmdOpenDoor, "choose_opendoor");
}

AttachLegs(iClient)
{
	static iEntity;	
	static String:sModel[PLATFORM_MAX_PATH];
	
	if(IsValidEntRef(iEntRef[iClient]))
	{
		iEntity = EntRefToEntIndex(iEntRef[iClient]);
		GetEntPropString(iClient, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
		SetEntityModel(iEntity, sModel);
		
		if(bLMC_Available)
			AttachOverlayLegs(iClient, true);
		
		return;
	}
		
	
	iEntity = CreateEntityByName("prop_dynamic_override");
	if(iEntity < 0)
		return;
	
	GetEntPropString(iClient, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	
	DispatchKeyValue(iEntity, "model", sModel);
	DispatchSpawn(iEntity);
	ActivateEntity(iEntity);
	
	SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 0x0004);
	
	static Float:fPos[3];
	static Float:fAng[3];
	GetClientAbsOrigin(iClient, fPos);
	GetClientEyeAngles(iClient, fAng);
	
	TeleportEntity(iEntity, fPos, NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(iClient, NULL_VECTOR, Float:{89.0, 0.0, 0.0}, NULL_VECTOR);
	
	AcceptEntityInput(iEntity, "TurnOn");
	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetParent", iClient);
	
	AcceptEntityInput(iEntity, "DisableCollision");
	AcceptEntityInput(iEntity, "DisableShadow");
	
	SetEntProp(iEntity, Prop_Send, "m_noGhostCollision", 1, 1);
	
	SetEntPropVector(iEntity, Prop_Send, "m_vecMins", Float:{0.0, 0.0, 0.0});
	SetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", Float:{0.0, 0.0, 0.0});

	
	TeleportEntity(iEntity, Float:{0.0, 0.0, -20.0}, Float:{-89.0, 0.0, 0.0}, NULL_VECTOR);
	TeleportEntity(iClient, NULL_VECTOR, fAng, NULL_VECTOR);
	
	iEntRef[iClient] = EntIndexToEntRef(iEntity);
	iEntOwner[iEntity] = GetClientUserId(iClient);
	
	//LMC
	if(bLMC_Available)
		AttachOverlayLegs(iClient, false);
	
	SDKHook(iEntity, SDKHook_SetTransmit, HideModel);
}

//door fix, (the door is not buggy on round restart but only on first map spawn)
public Action:CmdOpenDoor(iClient, const String:sCommand[], iArg)
{
	static bool:bIgnoreCmd = false;
	if(bIgnoreCmd)
		return Plugin_Continue;
	
	if(IsFakeClient(iClient) || GetClientTeam(iClient) != 2 || !IsPlayerAlive(iClient) || GetEntProp(iClient, Prop_Send, "m_isIncapacitated", 1))
		return Plugin_Continue;
	
	if(!IsValidEntRef(iEntRef[iClient]))
		return Plugin_Continue;
	
	static iSurvivorLegs;
	iSurvivorLegs = EntRefToEntIndex(iEntRef[iClient]);
	
	bTeleported[iClient] = true;
	TeleportEntity(iSurvivorLegs, Float:{0.0, 0.0, -300.0}, NULL_VECTOR, NULL_VECTOR);
	
	bIgnoreCmd = true;
	FakeClientCommand(iClient, "choose_opendoor");
	bIgnoreCmd = false;
	
	return Plugin_Handled;
}

//lmcstuff
AttachOverlayLegs(iClient, bool:bBaseReattach)
{
	static iSurvivorLegs;
	iSurvivorLegs = EntRefToEntIndex(iEntRef[iClient]);
	
	if(!IsValidEntRef(iSurvivorLegs))
		return;
		
	static iOverlayModel;
	iOverlayModel = LMC_GetClientOverlayModel(iClient);
	
	if(iOverlayModel == -1)
		return;
		
	static iEnt;
	iEnt = EntRefToEntIndex(iAttachedRef[iSurvivorLegs]);
	
	static String:sModel[PLATFORM_MAX_PATH];
	GetEntPropString(iOverlayModel, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	
	if(IsValidEntRef(iEnt))
	{
		if(!bBaseReattach)
		{
			SetEntityModel(iEnt, sModel);
			return;
		}
		else
			AcceptEntityInput(iEnt, "Kill");
	}
	
	iEnt = CreateEntityByName("prop_dynamic_ornament");
	if(iEnt < 0)
		return;
	
	DispatchKeyValue(iEnt, "model", sModel);
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	
	static Float:fPos[3];
	GetClientAbsOrigin(iClient, fPos);
	TeleportEntity(iEnt, fPos, NULL_VECTOR, NULL_VECTOR);
	
	SetEntProp(iEnt, Prop_Data, "m_CollisionGroup", 0x0004);
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", Float:{0.0, 0.0, 0.0});
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", Float:{0.0, 0.0, 0.0});
	 
	SetVariantString("!activator");
	AcceptEntityInput(iEnt, "SetParent", iSurvivorLegs);
	 
	SetVariantString("!activator");
	AcceptEntityInput(iEnt, "SetAttached", iSurvivorLegs);
	AcceptEntityInput(iEnt, "TurnOn");
	
	AcceptEntityInput(iEnt, "DisableCollision");
	AcceptEntityInput(iEnt, "DisableShadow");
	
	SetEntityRenderMode(iSurvivorLegs, RENDER_NONE);
	
	SetEntProp(iSurvivorLegs, Prop_Send, "m_nMinGPULevel", 1);
	SetEntProp(iSurvivorLegs, Prop_Send, "m_nMaxGPULevel", 1);
	
	iAttachedRef[iSurvivorLegs] = EntIndexToEntRef(iEnt);
	iAttachedOwner[iEnt] = GetClientUserId(iClient);
		
	SDKHook(iEnt, SDKHook_SetTransmit, HideOverlayModel);
	
}

public Action:HideModel(iEntity, iClient)
{
	if(IsFakeClient(iClient))
		return Plugin_Continue;
	
	static iOwner;
	iOwner = GetClientOfUserId(iEntOwner[iEntity]);
	
	if(iOwner < 1 || !IsClientInGame(iOwner))
	return Plugin_Continue;
	
	if(iOwner != iClient)
		return Plugin_Handled;
	
	if(ShouldHideLegs(iClient))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action:HideOverlayModel(iEntity, iClient)
{
	if(IsFakeClient(iClient))
		return Plugin_Continue;
	
	static iOwner;
	iOwner = GetClientOfUserId(iAttachedOwner[iEntity]);
	
	if(iOwner < 1 || !IsClientInGame(iOwner))
	return Plugin_Continue;
	
	if(iOwner != iClient)
		return Plugin_Handled;
	
	if(ShouldHideLegs(iClient))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public TP_OnThirdPersonChanged(iClient, bool:bIsThirdPerson)
{
	bThirdPerson[iClient] = bIsThirdPerson;
}

public ePlayerSpawn(Handle:hEvent, const String:sEventName[], bool:bDontBroadcast)
{	
	static iClient;
	iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(iClient < 1 || iClient > MaxClients)
		return;
	
	if(!IsClientInGame(iClient) || IsFakeClient(iClient) || !IsPlayerAlive(iClient) || GetClientTeam(iClient) != 2)
		return;
	
	new iEntity = iEntRef[iClient];
	if(IsValidEntRef(iEntity))
	{
		AcceptEntityInput(iEntity, "kill");
		iEntRef[iClient] = -1;
	}
	RequestFrame(NextFrame, GetClientUserId(iClient));
}

public NextFrame(any:iUserID)
{
	static iClient;
	iClient = GetClientOfUserId(iUserID);
	
	if(iClient < 1 || iClient > MaxClients)
		return;
	
	if(!IsClientInGame(iClient) || GetClientTeam(iClient) != 2 || !IsPlayerAlive(iClient))
		return;
	
	AttachLegs(iClient);
}

public eTeamChange(Handle:hEvent, const String:sEventName[], bool:bDontBroadcast)
{
	static iClient;
	iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient))
		return;
	
	new iEntity = iEntRef[iClient];
	if(!IsValidEntRef(iEntity))
		return;
	
	AcceptEntityInput(iEntity, "kill");
	iEntRef[iClient] = -1;
}

public ePlayerDeath(Handle:hEvent, const String:sEventName[], bool:bDontBroadcast)
{
	static iVictim;
	iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(iVictim < 1 || iVictim > MaxClients)
		return;
	
	if(!IsClientInGame(iVictim) || IsFakeClient(iVictim) || GetClientTeam(iVictim) != 2)
		return;
	
	new iEntity = iEntRef[iVictim];
	if(!IsValidEntRef(iEntity))
		return;
	
	AcceptEntityInput(iEntity, "kill");
	iEntRef[iVictim] = -1;
}

public Hook_OnPostThinkPost(iClient)
{
	if(!IsPlayerAlive(iClient) || GetClientTeam(iClient) != 2) 
		return;
	
	static iEntity;
	iEntity = EntRefToEntIndex(iEntRef[iClient]);
	
	if(!IsValidEntRef(iEntity))
		return;
	
	static iModelIndex[MAXPLAYERS+1] = {0, ...};		
	if(iModelIndex[iClient] != GetEntProp(iClient, Prop_Data, "m_nModelIndex", 2))
	{	
		//LMC Reattachbase
		iModelIndex[iClient] = GetEntProp(iClient, Prop_Data, "m_nModelIndex", 2);
		AttachLegs(iClient);
	}
	
	
	SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", GetEntPropFloat(iClient, Prop_Send, "m_flPlaybackRate"));
	SetEntProp(iEntity, Prop_Send, "m_nSequence", CheckAnimation(iClient, GetEntProp(iClient, Prop_Send, "m_nSequence", 2)), 2);
	
	#if DEBUG
		PrintToChat(iClient, "Client(m_nSquence)[%i] Legs(m_nSequence)[%i]", GetEntProp(iClient, Prop_Send, "m_nSequence", 2), GetEntProp(iEntity, Prop_Send, "m_nSequence", 2));
	#endif
	
	SetEntPropFloat(iEntity, Prop_Send, "m_flPoseParameter", -40.0, 0);
	SetEntPropFloat(iEntity, Prop_Send, "m_flCycle", GetEntPropFloat(iClient, Prop_Send, "m_flCycle"));
	
	static i;
	for (i = 1; i < 23; i++)
		SetEntPropFloat(iEntity, Prop_Send, "m_flPoseParameter", GetEntPropFloat(iClient, Prop_Send, "m_flPoseParameter", i), i);//credit to death chaos for animating legs
	
	if(GetEntProp(iClient, Prop_Send, "m_clientIntensity") < 1)
		SetEntProp(iClient, Prop_Send, "m_clientIntensity", 1);
		
	
	if(bTeleported[iClient])
	{
		bTeleported[iClient] = false;
		TeleportEntity(iEntity, Float:{0.0, 0.0, -20.0}, NULL_VECTOR, NULL_VECTOR);
	}
	
}

public OnClientPutInServer(iClient)
{
	if(IsFakeClient(iClient))
		return;
		
	SDKHook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
}

public OnClientDisconnect(iClient)
{
	if(!IsFakeClient(iClient))
	{
		SDKUnhook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
	}
	
	if(!IsValidEntRef(iEntRef[iClient]))
		return;
	
	AcceptEntityInput(iEntRef[iClient], "kill");
	iEntRef[iClient] = -1;
}

public eRoundStart(Handle:hEvent, const String:sEventName[], bool:bDontBroadcast)
{
	for(new i = 1; i <= MaxClients; i++)
		iEntRef[i] = -1;
}

public LMC_OnClientModelApplied(iClient, iEntity, const String:sModel[PLATFORM_MAX_PATH], bool:bBaseReattach)
{
	if(!IsClientInGame(iClient) || GetClientTeam(iClient) != 2)
		return;
	
	AttachOverlayLegs(iClient, bBaseReattach);
}

public LMC_OnClientModelChanged(iClient, iEntity, const String:sModel[PLATFORM_MAX_PATH])
{
	if(!IsClientInGame(iClient) || GetClientTeam(iClient) != 2)
		return;
	
	AttachOverlayLegs(iClient, false);
}

public LMC_OnClientModelDestroyed(iClient, iEntity)
{
	if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient) || GetClientTeam(iClient) != 2)
		return;
	
	static iSurvivorLegs;
	iSurvivorLegs = EntRefToEntIndex(iEntRef[iClient]);
	
	if(!IsValidEntRef(iSurvivorLegs))
		return;
	
	static iOverlayLegs;
	iOverlayLegs = EntRefToEntIndex(iAttachedRef[iSurvivorLegs]);
	
	if(!IsValidEntRef(iOverlayLegs))
		return;
	
	SetEntityRenderMode(iSurvivorLegs, RENDER_NORMAL);
	SetEntProp(iSurvivorLegs, Prop_Send, "m_nMinGPULevel", 0);
	SetEntProp(iSurvivorLegs, Prop_Send, "m_nMaxGPULevel", 0);
	
	AcceptEntityInput(iOverlayLegs, "Kill");
}

public Action:OnPlayerRunCmd(iClient, &buttons)
{
	if(GetClientTeam(iClient) != 2 || !IsPlayerAlive(iClient) || IsFakeClient(iClient))
		return Plugin_Continue;
	
	//pickup weapons ect fix
	if((buttons & IN_USE) && !bTeleported[iClient])
	{
		static iSurvivorLegs;
		iSurvivorLegs = EntRefToEntIndex(iEntRef[iClient]);
		if(!IsValidEntRef(iSurvivorLegs))
			return Plugin_Continue;
		
		bTeleported[iClient] = true;
		TeleportEntity(iSurvivorLegs, Float:{0.0, 0.0, -300.0}, NULL_VECTOR, NULL_VECTOR);
	}
	
	return Plugin_Continue;
}

static bool:IsValidEntRef(iEnt)
{
	return (iEnt != 0 && EntRefToEntIndex(iEnt) != INVALID_ENT_REFERENCE);
}

static bool:ShouldHideLegs(iClient) 
{
	if(bThirdPerson[iClient])
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_hZoomOwner") == iClient)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_hViewEntity") > 0)
		return true;
	if(GetEntPropFloat(iClient, Prop_Send, "m_TimeForceExternalView") > GetGameTime())
		return true;
	if(GetEntProp(iClient, Prop_Send, "m_iObserverMode") == 1)
		return true;
	if(GetEntProp(iClient, Prop_Send, "m_isIncapacitated") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_jockeyAttacker") > 0)
		return true; 
	if(GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_reviveTarget") > 0)
		return true;  
	if(GetEntPropFloat(iClient, Prop_Send, "m_staggerTimer", 1) > -1.0)
		return true; 
	switch(GetEntProp(iClient, Prop_Send, "m_iCurrentUseAction"))
	{
		case 1:
		{
			static iTarget;
			iTarget = GetEntPropEnt(iClient, Prop_Send, "m_useActionTarget");
			
			if(iTarget == GetEntPropEnt(iClient, Prop_Send, "m_useActionOwner"))
				return true;
			else if(iTarget != iClient)
				return true;
		}
		case 4, 6, 7, 8, 9, 10:
			return true;
	}
	
	static String:sModel[31];
	GetEntPropString(iClient, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	
	switch(sModel[29])
	{
		case 'b'://nick
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 626, 625, 624, 623, 622, 621, 661, 662, 664, 665, 666, 667, 668, 670, 671, 672, 673, 674, 620, 680, 643, 630, 629, 628, 627, 619, 616, 605, 606:
					return true;
			}
		}
		case 'd'://rochelle
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 674, 678, 679, 630, 631, 632, 633, 634, 668, 677, 681, 680, 676, 675, 673, 672, 671, 670, 687, 629, 651, 638, 637, 636, 635, 616, 615, 614:
					return true;
			}
		}
		case 'c'://coach
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 656, 622, 623, 624, 625, 626, 663, 662, 661, 660, 659, 658, 657, 654, 653, 652, 651, 621, 620, 669, 637, 630, 629, 628, 627, 615, 607, 606:
					return true;
			}
		}
		case 'h'://ellis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 625, 675, 626, 627, 628, 629, 630, 631, 678, 677, 676, 575, 674, 673, 672, 671, 670, 669, 668, 667, 666, 665, 684, 635, 634, 633, 632, 624, 621, 611, 610:
					return true;
			}
		}
		case 'v'://bill
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 528, 759, 763, 764, 529, 530, 531, 532, 533, 534, 753, 676, 675, 761, 758, 757, 756, 755, 754, 527, 772, 762, 551, 538, 537, 536, 535, 522, 515, 514:
					return true;
			}
		}
		case 'n'://zoey
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 537, 819, 823, 824, 538, 539, 540, 541, 542, 543, 813, 828, 825, 822, 821, 820, 818, 817, 816, 815, 814, 536, 809, 554, 547, 546, 545, 544, 572, 514, 515:
					return true;
			}
		}
		case 'e'://francis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 532, 533, 534, 535, 536, 537, 769, 768, 767, 766, 765, 764, 763, 762, 761, 760, 759, 758, 757, 756, 531, 530, 775, 554, 541, 540, 539, 538, 525, 518, 517:
					return true;
			}
		}
		case 'a'://louis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 529, 530, 531, 532, 533, 534, 766, 765, 764, 763, 762, 761, 760, 759, 758, 757, 756, 755, 754, 753, 527, 772, 528, 551, 538, 537, 536, 535, 522, 514, 515:
					return true;
			}
		}
		case 'w'://adawong
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 674, 678, 679, 630, 631, 632, 633, 634, 668, 677, 681, 680, 676, 675, 673, 672, 671, 670, 687, 629, 651, 638, 637, 636, 635, 616, 615, 614:
					return true;
			}
		}
	}
	
	return false;
}

static CheckAnimation(iClient, iSequence)
{
	static String:sModel[31];
	GetEntPropString(iClient, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	
	switch(sModel[29])
	{
		case 'b'://nick
		{
			switch(iSequence)
			{
				case 42, 39, 732, 43, 712, 45, 44, 684, 24, 27, 458:
					return 7;
				case 232, 244, 241, 744, 250, 724, 253, 247, 700, 226, 299, 463, 229:
					return 214;
				case 151, 461, 154, 697, 172, 178, 718, 175, 166, 741, 169, 136, 148:
					return 130;
				case 595, 598, 597, 592, 591, 759, 760, 586, 587, 731, 582, 580, 578, 708, 599, 600: 
					return 575;
				case 52, 733, 58, 59, 61, 713, 62, 60, 685, 53, 54, 459:
					return 46;
				case 738, 202, 199, 208, 211, 721, 205, 694, 184, 187, 462:
					return 133;
				case 95, 121, 103, 127, 99, 735, 100, 715, 97, 98, 691, 109, 112, 460:
					return 94;
				case 315, 319, 320, 316, 321, 322, 752, 323, 324, 726, 326, 325, 702, 317, 318, 465:
					return 313;
				case 296, 305, 306, 302, 307, 311, 725, 312, 310, 701, 303, 304, 464:
					return 301;
			}
		}
		case 'd'://rochelle
		{
			switch(iSequence)
			{
				case 229, 311, 226, 253, 256, 731, 259, 707, 241, 238, 477, 265, 232, 751, 262:
					return 232;
				case 11, 50, 719, 51, 47, 691, 26, 29, 472, 41, 44, 739:
					return 7;
				case 608, 609, 715, 591, 587, 589, 738, 596, 600, 601, 766, 767:
					return 606;
				case 54, 58, 57, 52, 65, 64, 67, 720, 68, 66, 692, 59, 60, 473, 740:
					return 56;
				case 148, 310, 211, 214, 220, 728, 223, 217, 701, 199, 196, 476, 745: 
					return 145;
				case 163, 160, 475, 704, 184, 181, 187, 725, 178, 175, 154, 151, 748, 316, 478, 315, 708, 323, 322, 324, 732, 758, 314, 308, 317, 312, 318, 313, 319:
					return 142;
				case 111, 106, 138, 135, 742, 139, 722, 136, 137, 698, 117, 120, 474:
					return 126;
				case 329, 479, 709, 336, 337, 338, 733, 759, 335, 334, 326, 327:
					return 333;
			}
		}
		case 'c'://coach
		{
			switch(iSequence)
			{
				case 202, 218, 733, 236, 215, 212, 713, 209, 206, 689, 221, 224, 466:
					return 203;
				case 36, 721, 13, 11, 701, 18, 10, 673, 15, 27, 461:
					return 16;
				case 730, 141, 198, 707, 192, 186, 686, 216, 129, 464, 292, 299, 302, 306, 303, 286, 298, 714, 297, 296, 690, 300, 301, 467:
					return 123;
				case 748, 749, 593, 592, 588, 587, 720, 581, 579, 697, 601, 600:
					return 233;
				case 41, 40, 38, 46, 45, 48, 722, 39, 53, 44, 702, 43, 42, 674, 49, 50, 462:
					return 51;
				case 37:
				{
					SetEntProp(iClient, Prop_Send, "m_nSequence", 40, 2);
					return 51;
				}
				case 144, 147, 159, 279, 183, 150, 165, 177, 727, 180, 168, 710, 174, 171, 683, 153, 156, 465:
					return 162;
				case 295, 309, 305, 313, 283, 289, 741, 314, 308, 315, 715, 317, 316, 691, 310, 311, 468:
					return 312;
				case 87, 83, 92, 724, 113, 84, 704, 89, 85, 680, 98, 101, 463:
					return 104;
			}
		}
		case 'h'://ellis
		{
			switch(iSequence)
			{
				case 214, 232, 223, 748, 211, 235, 241, 728, 244, 238, 704, 226, 229, 466:
					return 205;
				case 139, 745, 166, 133, 172, 722, 175, 169, 701, 154, 157, 464, 298, 300, 297, 296, 304, 301, 305, 755, 308, 729, 309, 307, 705, 302, 303, 467:
					return 121;
				case 736, 9, 36, 14, 716, 40, 13, 688, 24, 27, 461, 7:
					return 11;
				case 763, 764, 591, 592, 597, 596, 585, 735, 587, 583, 712, 605, 604:
					return 599;
				case 41, 43, 49, 50, 737, 45, 55, 56, 717, 57, 46, 689, 51, 52, 462:
					return 53;
				case 142, 124, 295, 148, 742, 136, 193, 725, 202, 196, 698, 181, 184, 465:
					return 187;
				case 314, 312, 311, 310, 318, 315, 756, 320, 313, 321, 730, 323, 322, 706, 316, 317, 468:
					return 319;
				case 86, 87, 89, 85, 110, 95, 739, 116, 88, 91, 719, 92, 90, 695, 101, 104, 463:
					return 107;
			}
		}
		case 'v'://bill
		{
			switch(iSequence)
			{
				case 200, 640, 197, 245, 182, 836, 206, 203, 643, 816, 596, 617, 792, 188, 191, 378: 
					return 185;
				case 824, 42, 39, 564, 804, 584, 605, 776, 24, 27, 373:
					return 18;
				case 137, 634, 833, 146, 143, 637, 810, 593, 614, 789, 131, 128, 376:
					return 243;
				case 672, 496, 495, 501, 852, 851, 823, 603, 624, 800, 508, 509:
					return 489;
				case 651, 262, 261, 265, 264, 844, 653, 818, 598, 619, 794, 259, 260, 380, 257:
					return 256;
				case 580, 105, 90, 99, 827, 114, 111, 625, 807, 587, 608, 783, 93, 96, 375:
					return 84;
				case 246, 247, 251, 248, 252, 650, 843, 652, 817, 597, 618, 793, 249, 250, 379:
					return 253;
				case 830, 176, 173, 628, 813, 590, 611, 786, 158, 161:
					return 149;
				case 572, 46, 47, 54, 53, 825, 571, 805, 585, 606, 777, 48, 49, 374:
					return 45;
			}
		}
		case 'n'://zoey
		{
			switch(iSequence)
			{
				case 24, 218, 783:
					return 212;
				case 508, 509, 796:
					return 495;
				case 185, 179, 182, 188, 777, 200, 584, 719, 649, 679, 751:
					return 191;
				case 63, 66, 54:
					return 60;
				case 27, 771:
					return 21;
				case 625:
					return 268;
				case 631, 413, 78:
					return 269;
				case 709:
					return 15;
				case 730:
					return 492;
				case 795:
					return 494;
				case 39, 42:
					return 9;
				case 227, 230:
					return 203;
				case 197, 416:
					return 173;
				case 497, 498:
					return 504;
				case 412:
					return 21;
				case 158, 780, 167, 587, 682, 652, 772, 722, 748:
					return 161;
				case 170:
					return 143;
				case 500, 501:
					return 505;
				case 571, 673, 643, 742:
					return 30;
				case 590, 613, 725, 685, 665, 655, 754:
					return 221;
				case 594, 689, 659, 745, 758:
					return 502;
				case 644, 710, 674, 743, 579:
					return 69;
				case 280, 282, 286, 639, 287, 592, 756, 657, 687, 727, 284, 283, 281, 288, 289, 791:
					return 285;
				case 581:
				{
					SetEntProp(iClient, Prop_Send, "m_nSequence", 646, 2);
					return 285;
				}
				case 114, 619, 716, 676, 646, 135, 138, 774:
					return 123;
				case 276, 270, 271, 275, 638, 277, 755, 656, 591, 686, 726, 724, 274, 790:
					return 272;
			}
		}
		case 'e'://francis
		{
			switch(iSequence)
			{
				case 206, 643, 839, 212, 215, 646, 819, 599, 620, 795, 197, 200, 382:
					return 11;
				case 48, 827, 51, 567, 807, 587, 608, 779, 33, 36, 377, 570, 42:
					return 5;
				case 503, 504, 855, 854, 499, 498, 675, 826, 606, 627, 803, 512:
					return 492;
				case 836, 152, 155, 640, 813, 596, 617, 792, 137, 140, 380:
					return 252;
				case 185, 833, 182, 631, 816, 593, 614, 789, 167, 170, 381: 
					return 253;
				case 824, 828, 63, 625, 574, 808, 588, 609, 780, 57, 58, 378:
					return 54;
				case 265, 269, 270, 654, 847, 272, 273, 656, 821, 601, 622, 797, 267, 268, 384:  
					return 271;
				case 653, 260, 259, 255, 254, 846, 655, 820, 600, 621, 796, 257, 258, 383:
					return 261;
				case 583, 830, 123, 120, 628, 810, 590, 611, 786, 105, 102, 379: 
					return 99;
			}
		}
		case 'a'://louis
		{
			switch(iSequence)
			{
				case 564, 804, 584, 605, 776, 30, 33, 374, 48, 45, 824:
					return 19;
				case 209, 212, 836, 643, 816, 596, 617, 792, 194, 379, 197:
					return 188;
				case 501, 852, 851, 495, 672, 823, 603, 624, 800, 508, 409, 509, 500, 496:
					return 507;
				case 149, 152, 833, 637, 810, 593, 614, 789, 134, 137, 377:
					return 128;
				case 53:
					return 52;
				case 59, 60, 825, 571, 805, 585, 606, 777, 54, 55, 375:
					return 50;
				case 179, 182, 830, 628, 813, 590, 611, 786, 164, 167, 378: 
					return 158;
				case 580, 111, 105, 93, 90, 117, 120, 827, 625, 807, 587, 608, 783, 99, 102, 376:
					return 96;
				case 263, 267, 268, 651, 269, 270, 271, 844, 653, 818, 598, 619, 794, 265, 266, 381:
					return 264;
				case 650, 258, 254, 257, 252, 253, 843, 652, 817, 597, 618, 793, 255, 256, 380:
					return 259;
				
			}
		}
		case 'w'://adawong
		{
			switch(iSequence)
			{
				case 229, 311, 226, 253, 256, 731, 259, 707, 241, 238, 477, 265, 232, 751, 262:
					return 232;
				case 11, 50, 719, 51, 47, 691, 26, 29, 472, 41, 44, 739:
					return 7;
				case 608, 609, 715, 591, 587, 589, 738, 596, 600, 601, 766, 767:
					return 606;
				case 54, 58, 57, 52, 65, 64, 67, 720, 68, 66, 692, 59, 60, 473, 740:
					return 56;
				case 148, 310, 211, 214, 220, 728, 223, 217, 701, 199, 196, 476, 745: 
					return 145;
				case 163, 160, 475, 704, 184, 181, 187, 725, 178, 175, 154, 151, 748, 316, 478, 315, 708, 323, 322, 324, 732, 758, 314, 308, 317, 312, 318, 313, 319:
					return 142;
				case 111, 106, 138, 135, 742, 139, 722, 136, 137, 698, 117, 120, 474:
					return 126;
				case 329, 479, 709, 336, 337, 338, 733, 759, 335, 334, 326, 327:
					return 333;
			}
		}
	}
	return iSequence;
}