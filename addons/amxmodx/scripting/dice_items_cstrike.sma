#include <amxmodx>
#include <cstrike>
#include <dice>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#define TASK_MADNESS 233400
#define UNL_AMMO 97280

new g_szPlugin[64]

enum _:Cvars
{
	BomberMin,
	BomberMax,
	MoneyMin,
	MoneyMax,
	MadnessHealth,
	MoleHealth,
	RandomWepAmmoMin,
	RandomWepAmmoMax
}

new g_eCvars[Cvars]

#define MAX_WEAPONS 23

enum _:Weapons
{
	Wpn[20],
	Csw,
	Name[20]
}

new bool:g_blMadness[33]
new Float:g_flKnockback[33][3]
new Float:g_flSpawnPoint[2][3]

public client_putinserver(id)
{
	g_blMadness[id] = false
}
	
new const g_eWeapons[MAX_WEAPONS][Weapons] = 
{
	{ "weapon_p228", CSW_P228, "P228" },
	{ "weapon_scout", CSW_SCOUT, "Scout" },
	{ "weapon_xm1014", CSW_XM1014, "XM1014" },
	{ "weapon_mac10", CSW_MAC10, "MAC-10" },
	{ "weapon_elite", CSW_ELITE, "Dual Elite" },
	{ "weapon_fiveseven", CSW_FIVESEVEN, "Five-Seven" },
	{ "weapon_ump45", CSW_UMP45, "UMP45" },
	{ "weapon_sg550", CSW_SG550, "SG550" },
	{ "weapon_galil", CSW_GALIL, "Galil" },
	{ "weapon_famas", CSW_FAMAS, "Famas" },
	{ "weapon_usp", CSW_USP, "USP" },
	{ "weapon_glock18", CSW_GLOCK18, "Glock18" },
	{ "weapon_awp", CSW_AWP, "AWP" },
	{ "weapon_mp5navy", CSW_MP5NAVY, "MP5 Navy" },
	{ "weapon_m249", CSW_M249, "M249" },
	{ "weapon_m3", CSW_M3, "M3" },
	{ "weapon_m4a1", CSW_M4A1, "M4A1" },
	{ "weapon_tmp", CSW_TMP, "TMP" },
	{ "weapon_g3sg1", CSW_G3SG1, "G3SG1" },
	{ "weapon_deagle", CSW_DEAGLE, "Deagle" },
	{ "weapon_sg552", CSW_SG552, "SG552" },
	{ "weapon_ak47", CSW_AK47, "AK47" },
	{ "weapon_p90", CSW_P90, "P90" }
}

enum _:Sounds (+= 2)
{
	Bomber = 1,
	Bankrupt,
	Applause,
	Madness,
	Teleport
}

new const g_szSounds[][] = {
	"bomber", "DICE/bomber.wav",
	"bankrupt", "DICE/laugh.wav",
	"money", "DICE/applause.wav",
	"madness", "DICE/madness.wav",
	"mole", "DICE/teleport.wav"
}

public plugin_init()
{
	register_plugin("D.I.C.E. Items: Cstrike", PLUGIN_VERSION, "OciXCrom")
	register_dictionary("DICE.txt")
	get_plugin(-1, g_szPlugin, charsmax(g_szPlugin))
	register_event("CurWeapon", "OnWeaponChange", "be", "1=1")	
	RegisterHam(Ham_TakeDamage, "player", "OnTakeDamage")
	RegisterHam(Ham_TakeDamage, "player", "OnTakeDamagePost", 1)
	register_clcmd("drop", "OnWeaponDrop")
	GetSpawnPoints()
	AddItems()
}

public plugin_precache()
{
	for(new i; i < sizeof(g_szSounds) - 1; i += 2)
		AddDiceResource(g_szSounds[i], g_szSounds[i + 1])
}

GetSpawnPoints()
{
	new iEnt = -1
	
	iEnt = find_ent_by_class(iEnt, "info_player_deathmatch")
	pev(iEnt, pev_origin, g_flSpawnPoint[0])
	
	iEnt = -1
	
	iEnt = find_ent_by_class(iEnt, "info_player_start")
	pev(iEnt, pev_origin, g_flSpawnPoint[1])
}

AddItems()
{
	new szItem[32]
	
	AddDiceItem(g_szPlugin, "fullequip", ITEM_INSTANT, "DI_FULL_EQUIP", "ItemFullEquip")
	AddDiceItem(g_szPlugin, "bankrupt", ITEM_INSTANT, "DI_BANKRUPT", "ItemBankrupt")
	
	copy(szItem, charsmax(szItem), "money")
	AddDiceItem(g_szPlugin, szItem, ITEM_INSTANT, "DI_MONEY", "ItemMoney")
	g_eCvars[MoneyMin] = AddDiceCvar(szItem, "min", "1000")
	g_eCvars[MoneyMax] = AddDiceCvar(szItem, "max", "16000")
	
	copy(szItem, charsmax(szItem), "bomber")
	AddDiceItem(g_szPlugin, szItem, ITEM_INSTANT, "DI_BOMBER", "ItemBomber")
	g_eCvars[BomberMin] = AddDiceCvar(szItem, "min", "10")
	g_eCvars[BomberMax] = AddDiceCvar(szItem, "max", "25")
	
	copy(szItem, charsmax(szItem), "madness")
	AddDiceItem(g_szPlugin, szItem, ITEM_DELAYED, "DI_MADNESS", "ItemMadness", "DIH_MADNESS", 8, 22, .glow = false)
	g_eCvars[MadnessHealth] = AddDiceCvar(szItem, "health", "500")
	
	copy(szItem, charsmax(szItem), "mole")
	AddDiceItem(g_szPlugin, szItem, ITEM_INSTANT, "DI_MOLE", "ItemMole")
	g_eCvars[MoleHealth] = AddDiceCvar(szItem, "health", "25")
	
	copy(szItem, charsmax(szItem), "randomwep")
	AddDiceItem(g_szPlugin, szItem, ITEM_INSTANT, "DI_RANDOM_WEAPON", "ItemRandomWeapon")
	g_eCvars[RandomWepAmmoMin] = AddDiceCvar(szItem, "min", "10")
	g_eCvars[RandomWepAmmoMax] = AddDiceCvar(szItem, "max", "255")
}

public OnWeaponChange(id)
{
	if(g_blMadness[id])
		engclient_cmd(id, "weapon_mac10")
}

public OnTakeDamage(iVictim, iInflictor, iAttacker, Float:flDamage, iBits)
{
	if(g_blMadness[iVictim])
		pev(iVictim, pev_velocity, g_flKnockback[iVictim])
}

public OnTakeDamagePost(iVictim, iInflictor, iAttacker, Float:flDamage, iBits)
{
	if(is_user_connected(iAttacker) && g_blMadness[iAttacker] && get_user_team(iAttacker) != get_user_team(iVictim))
		user_slap(iVictim, 0)
		
	if(g_blMadness[iVictim])
	{
		static Float:flPush[3]
		pev(iVictim, pev_velocity, flPush)
		xs_vec_sub(flPush, g_flKnockback[iVictim], flPush)
		xs_vec_mul_scalar(flPush, 0.0, flPush)
		xs_vec_add(flPush, g_flKnockback[iVictim], flPush)
		set_pev(iVictim, pev_velocity, flPush)
	}
}

public OnWeaponDrop(id)
	return g_blMadness[id] ? PLUGIN_HANDLED : PLUGIN_CONTINUE
	
public ItemFullEquip(id)
{
	if(get_user_team(id) == 2)
	{
		give_item(id, "weapon_m4a1")
		cs_set_user_bpammo(id, CSW_M4A1, 90)
		give_item(id, "item_thighpack")
	}
	else
	{
		give_item(id, "weapon_ak47")
		cs_set_user_bpammo(id, CSW_AK47, 90)
	}
	
	give_item(id, "weapon_deagle")
	give_item(id, "weapon_hegrenade")
	give_item(id, "weapon_flashbang")
	give_item(id, "weapon_flashbang")
	give_item(id, "weapon_smokegrenade")
	give_item(id, "item_assaultsuit")
	
	cs_set_user_bpammo(id, CSW_DEAGLE, 35)
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_FULL_EQUIP")
	client_cmd(0, "spk ^"fvox/weapon_pickup^"")
	DiceDHUD(id, szMessage)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	formatex(szMessage, charsmax(szMessage), "%L", LANG_PLAYER, "DIH_FULL_EQUIP", szName)
	DiceHUD(szMessage)
}

public ItemBankrupt(id)
{
	cs_set_user_money(id, 0)
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_BANKRUPT")
	client_cmd(0, "spk %s", g_szSounds[Bankrupt])
	DiceDHUD(id, szMessage)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	formatex(szMessage, charsmax(szMessage), "%L", LANG_PLAYER, "DIH_BANKRUPT", szName)
	DiceHUD(szMessage)
}

public ItemMoney(id)
{
	new iRandom = random_num(GetDiceCvar(g_eCvars[MoneyMin]), GetDiceCvar(g_eCvars[MoneyMax]))
	cs_set_user_money(id, cs_get_user_money(id) + iRandom)
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_MONEY", iRandom)
	client_cmd(0, "spk %s", g_szSounds[Applause])
	DiceDHUD(id, szMessage)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	formatex(szMessage, charsmax(szMessage), "%L", LANG_PLAYER, "DIH_MONEY", szName, iRandom)
	DiceHUD(szMessage)
}

public ItemBomber(id)
{
	new iRandom = random_num(GetDiceCvar(g_eCvars[BomberMin]), GetDiceCvar(g_eCvars[BomberMax]))
	
	if(!user_has_weapon(id, CSW_HEGRENADE))
	{
		give_item(id, "weapon_hegrenade")
		cs_set_user_bpammo(id, CSW_HEGRENADE, iRandom)
	}
	else
	{
		new iAmmo = cs_get_user_bpammo(id, CSW_HEGRENADE)
		cs_set_user_bpammo(id, CSW_HEGRENADE, iAmmo + iRandom)
	}
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_BOMBER", iRandom)
	client_cmd(0, "spk %s", g_szSounds[Bomber])
	DiceDHUD(id, szMessage)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	formatex(szMessage, charsmax(szMessage), "%L", LANG_PLAYER, "DIH_BOMBER", szName, iRandom)
	DiceHUD(szMessage)
}

public ItemMadness(id)
{
	new bool:bC4
	
	if(user_has_weapon(id, CSW_C4))
		bC4 = true
		
	strip_user_weapons(id)
	give_item(id, "weapon_mac10")
	cs_set_weapon_ammo(find_ent_by_owner(-1, "weapon_mac10", id), UNL_AMMO)
	cs_set_user_bpammo(id, CSW_MAC10, 0)
	set_user_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 40)
	set_user_health(id, GetDiceCvar(g_eCvars[MadnessHealth]))
	
	if(bC4)
		give_item(id, "weapon_c4")
	
	g_blMadness[id] = true
	EmitSound(id, g_szSounds[Madness])
	
	new iTask = id + TASK_MADNESS
	MadnessAura(iTask)
	set_task(0.7, "MadnessAura", iTask, .flags = "b")
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_MADNESS")
	DiceDHUD(id, szMessage)
}

public ItemMadnessOFF(id)
{
	remove_task(id + TASK_MADNESS)
		
	g_blMadness[id] = false
		
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
		{
			give_item(id, "weapon_knife")
			cs_set_weapon_ammo(find_ent_by_owner(-1, "weapon_mac10", id), 0)
			cs_set_user_bpammo(id, CSW_MAC10, 90)
		}
		
		set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderNormal, 0)
		
		new szMessage[128]
		formatex(szMessage, charsmax(szMessage), "%L", id, "DII_MADNESS_OFF")
		DiceDHUD(id, szMessage)
	}
}

public MadnessAura(id)
	MakeAura(id - TASK_MADNESS, 60, 255, 0, 0, RANDOM_COLOR, 50)
	
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

public ItemMole(id)
{
	new bool:bC4
	
	if(user_has_weapon(id, CSW_C4))
		bC4 = true
		
	PlayEffect(id, TE_TELEPORT)
	set_pev(id, pev_origin, g_flSpawnPoint[get_user_team(id) == 1 ? 1 : 0])
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	give_item(id, "weapon_elite")
	cs_set_user_bpammo(id, CSW_ELITE, 120)
	set_user_health(id, GetDiceCvar(g_eCvars[MoleHealth]))
	PlayEffect(id, TE_TELEPORT)
	
	if(bC4)
		give_item(id, "weapon_c4")
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_MOLE")
	client_cmd(0, "spk %s", g_szSounds[Teleport])
	DiceDHUD(id, szMessage)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	formatex(szMessage, charsmax(szMessage), "%L", LANG_PLAYER, "DIH_MOLE", szName)
	DiceHUD(szMessage)
}

public ItemRandomWeapon(id)
{
	new iWeapon = random(MAX_WEAPONS), iAmmo = random_num(GetDiceCvar(g_eCvars[RandomWepAmmoMin]), GetDiceCvar(g_eCvars[RandomWepAmmoMax]))
	give_item(id, g_eWeapons[iWeapon][Wpn])
	cs_set_user_bpammo(id, g_eWeapons[iWeapon][Csw], iAmmo)
	engclient_cmd(id, g_eWeapons[iWeapon][Wpn])
	
	new szMessage[128]
	formatex(szMessage, charsmax(szMessage), "%L", id, "DII_RANDOM_WEAPON", g_eWeapons[iWeapon][Name], iAmmo)
	client_cmd(0, "spk ^"weapon acquired^"")
	DiceDHUD(id, szMessage)
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	formatex(szMessage, charsmax(szMessage), "%L", LANG_PLAYER, "DIH_RANDOM_WEAPON", szName, g_eWeapons[iWeapon][Name], iAmmo)
	DiceHUD(szMessage)
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