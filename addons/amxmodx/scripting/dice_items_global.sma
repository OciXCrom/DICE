#include <amxmodx>
#include <amxmisc>
#include <dice>
#include <fakemeta>
#include <fun>
#include <engine>

#define TASK_SCORPIONS 233000
#define TASK_DEMONS 233100
#define TASK_LIGHTNING 233200
#define TASK_DISCO 233300
#define TASK_TOXINS 233500

new g_szPlugin[64]

new g_msgScreenFade,
	g_iScorpion,
	g_iLightning,
	g_iSmoke

enum _:Cvars
{
	InstantHealthMin,
	InstantHealthMax,
	ScorpionsMin,
	ScorpionsMax,
	ScorpionsFreq,
	DemonsDamageMin,
	DemonsDamageMax,
	DemonsFreq,
	MoonwalkGravity,
	HardwalkGravity,
	OldManSpeed,
	JetPlaneSpeed,
	JetPlaneGravity,
	LightningMin,
	LightningMax,
	LightningDamageMin,
	LightningDamageMax,
	LightningFreq,
	LightningSize,
	LightningFade,
	LightningSlap,
	DiscoRadius,
	DiscoHeal,
	ShadowHealth,
	ShadowSpeed,
	BuryDepth,
	ToxinsChance,
	ZeusSpeed
}

new g_eCvars[Cvars]

enum _:Sounds (+=2)
{
	Godmode = 1,
	OldMan,
	JetPlane,
	Thunder,
	Disco,
	Invis,
	Noclip,
	Bury,
	Demons,
	Jump,
	Fall,
	Camera,
	Blood,
	Zeus
}

new const g_szSounds[][] = {
	"godmode", "DICE/godmode.wav",
	"oldman", "DICE/oldman.wav",
	"jetplane", "DICE/speed.wav",
	"lightning", "DICE/thunder.wav",
	"disco", "DICE/gangnam.wav",
	"shadow", "DICE/invis.wav",
	"noclip", "DICE/noclip.wav",
	"bury", "DICE/bury.wav",
	"demons", "houndeye/he_blast1.wav",
	"wildride", "DICE/jump.wav",
	"wildride", "DICE/fall.wav",
	"camera", "DICE/camera.wav",
	"toxins", "weapons/headshot2.wav",
	"zeus", "DICE/zeus.wav"
}

new const g_iCameras[] = { CAMERA_NONE, CAMERA_3RDPERSON, CAMERA_TOPDOWN, CAMERA_UPLEFT }

new bool:g_blOldMan[33],
	bool:g_blJetPlane[33],
	bool:g_blKnifeOnly[33],
	bool:g_blShadow[33],
	bool:g_blZeus[33],
	bool:g_blCstrike
	
new Float:g_flOldSpeed[33]
	
new g_iOldPos[33][3],
	g_iOldHealth[33],
	g_iDepth[33]

public client_putinserver(id)
{
	g_blOldMan[id] = false
	g_blJetPlane[id] = false
	g_blKnifeOnly[id] = false
	g_blShadow[id] = false
	g_blZeus[id] = false
}

public plugin_init()
{
	register_plugin("D.I.C.E. Items", PLUGIN_VERSION, "OciXCrom")
	register_dictionary("DICE.txt")
	get_plugin(-1, g_szPlugin, charsmax(g_szPlugin))	
	register_event("CurWeapon", "OnWeaponChange", "be", "1=1")	
	g_blCstrike = cstrike_running() == 1 ? true : false
	g_msgScreenFade = get_user_msgid("ScreenFade")
	AddItems()
}

public plugin_precache()
{
	for(new i; i < sizeof(g_szSounds) - 1; i += 2)
		AddDiceResource(g_szSounds[i], g_szSounds[i + 1])
		
	AddDiceResource("camera", "models/rpgrocket.mdl")
	g_iScorpion = AddDiceResource("scorpions", "models/DICE/scorpion.mdl")
	g_iLightning = AddDiceResource("lightning", "sprites/lgtning.spr")
	g_iSmoke = AddDiceResource("lightning", "sprites/steam1.spr")
}

AddItems()
{
	new szItem[32]
	
	copy(szItem, charsmax(szItem), "instanthealth")
	AddDiceItem(g_szPlugin, szItem, ITEM_INSTANT, "DI_INSTANT_HEALTH", "ItemInstantHealth")
	g_eCvars[InstantHealthMin] = AddDiceCvar(szItem, "min", "25")
	g_eCvars[InstantHealthMax] = AddDiceCvar(szItem, "max", "255")
	
	AddDiceItem(g_szPlugin, "godmode", ITEM_DELAYED, "DI_GODMODE", "ItemGodmode", "DIH_GODMODE", 5, 15)
	
	copy(szItem, charsmax(szItem), "scorpions")
	AddDiceItem(g_szPlugin, szItem, ITEM_DELAYED, "DI_SCORPIONS", "ItemScorpions", "DIH_SCORPIONS", 8, 20)
	g_eCvars[ScorpionsFreq] = AddDiceCvar(szItem, "freq", "0.3", CVAR_FLOAT)
	
	copy(szItem, charsmax(szItem), "demons")
	AddDiceItem(g_szPlugin, szItem, ITEM_DELAYED, "DI_DEMONS", "ItemDemons", "DIH_DEMONS", 5, 15)
	g_eCvars[DemonsDamageMin] = AddDiceCvar(szItem, "damage_min", "1")
	g_eCvars[DemonsDamageMax] = AddDiceCvar(szItem, "damage_max", "5")
	g_eCvars[DemonsFreq] = AddDiceCvar(szItem, "freq", "0.8", CVAR_FLOAT)
	
	copy(szItem, charsmax(szItem), "moonwalk")
	AddDiceItem(g_szPlugin, szItem, ITEM_DELAYED, "DI_MOONWALK", "ItemMoonwalk", "DIH_MOONWALK", 5, 15)
	g_eCvars[MoonwalkGravity] = AddDiceCvar(szItem, "gravity", "0.3", CVAR_FLOAT)
	
	copy(szItem, charsmax(szItem), "hardwalk")
	AddDiceItem(g_szPlugin, szItem, ITEM_DELAYED, "DI_HARDWALK", "ItemHardwalk", "DIH_HARDWALK", 5, 15)
	g_eCvars[HardwalkGravity] = AddDiceCvar(szItem, "gravity", "30.0", CVAR_FLOAT)
	
	copy(szItem, charsmax(szItem), "oldman")
	AddDiceItem(g_szPlugin, szItem, ITEM_DELAYED, "DI_OLD_MAN", "ItemOldMan", "DIH_OLD_MAN", 7, 12)
	g_eCvars[OldManSpeed] = AddDiceCvar(szItem, "speed", "65.0", CVAR_FLOAT)
	
	copy(szItem, charsmax(szItem), "jetplane")
	AddDiceItem(g_szPlugin, szItem, ITEM_DELAYED, "DI_JET_PLANE", "ItemJetPlane", "DIH_JET_PLANE", 7, 12)
	g_eCvars[JetPlaneSpeed] = AddDiceCvar(szItem, "speed", "1000.0", CVAR_FLOAT)
	g_eCvars[JetPlaneGravity] = AddDiceCvar(szItem, "gravity", "0.4", CVAR_FLOAT)
	
	copy(szItem, charsmax(szItem), "lightning")
	AddDiceItem(g_szPlugin, szItem, ITEM_INSTANT, "DI_LIGHTNING", "ItemLightning")
	g_eCvars[LightningMin] = AddDiceCvar(szItem, "min", "1")
	g_eCvars[LightningMax] = AddDiceCvar(szItem, "max", "3")
	g_eCvars[LightningDamageMin] = AddDiceCvar(szItem, "damage_min", "20")
	g_eCvars[LightningDamageMax] = AddDiceCvar(szItem, "damage_max", "30")
	g_eCvars[LightningFreq] = AddDiceCvar(szItem, "freq", "0.8", CVAR_FLOAT)
	g_eCvars[LightningSize] = AddDiceCvar(szItem, "size", "100")
	g_eCvars[LightningFade] = AddDiceCvar(szItem, "fade", "1")
	g_eCvars[LightningSlap] = AddDiceCvar(szItem, "slap", "1")
	
	copy(szItem, charsmax(szItem), "disco")
	AddDiceItem(g_szPlugin, szItem, ITEM_DELAYED, "DI_DISCO", "ItemDisco", "DIH_DISCO", 9, 20)
	g_eCvars[DiscoRadius] = AddDiceCvar(szItem, "radius", "150.0", CVAR_FLOAT)
	g_eCvars[DiscoHeal] = AddDiceCvar(szItem, "heal", "4")
	
	copy(szItem, charsmax(szItem), "shadow")
	AddDiceItem(g_szPlugin, szItem, ITEM_DELAYED, "DI_SHADOW", "ItemShadow", "DIH_SHADOW", 5, 15, .glow = false)
	g_eCvars[ShadowHealth] = AddDiceCvar(szItem, "health", "1")
	g_eCvars[ShadowSpeed] = AddDiceCvar(szItem, "speed", "360.0", CVAR_FLOAT)
	
	AddDiceItem(g_szPlugin, "noclip", ITEM_DELAYED, "DI_NOCLIP", "ItemNoclip", "DIH_NOCLIP", 5, 15)
	
	copy(szItem, charsmax(szItem), "bury")
	AddDiceItem(g_szPlugin, szItem, ITEM_DELAYED, "DI_BURY", "ItemBury", "DIH_BURY", 5, 12)
	g_eCvars[BuryDepth] = AddDiceCvar(szItem, "depth", "30")
	
	AddDiceItem(g_szPlugin, "wildride", ITEM_DELAYED, "DI_WILD_RIDE", "ItemWildRide", "DIH_WILD_RIDE", 5, 10)
	
	AddDiceItem(g_szPlugin, "camera", ITEM_DELAYED, "DI_CAMERA", "ItemCamera", "DIH_CAMERA", 10, 20)
	AddDiceItem(g_szPlugin, "disarm", ITEM_INSTANT, "DI_DISARM", "ItemDisarm")
	
	copy(szItem, charsmax(szItem), "toxins")
	AddDiceItem(g_szPlugin, szItem, ITEM_DELAYED, "DI_TOXINS", "ItemToxins", "DIH_TOXINS", 7, 15)
	g_eCvars[ToxinsChance] = AddDiceCvar(szItem, "chance", "10")
	
	copy(szItem, charsmax(szItem), "zeus")
	AddDiceItem(g_szPlugin, szItem, ITEM_DELAYED, "DI_ZEUS", "ItemZeus", "DIH_ZEUS", 7, 15)
	g_eCvars[ZeusSpeed] = AddDiceCvar(szItem, "speed", "700.0", CVAR_FLOAT)
}

public OnWeaponChange(id)
{
	if(g_blKnifeOnly[id])
		engclient_cmd(id, "weapon_knife")
		
	if(g_blOldMan[id])
		set_user_maxspeed(id, GetDiceCvar(g_eCvars[OldManSpeed], CVAR_FLOAT))
		
	if(g_blJetPlane[id])
		set_user_maxspeed(id, GetDiceCvar(g_eCvars[JetPlaneSpeed], CVAR_FLOAT))
		
	if(g_blShadow[id])
	{
		set_user_maxspeed(id, GetDiceCvar(g_eCvars[ShadowSpeed], CVAR_FLOAT))
		engclient_cmd(id, "weapon_knife")
	}
	
	if(g_blZeus[id])
		set_user_maxspeed(id, GetDiceCvar(g_eCvars[ZeusSpeed], CVAR_FLOAT))
}

public ItemInstantHealth(id)
{
	new iRandom = random_num(GetDiceCvar(g_eCvars[InstantHealthMin]), GetDiceCvar(g_eCvars[InstantHealthMax]))
	new userHP = get_user_health(id)
	new newHP = userHP + iRandom
	set_user_health(id, newHP >= 255 ? 255 : newHP)
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_INSTANT_HEALTH", newHP >= 255 ? 255 : newHP)
	client_cmd(0, "spk ^"fvox/beep _comma beep _comma beep _comma administering_medical^"")
	DiceDHUD(id, szMessage)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	formatex(szMessage, charsmax(szMessage), "%L", LANG_PLAYER, "DIH_INSTANT_HEALTH", szName, iRandom)
	DiceHUD(szMessage)
}

public ItemGodmode(id)
{
	set_user_godmode(id, 1)
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_GODMODE")
	client_cmd(0, "spk %s", g_szSounds[Godmode])
	DiceDHUD(id, szMessage)
}

public ItemGodmodeOFF(id)
{		
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
			set_user_godmode(id, 0)
			
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_GODMODE_OFF")
		DiceDHUD(id, szMessage)
	}
}

public ItemScorpions(id)
{
	set_task(GetDiceCvar(g_eCvars[ScorpionsFreq], CVAR_FLOAT), "CreateScorpion", id + TASK_SCORPIONS, .flags = "b")
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_SCORPIONS")
	client_cmd(0, "spk aslave/slv_die2.wav")
	DiceDHUD(id, szMessage)
}

public ItemScorpionsOFF(id)
{
	remove_task(id + TASK_SCORPIONS)
		
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
			set_user_godmode(id, 0)
			
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_SCORPIONS_OFF")
		DiceDHUD(id, szMessage)
	}
}

public CreateScorpion(id)
{
	id -= TASK_SCORPIONS
	
	if(is_user_alive(id))
	{
		new iVec[3], iAimVec[3], iVelocityVec[3], iLength, iSpeed = 800
		get_user_origin(id, iVec)
		get_user_origin(id, iAimVec, 2)
	
		iVelocityVec[0] = iAimVec[0] - iVec[0]
		iVelocityVec[1] = iAimVec[1] - iVec[1]
		iVelocityVec[2] = iAimVec[2] - iVec[2]
	
		iLength = sqrt(iVelocityVec[0] * iVelocityVec[0] + iVelocityVec[1] * iVelocityVec[1] + iVelocityVec[2] * iVelocityVec[2])
	
		iVelocityVec[0] = iVelocityVec[0] * iSpeed/iLength
		iVelocityVec[1] = iVelocityVec[1] * iSpeed/iLength
		iVelocityVec[2] = iVelocityVec[2] * iSpeed/iLength
	
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_MODEL)
		write_coord(iVec[0])
		write_coord(iVec[1])
		write_coord(iVec[2] + 20)
		write_coord(iVelocityVec[0])
		write_coord(iVelocityVec[1])
		write_coord(iVelocityVec[2] + 100)
		write_angle(random(361))
		write_short(g_iScorpion)
		write_byte(2)
		write_byte(255)
		message_end()
	}
	else
		remove_task(id + TASK_SCORPIONS)
} 

sqrt(iNum)
{		
	new iDiv = iNum
	new iResult = 1
	
	while(iDiv > iResult)
	{
		iDiv = (iDiv + iResult) / 2
		iResult = iNum / iDiv
	}
	
	return iDiv
}

public ItemDemons(id)
{
	set_task(GetDiceCvar(g_eCvars[DemonsFreq], CVAR_FLOAT), "DemonsAttack", id + TASK_DEMONS, .flags = "b")
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_DEMONS")
	client_cmd(0, "spk houndeye/he_attack2.wav")
	DiceDHUD(id, szMessage)
}

public ItemDemonsOFF(id)
{
	remove_task(id + TASK_DEMONS)
		
	if(is_user_connected(id))
	{
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_DEMONS_OFF")
		DiceDHUD(id, szMessage)
	}
}

public DemonsAttack(id)
{
	id -= TASK_DEMONS
	user_slap(id, random_num(GetDiceCvar(g_eCvars[DemonsDamageMin]), GetDiceCvar(g_eCvars[DemonsDamageMax])))
	EmitSound(id, g_szSounds[Demons])
}

public ItemMoonwalk(id)
{
	set_user_gravity(id, GetDiceCvar(g_eCvars[MoonwalkGravity], CVAR_FLOAT))
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_MOONWALK")
	client_cmd(0, "spk ^"dadeda high walk granted^"")
	DiceDHUD(id, szMessage)
}

public ItemMoonwalkOFF(id)
{
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
			set_user_gravity(id)
		
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_MOONWALK_OFF")
		DiceDHUD(id, szMessage)
	}
}

public ItemHardwalk(id)
{
	set_user_gravity(id, GetDiceCvar(g_eCvars[HardwalkGravity], CVAR_FLOAT))
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_HARDWALK")
	client_cmd(0, "spk ^"warning _comma high walk denied^"");
	DiceDHUD(id, szMessage)
}

public ItemHardwalkOFF(id)
{
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
			set_user_gravity(id)
		
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_HARDWALK_OFF")
		DiceDHUD(id, szMessage)
	}
}

public ItemOldMan(id)
{
	g_blOldMan[id] = true
	g_flOldSpeed[id] = get_user_maxspeed(id)
	OnWeaponChange(id)
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_OLD_MAN")
	client_cmd(0, "spk %s", g_szSounds[OldMan])
	DiceDHUD(id, szMessage)
}

public ItemOldManOFF(id)
{
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
			set_user_maxspeed(id, g_flOldSpeed[id])
			
		g_blOldMan[id] = false
		
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_OLD_MAN_OFF")
		DiceDHUD(id, szMessage)
	}
}

public ItemJetPlane(id)
{
	g_blJetPlane[id] = true
	g_flOldSpeed[id] = get_user_maxspeed(id)
	set_user_gravity(id, GetDiceCvar(g_eCvars[JetPlaneGravity], CVAR_FLOAT))
	OnWeaponChange(id)
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_JET_PLANE")
	client_cmd(0, "spk %s", g_szSounds[JetPlane])
	DiceDHUD(id, szMessage)
}

public ItemJetPlaneOFF(id)
{
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
		{
			set_user_maxspeed(id, g_flOldSpeed[id])
			set_user_gravity(id)
		}
			
		g_blJetPlane[id] = false
		
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_JET_PLANE_OFF")
		DiceDHUD(id, szMessage)
	}
}

public ItemLightning(id)
{
	new iRandom = random_num(GetDiceCvar(g_eCvars[LightningMin]), GetDiceCvar(g_eCvars[LightningMax]))
	new iTask = id + TASK_LIGHTNING
	
	StruckLightning(iTask)
	
	if(iRandom > 1)
		set_task(GetDiceCvar(g_eCvars[LightningFreq], CVAR_FLOAT), "StruckLightning", iTask, .flags = "a", .repeat = iRandom - 1)
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_LIGHTNING", iRandom)
	DiceDHUD(id, szMessage)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	formatex(szMessage, charsmax(szMessage), "%L", LANG_PLAYER, "DIH_LIGHTNING", szName, iRandom)
	DiceHUD(szMessage)
}

public StruckLightning(id)
{
	id -= TASK_LIGHTNING
	
	if(!is_user_alive(id))
	{
		remove_task(id + TASK_LIGHTNING)
		return
	}
		
	new iOrigin[2][3]
	get_user_origin(id, iOrigin[0])
	iOrigin[0][2] = iOrigin[0][2] - 26
	iOrigin[1][0] = iOrigin[0][0] + 150
	iOrigin[1][1] = iOrigin[0][1] + 150
	iOrigin[1][2] = iOrigin[0][2] + 400
	
	if(GetDiceCvar(g_eCvars[LightningFade]))
		ScreenFade(id, 255, 255, 255, 120)
	
	if(GetDiceCvar(g_eCvars[LightningSlap]))
		user_slap(id, random_num(GetDiceCvar(g_eCvars[LightningDamageMin]), GetDiceCvar(g_eCvars[LightningDamageMax])))
	else
		set_user_health(id, get_user_health(id) - random_num(GetDiceCvar(g_eCvars[LightningDamageMin]), GetDiceCvar(g_eCvars[LightningDamageMax])))
		
	EmitSound(id, g_szSounds[Thunder])
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(0)
	write_coord(iOrigin[0][0])
	write_coord(iOrigin[0][1])
	write_coord(iOrigin[0][2])
	write_coord(iOrigin[1][0])
	write_coord(iOrigin[1][1])
	write_coord(iOrigin[1][2])
	write_short(g_iLightning)
	write_byte(1)
	write_byte(5)
	write_byte(2)
	write_byte(GetDiceCvar(g_eCvars[LightningSize]))
	write_byte(30)
	write_byte(RANDOM_COLOR)
	write_byte(RANDOM_COLOR)
	write_byte(RANDOM_COLOR)
	write_byte(200)
	write_byte(200)
	message_end()
	
	message_begin(MSG_PVS, SVC_TEMPENTITY, iOrigin[1])
	write_byte(9)
	write_coord(iOrigin[1][0])
	write_coord(iOrigin[1][1])
	write_coord(iOrigin[1][2])
	message_end()
	   
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY, iOrigin[1])
	write_byte(5)
	write_coord(iOrigin[1][0])
	write_coord(iOrigin[1][1])
	write_coord(iOrigin[1][2])
	write_short(g_iSmoke)
	write_byte(10)
	write_byte(10)
	message_end()
}

public ScreenFade(id, iRed, iGreen, iBlue, iAlpha)
{
	message_begin(MSG_ONE, g_msgScreenFade, {0, 0, 0}, id)
	write_short(1<<10)
	write_short(1<<10)
	write_short(0x0000)
	write_byte(iRed)
	write_byte(iGreen)
	write_byte(iBlue)
	write_byte(iAlpha)
	message_end()
}

public ItemDisco(id)
{
	g_blKnifeOnly[id] = true
	engclient_cmd(id, "weapon_knife")
	
	new iTask = id + TASK_DISCO
	DiscoAura(iTask)
	set_task(0.7, "DiscoAura", iTask, .flags = "b")
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_DISCO")
	EmitSound(id, g_szSounds[Disco])
	DiceDHUD(id, szMessage)
}

public ItemDiscoOFF(id)
{
	remove_task(id + TASK_DISCO)
	arrayset(g_blKnifeOnly, false, sizeof(g_blKnifeOnly))
		
	if(is_user_connected(id))
	{
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_DISCO_OFF")
		DiceDHUD(id, szMessage)
	}
}

public DiscoAura(id)
{
	id -= TASK_DISCO
	
	MakeAura(id, 60, RANDOM_COLOR, RANDOM_COLOR, RANDOM_COLOR, RANDOM_COLOR, 50)
	
	new iPlayers[32], Float:flOrigin[3], Float:flOrigin2[3], Float:flRadius = GetDiceCvar(g_eCvars[DiscoRadius], CVAR_FLOAT),
		iHeal = GetDiceCvar(g_eCvars[DiscoHeal]), iTeam = get_user_team(id), iPnum, iPlayer
		
	get_players(iPlayers, iPnum, "a")
	pev(id, pev_origin, flOrigin)
	
	for(new i; i < iPnum; i++)
	{
		iPlayer = iPlayers[i]
		pev(iPlayer, pev_origin, flOrigin2)
		
		if(get_distance_f(flOrigin, flOrigin2) <= flRadius)
		{
			if(get_user_team(iPlayer) == iTeam)
				set_user_health(iPlayer, get_user_health(iPlayer) + iHeal)
			else
			{
				if(!g_blKnifeOnly[iPlayer])
				{
					g_blKnifeOnly[iPlayer] = true
					engclient_cmd(iPlayer, "weapon_knife")
				}
			}
		}
	}
}

MakeAura(id, iRadius, iRed, iGreen, iBlue, iAlpha, iDecay)
{
	new iOrigin[3]
	get_user_origin(id, iOrigin)
	
	message_begin(MSG_PVS, SVC_TEMPENTITY, iOrigin, 0)
	write_byte(TE_DLIGHT)
	write_coord(iOrigin[0])
	write_coord(iOrigin[1])
	write_coord(iOrigin[2])
	write_byte(iRadius)
	write_byte(iRed)
	write_byte(iGreen)
	write_byte(iBlue)
	write_byte(iAlpha)
	write_byte(iDecay)
	message_end()
}

public ItemShadow(id)
{
	g_blShadow[id] = true
	g_iOldHealth[id] = get_user_health(id)
	g_flOldSpeed[id] = get_user_maxspeed(id)
	set_user_health(id, GetDiceCvar(g_eCvars[ShadowHealth]))
	set_user_footsteps(id, 1)
	set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0)
	OnWeaponChange(id)	
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_SHADOW")
	client_cmd(0, "spk %s", g_szSounds[Invis])
	DiceDHUD(id, szMessage)
}

public ItemShadowOFF(id)
{
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
		{
			set_user_maxspeed(id, g_flOldSpeed[id])
			set_user_health(id, g_iOldHealth[id])
			set_user_footsteps(id, 0)
			set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderNormal, 0)
		}
			
		g_blShadow[id] = false
			
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_SHADOW_OFF")
		DiceDHUD(id, szMessage)
	}
}

public ItemNoclip(id)
{
	get_user_origin(id, g_iOldPos[id])
	set_user_noclip(id, 1)
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_NOCLIP")
	client_cmd(0, "spk %s", g_szSounds[Noclip])
	DiceDHUD(id, szMessage)
}

public ItemNoclipOFF(id)
{		
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
		{
			set_user_noclip(id, 0)
			UnstuckIfStuck(id)
		}
			
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_NOCLIP_OFF")
		DiceDHUD(id, szMessage)
	}
}

bool:is_player_stuck(id)
{
    static Float:flOrigin[3]
    pev(id, pev_origin, flOrigin)
    
    engfunc(EngFunc_TraceHull, flOrigin, flOrigin, 0, (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN, id, 0)
    
    if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
        return true
    
    return false
}

public ItemBury(id)
{
	new iDepth = GetDiceCvar(g_eCvars[BuryDepth])
	
	while(!is_player_stuck(id))
	{
		bury_player(id, 1)
		g_iDepth[id] += iDepth
	}
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_BURY")
	client_cmd(0, "spk %s", g_szSounds[Bury])
	DiceDHUD(id, szMessage)
}

public ItemBuryOFF(id)
{		
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
			bury_player(id, 0)
			
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_BURY_OFF")
		DiceDHUD(id, szMessage)
	}
}

bury_player(id, iType)
{
	new iOrigin[3]
	get_user_origin(id, iOrigin)
	
	switch(iType)
	{
		case 0:	iOrigin[2] += GetDiceCvar(g_eCvars[BuryDepth]) + 5
		case 1:	iOrigin[2] -= 30
	}
	
	set_user_origin(id, iOrigin)
}

public ItemWildRide(id)
{
	set_user_gravity(id, -50.0)
	
	new iOrigin[3]
	get_user_origin(id, iOrigin)
	iOrigin[2] += 5
	set_user_origin(id, iOrigin)
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_WILD_RIDE")
	EmitSound(id, g_szSounds[Jump])
	DiceDHUD(id, szMessage)
}

public ItemWildRideOFF(id)
{		
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
		{
			set_user_gravity(id, 30.0)
			EmitSound(id, g_szSounds[Fall])
			set_task(1.0, "NormalGravity", id)
		}
			
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_WILD_RIDE_OFF")
		DiceDHUD(id, szMessage)
	}
}

public NormalGravity(id)
	set_user_gravity(id)

public ItemCamera(id)
{
	new iRandom = g_iCameras[random_num(1, charsmax(g_iCameras))]
	set_view(id, iRandom)
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_CAMERA")
	client_cmd(0, "spk %s", g_szSounds[Camera])
	DiceDHUD(id, szMessage)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	formatex(szMessage, charsmax(szMessage), "%L", LANG_PLAYER, "DIH_CAMERA", szName)
	DiceHUD(szMessage)
}

public ItemCameraOFF(id)
{		
	if(is_user_connected(id))
	{
		set_view(id, g_iCameras[0])
			
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_CAMERA_OFF")
		DiceDHUD(id, szMessage)
	}
}

public ItemDisarm(id)
{
	new bool:bC4
	
	if(g_blCstrike && user_has_weapon(id, CSW_C4))
		bC4 = true
		
	strip_user_weapons(id)
	
	if(bC4)
		give_item(id, "weapon_c4")
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_DISARM")
	client_cmd(0, "spk ^"weapon system deactivated^"")
	DiceDHUD(id, szMessage)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	formatex(szMessage, charsmax(szMessage), "%L", LANG_PLAYER, "DIH_DISARM", szName)
	DiceHUD(szMessage)
}

public ItemToxins(id)
{
	set_task(1.0, "CheckBlood", id + TASK_TOXINS, .flags = "b")
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_TOXINS")
	client_cmd(0, "spk fvox/blood_toxins.wav")
	DiceDHUD(id, szMessage)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	formatex(szMessage, charsmax(szMessage), "%L", LANG_PLAYER, "DIH_TOXINS", szName)
	DiceHUD(szMessage)
}

public ItemToxinsOFF(id)
{
	remove_task(id + TASK_TOXINS)
	
	if(is_user_alive(id))
	{
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_TOXINS_OFF")
		DiceDHUD(id, szMessage)
	}
}

public CheckBlood(id)
{
	id -= TASK_TOXINS
	
	if(is_user_alive(id))
	{
		ScreenFade(id, RANDOM_COLOR, RANDOM_COLOR, RANDOM_COLOR, RANDOM_COLOR)
		PlayEffect(id, TE_LAVASPLASH)
		
		if(!random(GetDiceCvar(g_eCvars[ToxinsChance])))
		{
			EmitSound(id, g_szSounds[Blood])
			user_kill(id)
		}
	}
	else
		remove_task(id + TASK_TOXINS)
}

public ItemZeus(id)
{
	g_blZeus[id] = true
	g_flOldSpeed[id] = get_user_maxspeed(id)
	get_user_origin(id, g_iOldPos[id])
	set_user_noclip(id, 1)
	set_user_godmode(id, 1)
	OnWeaponChange(id)
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_ZEUS")
	client_cmd(0, "spk %s", g_szSounds[Zeus])
	DiceDHUD(id, szMessage)
}

public ItemZeusOFF(id)
{
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
		{
			set_user_maxspeed(id, g_flOldSpeed[id])
			set_user_noclip(id, 0)
			set_user_godmode(id, 0)
			UnstuckIfStuck(id)
		}
			
		g_blZeus[id] = false
		
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_ZEUS_OFF")
		DiceDHUD(id, szMessage)
	}
}

UnstuckIfStuck(id)
{
	if(is_player_stuck(id))
	{
		PlayEffect(id, TE_TELEPORT)
		set_user_origin(id, g_iOldPos[id])
		PlayEffect(id, TE_TELEPORT)
	}
}

PlayEffect(id, iEffect)
{
	new iOrigin[3]
	get_user_origin(id, iOrigin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(iEffect)
	write_coord(iOrigin[0])
	write_coord(iOrigin[1])
	write_coord(iOrigin[2])
	message_end()
}

EmitSound(id, szSound[])
	emit_sound(id, CHAN_ITEM, szSound, 1.0, ATTN_NORM, 0, PITCH_NORM)