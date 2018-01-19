#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <dice>
#include <fun>

#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
#endif

#define PSTRING_MAX 33
#define TASK_HUDINFO 446999
#define TASK_DELAY 234776
#define TASK_REMOVEGLOW 748339

enum _:Items
{
	Plugin[64],
	Name[32],
	Type,
	ChatMessage[32],
	StartFunc[32],
	EndFunc[32],
	HudMessage[32],
	MinDuration,
	MaxDuration,
	bool:Glow
}

new g_eItem[Items]
new Array:g_aItems
new Array:g_aCvars
new Trie:g_tDisabled
new Trie:g_tCvars
new const g_szAll[] = "#all_maps"
new const g_szNone[] = "#none"

enum _:Settings
{
	bool:DICE_ENABLED,
	CHAT_PREFIX[32],
	ROLL_INTERVAL,
	Float:ROUND_START_DELAY,
	DICE_TEAM,
	DICE_FLAG,
	DICE_COST,
	DICE_LEAVE_SOUND[128],
	bool:GLOW_ENABLED,
	GLOW_ALPHA,
	GLOW_DURATION,
	Float:DICE_COOLDOWN,
	Float:HUD_X,
	Float:HUD_Y,
	HUD_EFFECTS,
	Float:HUD_FXTIME,
	Float:HUD_HOLDTIME,
	Float:HUD_FADEINTIME,
	Float:HUD_FADEOUTTIME,
	bool:DHUD_ENABLED,
	Float:DHUD_X,
	Float:DHUD_Y,
	DHUD_EFFECTS,
	Float:DHUD_FXTIME,
	Float:DHUD_HOLDTIME,
	Float:DHUD_FADEINTIME,
	Float:DHUD_FADEOUTTIME,
	DICE_LOG
}

new g_eSettings[Settings]

new bool:g_blFreeze,
	bool:g_blActive,
	bool:g_blDelayed,
	bool:g_blCstrike

new g_szIP[PSTRING_MAX][32],
	g_szHudLang[32],
	g_iLastRoll[PSTRING_MAX],
	g_iCurrentUser,
	g_iHudTime,
	g_iObject,
	g_iCurrentItem,
	g_iItems
	
new Trie:g_tLastRolls,
	g_szMap[32],
	g_msgSayText
	
new g_szConfigFolder[256],
	g_szConfigFile[256]

public plugin_init()
{
	register_plugin("D.I.C.E.", PLUGIN_VERSION, "OciXCrom")
	register_cvar("@D.I.C.E.", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_dictionary("DICE.txt")
	
	register_concmd("dice_roll", "DiceRoll", ADMIN_RCON, "<nick|#userid>")
	register_srvcmd("dice_reload", "ReadConfigFile")
	
	register_logevent("OnRoundStart", 2, "0=World triggered", "1=Round_Start")
	register_logevent("OnRoundEnd", 2, "1=Round_End")
	
	g_blFreeze = true
	g_blCstrike = cstrike_running() == 1 ? true : false
	
	g_aItems = ArrayCreate(Items)
	g_aCvars = ArrayCreate(32)
	g_tLastRolls = TrieCreate()
	g_tCvars = TrieCreate()
	g_iObject = CreateHudSyncObj()
	g_msgSayText = get_user_msgid("SayText")
}

public plugin_precache()
{
	get_configsdir(g_szConfigFolder, charsmax(g_szConfigFolder))
	get_mapname(g_szMap, charsmax(g_szMap))
	g_tDisabled = TrieCreate()
	ReadMainFile()
}

public plugin_cfg()
{
	formatex(g_szConfigFile, charsmax(g_szConfigFile), "%s/DICE.cfg", g_szConfigFolder)
	ReadConfigFile()
}

public DiceRoll(id, iLevel, iCid)
{
	if(!cmd_access(id, iLevel, iCid, 2))
		return PLUGIN_HANDLED
		
	new szArg[32]
	read_argv(1, szArg, charsmax(szArg))
	
	new iPlayer = cmd_target(id, szArg, CMDTARGET_OBEY_IMMUNITY|CMDTARGET_ALLOW_SELF)
	
	if(!iPlayer)
		return PLUGIN_HANDLED
		
	new szName[2][32]
	get_user_name(id, szName[0], charsmax(szName[]))
	get_user_name(iPlayer, szName[1], charsmax(szName[]))
	
	ColorChat(0, "%L", LANG_PLAYER, "DICE_FORCE", szName[0], szName[1])
	log_clear("%L", LANG_SERVER, "DICE_FORCE", szName[0], szName[1])
	
	RollTheDice(iPlayer)
	return PLUGIN_HANDLED
}

public plugin_end()
{
	WriteConfigFile()
	ArrayDestroy(g_aItems)
	ArrayDestroy(g_aCvars)
	TrieDestroy(g_tDisabled)
	TrieDestroy(g_tLastRolls)
	TrieDestroy(g_tCvars)
}

public ReadConfigFile()
{
	server_cmd("exec %s", g_szConfigFile)
	server_exec()
	log_amx("%L", LANG_SERVER, "DICE_LOADED")
}

WriteConfigFile()
{
	delete_file(g_szConfigFile)
	
	new iFile = fopen(g_szConfigFile, "wt")
	new szCvar[32], szValue[32]
	
	for(new i; i < ArraySize(g_aCvars); i++)
	{
		ArrayGetString(g_aCvars, i, szCvar, charsmax(szCvar))
		get_cvar_string(szCvar, szValue, charsmax(szValue))
		fprintf(iFile, "%s ^"%s^"^n", szCvar, szValue)
	}
	
	fclose(iFile)
}

ReadMainFile()
{
	new g_szConfigFolder[256], szFilename[256]
	get_configsdir(g_szConfigFolder, charsmax(g_szConfigFolder))
	formatex(szFilename, charsmax(szFilename), "%s/DICE.ini", g_szConfigFolder)
	
	if(!file_size(szFilename))
	{
		pause("ad")
		log_amx("Configuration file (%s) is empty. The plugin is paused.", szFilename)
		return
	}
	
	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new szData[256], szKey[32], szValue[224], iSize
		new bool:blRead
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)
			
			switch(szData[0])
			{
				case EOS, ';': continue
				case '[':
				{
					iSize = strlen(szData)
					
					if(szData[iSize - 1] == ']')
					{
						szData[0] = ' '
						szData[iSize - 1] = ' '
						trim(szData)
						
						if(contain(szData, "*") != -1)
						{
							strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '*')
							copy(szValue, strlen(szKey), g_szMap)
							blRead = equal(szValue, szKey) ? true : false
						}
						else
							blRead = equal(szData, g_szAll) || equali(szData, g_szMap)
					}
					else continue
				}
				default:
				{
					if(!blRead)
						continue
						
					strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
					trim(szKey); trim(szValue)
					
					if(is_blank(szValue))
						continue
					
					if(equal(szKey, "DICE_ENABLED"))
						g_eSettings[DICE_ENABLED] = str_to_num(szValue) == 1
					else if(equal(szKey, "CHAT_PREFIX"))
						copy(g_eSettings[CHAT_PREFIX], charsmax(g_eSettings[CHAT_PREFIX]), szValue)
					else if(equal(szKey, "ROLL_INTERVAL"))
						g_eSettings[ROLL_INTERVAL] = clamp(str_to_num(szValue), 0, 2400)
					else if(equal(szKey, "ROUND_START_DELAY"))
						g_eSettings[ROUND_START_DELAY] = _:float(clamp(str_to_num(szValue), 0, 300))
					else if(equal(szKey, "SAY_COMMANDS"))
					{
						while(szValue[0] != 0 && strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ','))
						{
							trim(szKey); trim(szValue)
							formatex(szData, charsmax(szData), "say %s", szKey)
							register_clcmd(szData, "RollTheDice")
							formatex(szData, charsmax(szData), "say_team %s", szKey)
							register_clcmd(szData, "RollTheDice")
						}
					}
					else if(equal(szKey, "CONSOLE_COMMANDS"))
					{
						while(szValue[0] != 0 && strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ','))
						{
							trim(szKey); trim(szValue)
							register_clcmd(szKey, "RollTheDice")
						}
					}
					else if(equal(szKey, "DISABLED_ITEMS"))
					{
						while(szValue[0] != 0 && strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ','))
						{
							trim(szKey); trim(szValue)
							
							if(equal(szKey, g_szNone))
								break
								
							TrieSetCell(g_tDisabled, szKey, 1)
						}
					}
					else if(equal(szKey, "DICE_TEAM"))
						g_eSettings[DICE_TEAM] = clamp(str_to_num(szValue), 0, 3)
					else if(equal(szKey, "DICE_FLAG"))
						g_eSettings[DICE_FLAG] = equal(szValue, "0") ? 0 : read_flags(szValue)
					else if(equal(szKey, "DICE_COST"))
						g_eSettings[DICE_COST] = clamp(str_to_num(szValue), 0, 16000)
					else if(equal(szKey, "DICE_LEAVE_SOUND"))
					{
						if(equal(szValue, g_szNone))
							continue
						
						copy(g_eSettings[DICE_LEAVE_SOUND], charsmax(g_eSettings[DICE_LEAVE_SOUND]), szValue)
						precache_sound(szValue)
					}
					else if(equal(szKey, "GLOW_ENABLED"))
						g_eSettings[GLOW_ENABLED] = str_to_num(szValue) == 1
					else if(equal(szKey, "GLOW_ALPHA"))
						g_eSettings[GLOW_ALPHA] = clamp(str_to_num(szValue), 0, 255)
					else if(equal(szKey, "GLOW_DURATION"))
						g_eSettings[GLOW_DURATION] = clamp(str_to_num(szValue), 0, 30)
					else if(equal(szKey, "DICE_COOLDOWN"))
						g_eSettings[DICE_COOLDOWN] = _:floatclamp(str_to_float(szValue), 0.1, 30.0)
					else if(equal(szKey, "HUD_X"))
						g_eSettings[HUD_X] = _:floatclamp(str_to_float(szValue), -1.0, 1.0)
					else if(equal(szKey, "HUD_Y"))
						g_eSettings[HUD_Y] = _:floatclamp(str_to_float(szValue), -1.0, 1.0)
					else if(equal(szKey, "HUD_EFFECTS"))
						g_eSettings[HUD_EFFECTS] = clamp(str_to_num(szValue), 0, 2)
					else if(equal(szKey, "HUD_FXTIME"))
						g_eSettings[HUD_FXTIME] = _:floatclamp(str_to_float(szValue), 0.01, 30.0)
					else if(equal(szKey, "HUD_HOLDTIME"))
						g_eSettings[HUD_HOLDTIME] = _:floatclamp(str_to_float(szValue), 1.0, 30.0)
					else if(equal(szKey, "HUD_FADEINTIME"))
						g_eSettings[HUD_FADEINTIME] = _:floatclamp(str_to_float(szValue), 0.01, 30.0)
					else if(equal(szKey, "HUD_FADEOUTTIME"))
						g_eSettings[HUD_FADEOUTTIME] = _:floatclamp(str_to_float(szValue), 0.01, 30.0)
					else if(equal(szKey, "DHUD_ENABLED"))
						g_eSettings[DHUD_ENABLED] = str_to_num(szValue) == 1
					else if(equal(szKey, "DHUD_X"))
						g_eSettings[DHUD_X] = _:floatclamp(str_to_float(szValue), -1.0, 1.0)
					else if(equal(szKey, "DHUD_Y"))
						g_eSettings[DHUD_Y] = _:floatclamp(str_to_float(szValue), -1.0, 1.0)
					else if(equal(szKey, "DHUD_EFFECTS"))
						g_eSettings[DHUD_EFFECTS] = clamp(str_to_num(szValue), 0, 2)
					else if(equal(szKey, "DHUD_FXTIME"))
						g_eSettings[DHUD_FXTIME] = _:floatclamp(str_to_float(szValue), 0.01, 30.0)
					else if(equal(szKey, "DHUD_HOLDTIME"))
						g_eSettings[DHUD_HOLDTIME] = _:floatclamp(str_to_float(szValue), 1.0, 30.0)
					else if(equal(szKey, "DHUD_FADEINTIME"))
						g_eSettings[DHUD_FADEINTIME] = _:floatclamp(str_to_float(szValue), 0.01, 30.0)
					else if(equal(szKey, "DHUD_FADEOUTTIME"))
						g_eSettings[DHUD_FADEOUTTIME] = _:floatclamp(str_to_float(szValue), 0.01, 30.0)
					else if(equal(szKey, "DICE_LOG"))
						g_eSettings[DICE_LOG] = clamp(str_to_num(szValue), 0, 1)
				}
			}
		}
		
		fclose(iFilePointer)
		
		if(g_eSettings[ROUND_START_DELAY] > 0)
			g_blDelayed = true
	}
}

public client_putinserver(id)
{
	g_iLastRoll[id] = 0
	get_user_ip(id, g_szIP[id], charsmax(g_szIP[]))
	
	if(TrieKeyExists(g_tLastRolls, g_szIP[id]))
		TrieGetCell(g_tLastRolls, g_szIP[id], g_iLastRoll[id])
}

public client_disconnect(id)
	TrieSetCell(g_tLastRolls, g_szIP[id], g_iLastRoll[id])
	
public OnRoundStart()
{
	g_blFreeze = false
	
	if(g_eSettings[ROUND_START_DELAY] > 0)
	{
		if(task_exists(TASK_DELAY))
			remove_task(TASK_DELAY)
		else
			set_task(g_eSettings[ROUND_START_DELAY], "RemoveDelay", TASK_DELAY)
	}
}

public OnRoundEnd()
{
	g_blFreeze = true
	
	if(g_eSettings[ROUND_START_DELAY] > 0)
		g_blDelayed = true
}

public RemoveDelay()
{
	g_blDelayed = false
	ColorChat(0, "%L", LANG_PLAYER, "DICE_DELAY_OVER")
}

public RollTheDice(id)
{	
	if(!g_eSettings[DICE_ENABLED])
		ColorChat(id, "%L", id, "DICE_CANTROLL_DISABLED")
	else if(g_iItems == 0)
		ColorChat(id, "%L", id, "DICE_CANTROLL_NOITEMS")
	else if(g_eSettings[DICE_FLAG] != 0 && !(get_user_flags(id) & g_eSettings[DICE_FLAG]))
		ColorChat(id, "%L", id, "DICE_CANTROLL_FLAG")
	else if(!is_user_alive(id))
		ColorChat(id, "%L", id, "DICE_CANTROLL_DEAD")
	else if(g_eSettings[DICE_TEAM] != 0 && get_user_team(id) != g_eSettings[DICE_TEAM])
		ColorChat(id, "%L", id, "DICE_CANTROLL_TEAM")
	else if(g_blFreeze)
		ColorChat(id, "%L", id, "DICE_CANTROLL_FREEZE")
	else if(g_blDelayed)
		ColorChat(id, "%L", id, "DICE_CANTROLL_DELAY", floatround(g_eSettings[ROUND_START_DELAY]))
	else if(g_blCstrike && g_eSettings[DICE_COST] > 0 && cs_get_user_money(id) < g_eSettings[DICE_COST])
		ColorChat(id, "%L", id, "DICE_CANTROLL_COST", g_eSettings[DICE_COST])
	else
	{
		new iTime = get_systime(),
			iRemaining = g_iLastRoll[id] - iTime
		
		if(iRemaining > 0)
			ColorChat(id, "%L", id, "DICE_CANTROLL_INTERVAL", iRemaining)
		else if(g_blActive)
		{
			if(is_user_connected(g_iCurrentUser))
			{
				new szName[32]
				get_user_name(g_iCurrentUser, szName, charsmax(szName))
				ColorChat(id, "%L", id, "DICE_CANTROLL_BUSY", szName)
			}
			else ColorChat(id, "%L", id, "DICE_CANTROLL_COOLDOWN")
			
			return PLUGIN_HANDLED
		}
		else
		{
			g_blActive = true
			g_iCurrentUser = id
			g_iLastRoll[id] = iTime + g_eSettings[ROLL_INTERVAL]
			
			new szName[32], iDuration, iItem = random(g_iItems)
			get_user_name(id, szName, charsmax(szName))
			ArrayGetArray(g_aItems, iItem, g_eItem)
			ColorChat(0, "%L", LANG_PLAYER, "DICE_ROLLED", szName, LANG_PLAYER, g_eItem[ChatMessage])
			log_clear("%L", LANG_PLAYER, "DICE_ROLLED", szName, LANG_PLAYER, g_eItem[ChatMessage])
			
			if(g_blCstrike && g_eSettings[DICE_COST] > 0)
				cs_set_user_money(id, cs_get_user_money(id) - g_eSettings[DICE_COST])
			
			callfunc_begin(g_eItem[StartFunc], g_eItem[Plugin])
			callfunc_push_int(id)
			callfunc_end()
			
			switch(g_eItem[Type])
			{
				case ITEM_INSTANT:
				{
					set_task(g_eSettings[DICE_COOLDOWN], "RestartDice")
					
					if(g_eSettings[GLOW_ENABLED] && g_eItem[Glow])
						SetRandomGlow(id)
						
					if(g_eSettings[GLOW_DURATION] > 0)
						set_task(float(g_eSettings[GLOW_DURATION]), "AutoRemoveGlow", id + TASK_REMOVEGLOW)
				}
				case ITEM_DELAYED:
				{
					iDuration = random_num(get_pcvar_num(g_eItem[MinDuration]), get_pcvar_num(g_eItem[MaxDuration]))
					g_iHudTime = iTime + iDuration
					copy(g_szHudLang, charsmax(g_szHudLang), g_eItem[HudMessage])
					g_iCurrentItem = iItem
					set_task(1.0, "HudInfo", id + TASK_HUDINFO, .flags = "b")
					
					if(g_eSettings[GLOW_ENABLED] && g_eItem[Glow])
						SetRandomGlow(id)
						
					new iTask = id + TASK_REMOVEGLOW
					
					if(task_exists(iTask))
						remove_task(iTask)
				}
			}
		}
	}
	
	return PLUGIN_HANDLED
}

public RestartDice()
	g_blActive = false
	
public HudInfo(id)
{
	id -= TASK_HUDINFO
	new	iRemaining = g_iHudTime - get_systime()
	
	if(iRemaining <= 0)
		goto cpEnd
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	
	set_hudmessage
	(
		RANDOM_COLOR,
		RANDOM_COLOR,
		RANDOM_COLOR,
		g_eSettings[HUD_X],
		g_eSettings[HUD_Y],
		0,
		0.1,
		1.0,
		0.1,
		0.1,
		-1
	)
	
	if(!is_user_connected(id))
	{
		ShowSyncHudMsg(0, g_iObject, "< D.I.C.E. %L >^n%L", LANG_PLAYER, "DICE_INTERRUPTED", LANG_PLAYER, "DICE_LEFT", szName)
		
		if(!is_blank(g_eSettings[DICE_LEAVE_SOUND]))
			client_cmd(0, "spk %s", g_eSettings[DICE_LEAVE_SOUND])
			
		goto cpEnd
	}
	else if(!is_user_alive(id))
	{
		ShowSyncHudMsg(0, g_iObject, "< D.I.C.E. %L >^n%L", LANG_PLAYER, "DICE_INTERRUPTED", LANG_PLAYER, "DICE_DIED", szName)
		goto cpEnd
	}
	else if(g_blFreeze)
	{
		ShowSyncHudMsg(0, g_iObject, "< D.I.C.E. %L >^n%L", LANG_PLAYER, "DICE_INTERRUPTED", LANG_PLAYER, "DICE_ROUND_END", szName)
		goto cpEnd
	}
	else
	{
		ShowSyncHudMsg(0, g_iObject, "< D.I.C.E. | %i %L >^n%L", iRemaining, LANG_PLAYER, "DICE_REMAINING", LANG_PLAYER, g_szHudLang, szName)
		
		if(g_eSettings[GLOW_ENABLED] && g_eItem[Glow])
			SetRandomGlow(id)
			
		return
	}
	
	cpEnd:
	remove_task(id + TASK_HUDINFO)
	EndItem(id)
}

public EndItem(id)
{
	g_iCurrentUser = 0
	
	ArrayGetArray(g_aItems, g_iCurrentItem, g_eItem)
	set_task(g_eSettings[DICE_COOLDOWN], "RestartDice")
	
	new iTask = id + TASK_HUDINFO
	
	if(g_eSettings[GLOW_ENABLED] && g_eItem[Glow] && is_user_alive(id))
		RemoveGlow(id)
	
	if(task_exists(iTask))
		remove_task(iTask)
	
	callfunc_begin(g_eItem[EndFunc], g_eItem[Plugin])
	callfunc_push_int(id)
	callfunc_end()
}

public AutoRemoveGlow(id)
{
	id -= TASK_REMOVEGLOW
	
	if(is_user_alive(id))
		RemoveGlow(id)
}

SetRandomGlow(id)
	set_user_rendering(id, kRenderFxGlowShell, RANDOM_COLOR, RANDOM_COLOR, RANDOM_COLOR, kRenderNormal, g_eSettings[GLOW_ALPHA])
	
RemoveGlow(id)
	set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderNormal, 0)
	
log_clear(message[], any:...)
{
	if(g_eSettings[DICE_LOG])
	{
		new szMessage[192]
		vformat(szMessage, charsmax(szMessage), message, 2)
		replace_all(szMessage, charsmax(szMessage), "!g", "")
		replace_all(szMessage, charsmax(szMessage), "!n", "")
		replace_all(szMessage, charsmax(szMessage), "!t", "")
		log_amx(szMessage)
	}
}

bool:is_blank(szString[])
	return szString[0] == EOS

bool:IsItemDisabled(szItem[])
	return TrieKeyExists(g_tDisabled, szItem)
	
ColorChat(const id, const szInput[], any:...)
{
	new iPlayers[32], iCount = 1
	static szMessage[191]
	vformat(szMessage, charsmax(szMessage), szInput, 3)
	format(szMessage[0], charsmax(szMessage), "%s %s", g_eSettings[CHAT_PREFIX], szMessage)
	
	replace_all(szMessage, charsmax(szMessage), "!g", "^4")
	replace_all(szMessage, charsmax(szMessage), "!n", "^1")
	replace_all(szMessage, charsmax(szMessage), "!t", "^3")
	
	if(id)
		iPlayers[0] = id
	else
		get_players(iPlayers, iCount, "ch")
	
	for(new i; i < iCount; i++)
	{
		if(is_user_connected(iPlayers[i]))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, iPlayers[i])
			write_byte(iPlayers[i])
			write_string(szMessage)
			message_end()
		}
	}
}

/* PLUGIN Natives */

public plugin_natives()
{
	register_library("DICE")
	register_native("AddDiceItem", "_AddDiceItem")
	register_native("AddDiceCvar", "_AddDiceCvar")
	register_native("AddDiceResource", "_AddDiceResource")
	register_native("GetDiceCvar", "_GetDiceCvar")
	register_native("DiceHUD", "_DiceHUD")
	register_native("DiceDHUD", "_DiceDHUD")
	register_native("DiceChat", "_DiceChat")
	register_native("IsDiceActive", "_IsDiceActive")
}

public _AddDiceItem(iPlugin, iParams)
{
	new szName[32]
	get_string(2, szName, charsmax(szName))
	
	if(IsItemDisabled(szName))
		return
		
	new eItem[Items]
	
	get_string(1, eItem[Plugin], charsmax(eItem[Plugin]))
	copy(eItem[Name], charsmax(eItem[Name]), szName)
	eItem[Type] = get_param(3)
	get_string(4, eItem[ChatMessage], charsmax(eItem[ChatMessage]))
	get_string(5, eItem[StartFunc], charsmax(eItem[StartFunc]))
	formatex(eItem[EndFunc], charsmax(eItem[EndFunc]), "%sOFF", eItem[StartFunc])
	get_string(6, eItem[HudMessage], charsmax(eItem[HudMessage]))
	
	if(eItem[Type] == ITEM_DELAYED)
	{
		new szMin[3], szMax[3]
		num_to_str(get_param(7), szMin, charsmax(szMin))
		num_to_str(get_param(8), szMax, charsmax(szMax))
		
		eItem[MinDuration] = AddDiceCvar(eItem[Name], "min", szMin, CVAR_INTEGER)
		eItem[MaxDuration] = AddDiceCvar(eItem[Name], "max", szMax, CVAR_INTEGER)
	}

	eItem[Glow] = _:get_param(9)
	
	ArrayPushArray(g_aItems, eItem)
	g_iItems++
	
	/*log_amx("[DICE] Plugin: %s", eItem[Plugin])
	log_amx("[DICE] Name: %s", eItem[Name])
	log_amx("[DICE] Type: %s", eItem[Type] == 1 ? "delayed" : "instant")
	log_amx("[DICE] Chat Message: %s", eItem[ChatMessage])
	log_amx("[DICE] Start Function: %s", eItem[StartFunc])
	log_amx("[DICE] End Function: %s", eItem[EndFunc])
	log_amx("[DICE] HUD Message: %s", eItem[HudMessage])
	log_amx("[DICE] Minimum Duration: %i", eItem[MinDuration])
	log_amx("[DICE] Maximum Duration: %i", eItem[MaxDuration])
	log_amx("[DICE] Glow: %s", eItem[Glow] ? "true" : "false")*/
}

public _AddDiceCvar(iPlugin, iParams)
{
	new szItem[32]
	get_string(1, szItem, charsmax(szItem))
	
	if(IsItemDisabled(szItem))
		return 0
		
	new szCvar[64], szOption[32], szValue[32]
	get_string(2, szOption, charsmax(szOption))
	get_string(3, szValue, charsmax(szValue))
	formatex(szCvar, charsmax(szCvar), "dice_%s_%s", szItem, szOption)
	ArrayPushString(g_aCvars, szCvar)
	TrieSetCell(g_tCvars, szCvar, get_param(4))
	return register_cvar(szCvar, szValue)
}

public _AddDiceResource(iPlugin, iParams)
{
	new szItems[128], szItem[32], iDisabled, iCommas
	get_string(1, szItems, charsmax(szItems))
	
	if(contain(szItems, ",") != -1)
	{
		while(szItems[0] != 0 && strtok(szItems, szItem, charsmax(szItem), szItems, charsmax(szItems), ','))
		{
			trim(szItems); trim(szItem)
			iCommas++
			
			if(IsItemDisabled(szItem))
				iDisabled++
		}
		
		if(iDisabled == iCommas)
			return 0
	}
	else if(IsItemDisabled(szItems))
		return 0
	
	new szResource[128]
	get_string(2, szResource, charsmax(szResource))
	
	switch(szResource[strlen(szResource) - 1])
	{
		case 'l', 'L', 'r', 'R': return precache_model(szResource)
		case 'v', 'V': return precache_sound(szResource)
		case '3': return precache_generic(szResource)
	}
	
	return 0
}

public any:_GetDiceCvar(iPlugin, iParams)
{
	switch(get_param(2))
	{
		case CVAR_INTEGER: return get_pcvar_num(get_param(1))
		case CVAR_FLOAT: return get_pcvar_float(get_param(1))
		case CVAR_STRING:
		{
			new szValue[32]
			get_pcvar_string(get_param(1), szValue, charsmax(szValue))
			set_string(3, szValue, get_param(4))
		}
	}
	
	return 1
}

public _DiceHUD(iPlugin, iParams)
{
	set_hudmessage
	(
		RANDOM_COLOR,
		RANDOM_COLOR,
		RANDOM_COLOR,
		g_eSettings[HUD_X],
		g_eSettings[HUD_Y],
		g_eSettings[HUD_EFFECTS],
		g_eSettings[HUD_FXTIME],
		g_eSettings[HUD_HOLDTIME],
		g_eSettings[HUD_FADEINTIME],
		g_eSettings[HUD_FADEOUTTIME]
	)
	
	new szMessage[128]
	get_string(2, szMessage, charsmax(szMessage))
	show_hudmessage(0, "< D.I.C.E. >^n%s", szMessage)
}

public _DiceDHUD(iPlugin, iParams)
{
	if(!g_eSettings[DHUD_ENABLED])
		return
		
	set_dhudmessage
	(
		RANDOM_COLOR,
		RANDOM_COLOR,
		RANDOM_COLOR,
		g_eSettings[DHUD_X],
		g_eSettings[DHUD_Y],
		g_eSettings[DHUD_EFFECTS],
		g_eSettings[DHUD_FXTIME],
		g_eSettings[DHUD_HOLDTIME],
		g_eSettings[DHUD_FADEINTIME],
		g_eSettings[DHUD_FADEOUTTIME]
	)
	
	new szMessage[128]
	get_string(2, szMessage, charsmax(szMessage))
	show_dhudmessage(get_param(1), szMessage)
}

public _DiceChat(iPlugin, iParams)
{
	new szMessage[191]
	vdformat(szMessage, charsmax(szMessage), 2, 3)
	ColorChat(get_param(1), szMessage)
}

public bool:_IsDiceActive(iPlugin, iParams)
	return g_blActive
